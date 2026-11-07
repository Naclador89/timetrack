# 0006: End-to-end encryption of the sync files

- Status: accepted (2026-11-07)

## Context
Sync goes through files on the user's Nextcloud (ADR 0003). The user confirmed that the Nextcloud
**is run by a provider**, so without encryption the provider could read every working hour, location,
trip and project.

## Decision
End-to-end encryption is **mandatory in sync format 1**. Batch files use AES-256-GCM with a key
derived by Argon2id from a sync passphrase. The file path is bound in as AAD. `format.json` holds the
KDF parameters and a key check. Details: `docs/specs/sync-format.md` §10.

## Consequences
- The provider sees only metadata: file names (device ids, times of changes), sizes, device names.
- The user has to enter the sync passphrase once on each new device. If it's lost, the synced data
  can't be recovered from Nextcloud; each device's local copy and the JSON backup still are.
- No migration needed: no data had been synced when this was decided.
- Changing the passphrase needs a later format version.
