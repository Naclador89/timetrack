# Backup and restore

Status: **normative**. Code: `packages/core/lib/src/sync/backup.dart`; UI: Berichte → "Sicherung
laden" (`app/lib/features/reports/restore_backup.dart`).

## §1 File
A JSON object, written by `encodeBackup`:

```json
{"app": "TimeTrack", "format": 1, "exported": "2026-11-08T09:00:00.000Z",
 "rows": [{"tbl": "projects", "id": "…", "fields": {…}, "fieldClock": {"name": "<hlc>", …}}]}
```

- `rows` holds every row of the synced tables (sync-format §4), **tombstones and field clocks
  included**, unencrypted. Keep the file private.
- `format` is the sync format version (sync-format §9). A file with a newer format, without
  `"app": "TimeTrack"`, or with an unparsable clock is refused as a whole (`BackupFormatException`).

## §2 Loading
The user picks the mode **every time** a backup is loaded (user, 2026-11-08). Before the choice the
app runs a sync (so other devices' latest rows are known) and shows, per mode, how many rows come
back, change and get deleted (a dry run). A mode that would change nothing can't be confirmed.
Every write goes through the repository's transaction and outbox, so the result reaches all devices.
There is no undo; the dialog suggests saving a current backup first.

### §2.1 Merge (Zusammenführen)
Exactly like receiving the backup's changes by sync (sync-format §6): for each field the backup's
value is applied with **its original HLC** if that is newer than the local field clock. Anything
written after the backup therefore stays, and loading the same backup twice changes nothing. The
local clock `receive`s the applied HLCs.

### §2.2 Replace (Ersetzen)
The data becomes exactly the backup, **on all devices**: for every row whose fields differ from the
backup, one write with a **fresh** HLC sets the backup's values (fields the backup lacks become
`null`); rows the backup doesn't contain and that aren't deleted get a tombstone. Fresh HLCs are
newer than everything this device has seen, so they win on the other devices too. Rows another
device created after the last successful sync are not known and stay; the pre-sync keeps this rare.
