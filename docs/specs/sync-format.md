# Spec: sync format (format version 1)

Status: **normative**. Any change to this file needs a new **format version** (§9) and an ADR.
Tests cite sections (`// spec: sync-format.md §N`).

Goal: several devices (Android, Linux, Windows) each keep a full local SQLite copy and sync
**without a server of our own**, only through files in a shared WebDAV folder (Nextcloud).
Sync must converge (all devices reach the same state), never lose a change, and be safe against
crashes and repeated uploads.

---

## §1 Principles

1. **Each device writes only to its own folder.** No file is ever written by two devices, so there
   are no file conflicts.
2. **Files are never changed after upload.** A file is written once and never modified. Only its own
   device may delete it, and only during compaction (§8).
3. **Changes are per-field last-writer-wins (LWW)**, ordered by a **hybrid logical clock** (HLC).
   Applying changes is idempotent, commutative and associative, so files may be read in any order,
   any number of times.

## §2 Folder layout

The root is configurable; the default is `/TimeTrack` in the user's Nextcloud
(`https://<host>/remote.php/dav/files/<user>/TimeTrack`).

```
<root>/
  format.json
  devices/
    <deviceId>/
      device.json
      ops/
        <hlc>.jsonl.gz
```

- `format.json`: `{"format": 1, "created": "<ISO-8601 UTC>"}`. It is created by the first device if
  missing. A client that finds `format` greater than it supports **stops syncing** and asks the user
  to update the app. It never writes.
- `device.json`: `{"deviceId": "...", "name": "Pixel 8", "platform": "android", "created": "..."}`.
  Written once at the device's first sync and rewritten (by that device only) when the name changes.
- `deviceId`: 16 lowercase hex characters (64 random bits), created at first launch and stored only
  locally. A reinstall creates a new device id; old folders simply stay readable.

## §3 Hybrid logical clock

The format is `<ms>-<counter>-<deviceId>`:
- `ms`: Unix time in milliseconds, **13 decimal digits**, zero-padded.
- `counter`: **4 lowercase hex digits** (`0000`–`ffff`).
- `deviceId` as in §2.

Example: `1794067200123-0000-1a2b3c4d5e6f7081`. Because of the fixed width, **comparing the strings
gives the same order as comparing the clocks**, and the device id breaks ties.

Rules (the standard HLC algorithm), with local state `(l_ms, l_c)`:
- **Local event**: `pt = wall clock ms`. If `pt > l_ms`, then `(l_ms, l_c) = (pt, 0)`; otherwise `l_c += 1`.
- **Receiving** a remote HLC `(r_ms, r_c)`: `pt = wall clock`.
  - If `pt > max(l_ms, r_ms)`: `(pt, 0)`.
  - Else if `l_ms == r_ms`: `(l_ms, max(l_c, r_c) + 1)`.
  - Else if `l_ms > r_ms`: `(l_ms, l_c + 1)`.
  - Else: `(r_ms, r_c + 1)`.
- If the counter would overflow `ffff`, `l_ms` is increased by 1 and the counter resets to 0.
- The state is stored locally after every change, so the clock never goes backwards across restarts.

## §4 Synced tables and rows

Synced tables (fields: see `docs/concept.md` §2):
`work_sessions`, `breaks`, `projects`, `project_entries`, `absences`, `work_schedules`,
`settings`, `home_office_rules`, `trips`, `trip_meals`, `per_diem_rates`.

Every synced row has:
- `id`: UUIDv7 string. For `settings` the id is the setting key (for example `home_office.day_rule`).
- the table's data fields;
- `deleted`: bool (tombstone; rows are never physically deleted);
- locally only: `field_clock`, a JSON object `field → HLC` of the last applied write per field.

**Values** in changes: JSON `null`, bool, number (ints only, minutes or cents), string.
- Instants are ISO-8601 UTC strings with minute precision: `"2026-11-07T08:00:00Z"`.
- Dates are `"YYYY-MM-DD"`.
- Money is integer **cents**.

## §5 Change (op) format

One change is one JSON object:

```json
{"tbl":"project_entries","id":"019a5f2e-…","hlc":"1794067200123-0000-1a2b3c4d5e6f7081","set":{"end_utc":"2026-11-07T11:00:00Z"}}
```

- `tbl`: table name; `id`: row id; `hlc`: the HLC of this write.
- `set`: the fields written by this change, at least one. A **create** sets all fields. A **delete**
  sets `{"deleted": true}`.

A **batch file** `devices/<deviceId>/ops/<hlc>.jsonl.gz` is gzip-compressed UTF-8 JSON Lines:
- Line 1 is the header: `{"format":1,"deviceId":"…","count":<n>}`.
- Lines 2…n+1 are changes, sorted by `hlc` ascending. They were all created by this device.
- The file name is the `hlc` of the **first** change. HLCs of one device strictly increase, so names are unique.

