# 0003: Sync through files on Nextcloud (WebDAV), no server of our own

- Status: accepted (2026-11-07)

## Context
Devices must sync automatically. The user didn't want to run a server and already has a Nextcloud.
Alternatives were a self-hosted sync server on a Raspberry Pi, a managed backend (Supabase or
Firebase), Google Drive and Syncthing.

## Decision
**Local-first**: each device has a full SQLite copy. Devices exchange **files that are never changed
after upload**, in **per-device folders** on the user's Nextcloud through WebDAV. The app does the
WebDAV calls itself; no Nextcloud client is needed. Sign-in uses Nextcloud Login Flow v2 (app password).

## Consequences
- No file conflicts are possible (each device writes only its own folder), and nothing runs on a server.
- Convergence must come from the data model: per-field LWW with an HLC (ADR 0004).
- Near-real-time sync isn't possible; polling uses folder ETags and is cheap (about 1 min in the
  foreground, about 15 min in the background on Android).
- The format is a public contract: `docs/specs/sync-format.md`.
