# Architecture decision records

One short file per decision: context, decision, consequences. Numbered and never renumbered.
To change a decision, add a new ADR that supersedes the old one, and mark the old one as superseded.

| # | Decision |
|---|---|
| [0001](0001-flutter.md) | Flutter (Dart) for all platforms |
| [0002](0002-two-layer-time-model.md) | Two-layer time model (attendance + projects) |
| [0003](0003-file-sync-nextcloud.md) | Sync through files on Nextcloud (WebDAV), no server of our own |
| [0004](0004-per-field-lww-hlc.md) | Per-field last-writer-wins with a hybrid logical clock |
| [0005](0005-ci-github-actions-free.md) | CI on GitHub Actions, sized for the free plan |
| [0006](0006-e2e-encryption.md) | End-to-end encryption of the sync files |
