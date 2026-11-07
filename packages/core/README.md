# timetrack_core

All business logic of TimeTrack, in pure Dart (no Flutter): time model, calculation rules
(`docs/specs/calculations.md`) and sync (`docs/specs/sync-format.md`).

```bash
../../tool/dev.sh dart test      # see AGENTS.md for all commands
```

Layout: `lib/src/time/` (dates, intervals), `lib/src/rules/` (pure calculation functions).
More modules are listed in `docs/architecture.md`.
