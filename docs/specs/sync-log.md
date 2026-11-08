# Sync log

Status: **normative**. Code: `packages/core/lib/src/sync/sync_log.dart`; UI: Einstellungen → Sync →
Sync-Protokoll (`app/lib/features/settings/sync_log_screen.dart`).

- Every sync cycle, in the app (`SyncController.syncNow`) and in Android background handlers
  (`syncInBackground`), records one entry: start (UTC), duration, where it ran (`app` /
  `background`), the `SyncReport` counts (changes uploaded, files downloaded, changes in them, rows
  resolved) or the error.
- **Device-local**: stored as JSON under `local_values` key `sync_log`, never synced. Newest first,
  at most **100** entries; older ones are dropped. A damaged value reads as an empty log.
- An **idle** cycle (success, nothing moved) directly after another idle one doesn't add an entry:
  the newest entry's `n` (count) and `last` (start of the latest cycle) are updated instead, so the
  60-second timer doesn't flood the log.
- **Errors** are stored as one line of at most 300 characters, with `user:password@` removed from
  URLs. Nothing else from the connection (app password, key, passphrase) is ever logged.
- Writing the log never fails a sync: errors while recording are ignored.

Stored form of one entry (fields with value 0 / 1 / null are left out):

```json
{"start": "2026-11-08T09:12:00.000Z", "last": "2026-11-08T09:41:00.000Z", "ms": 380,
 "trigger": "app", "up": 3, "files": 2, "down": 14, "resolved": 1, "error": "…", "n": 30}
```