## §6 Applying changes (merge)

To apply a change `op`:

1. If the row `(tbl, id)` doesn't exist locally, create it with every field `null` and `deleted = false`,
   and an empty `field_clock`.
2. For each `(field, value)` in `op.set`: if `field_clock[field]` is missing **or** `op.hlc >
   field_clock[field]` (string comparison), set `row[field] = value` and `field_clock[field] = op.hlc`.
   Otherwise ignore that field.
3. Update the local HLC with `op.hlc` (§3, receiving).
4. Unknown tables are skipped. Unknown fields are stored nowhere (see §9 for replay).

Files from different devices can arrive in any order, so an update can arrive before its create.
The row then has `null` in fields not written yet. All synced data columns are therefore nullable in
the database. Calculations and the UI **ignore rows that are missing a required field**: they count
as not yet complete. For example, a session without `start_utc` is skipped.

Because each field takes the maximum HLC, the result doesn't depend on order or repetition.
`deleted` is an ordinary field: an edit after a delete doesn't bring the row back unless it also sets
`deleted: false`.

## §7 Sync cycle

Local only state: `outbox` (changes not yet uploaded, in HLC order), `pending_batch` (at most one
frozen batch: file name + change list), `seen_files` (path + ETag of every applied remote file),
`folder_etags` (last seen ETag per remote folder), `hlc_state`.

**Local write** (one SQLite transaction): get a new HLC, update the row and `field_clock`, append the
change to `outbox`. After the commit, schedule a sync (debounced 5 s).

**Sync** (only one at a time per device; protected by a lock):

1. **Prepare**: `PROPFIND <root>` (Depth 0). If it doesn't exist, `MKCOL` the root, `devices/`, the own
   device folder and `ops/`, and write `format.json` (with `If-None-Match: *`; a 412 means another
   device was faster, which is fine). Read `format.json` and check the version.
2. **Push**:
   - If there is no `pending_batch` and `outbox` isn't empty, freeze the whole outbox into a
     `pending_batch` and remove those changes from `outbox`, in one transaction.
   - `PUT` the batch file with header `If-None-Match: *`. `201`/`204` = uploaded. `412` = the file
     already exists from an earlier attempt that crashed after uploading, so it counts as uploaded.
   - Then delete `pending_batch`.
   - A crash at any point leaves either the outbox or the pending batch intact, so nothing is lost,
     and the same file name is reused, so nothing is duplicated.
3. **Check**: `PROPFIND <root>/devices/` (Depth 1) and get the ETag of every device folder.
   Nextcloud updates a folder's ETag whenever anything inside it changes.
4. **Pull**: for every **other** device folder whose ETag differs from `folder_etags`:
   - `PROPFIND <device>/ops/` (Depth 1).
   - For every file not in `seen_files` (or with a different ETag), `GET` it, check the header, and
     apply all its changes in **one** transaction, adding the file to `seen_files` in that same
     transaction.
   - Store the folder ETag only after all of its files were applied.
5. **Resolve** (§7.1), then emit the changes to the UI.

Network errors stop the cycle without harm; the next cycle starts again at step 1.

### §7.1 Resolving after a merge

Rules that must hold, and are restored deterministically after every pull:
- **At most one open session**: if several `work_sessions` with `end_utc = null` and `deleted = false`
  exist, sort them by `(start_utc, id)`. Every one except the last gets `end_utc = start_utc` of the next.
- **At most one running project entry**: the same rule for `project_entries`.

These corrections are ordinary local writes (§7) with new HLCs. Every device computes the **same
values**, so even if two devices both correct the same row, LWW ends in the same state.

### §7.2 Triggers

5 s after a local write (debounced); on app start and resume; every 60 s while in the foreground; on
a network change. On Android: WorkManager every 15 min (network required), plus a one-off job after
background writes (notification, tile, widget, watch).

## §8 Compaction (optional, later)

A device may merge **its own** batch files into one new file (named after its first change's HLC,
with the header `"compacted": true`) and then delete the old files. Readers that already applied the
old files apply the new one again, which is harmless (§6). A reader that gets 404 for a deleted file
lists the folder again in its next cycle.

## §9 Versioning and schema evolution

- `format` in `format.json` and in the batch header changes **only** for incompatible changes to this
  spec. Clients refuse to read a newer `format`.
- **Adding** tables or fields is compatible. Older clients ignore them (§6.4). When a client update
  adds fields, the client does a **full replay** once: it clears `seen_files` and `folder_etags`,
  pulls again and re-applies all files, so values written by newer clients reach the new columns.

## §10 Security

- Transport is HTTPS only, with the Nextcloud **app password** from Login Flow v2. It is stored in the
  platform's secure storage and never written to the database or to logs.
- End-to-end encryption of batch files is planned as an option (a separate format version).
