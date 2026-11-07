# Architecture

How the code is organised. The *why* is in `docs/concept.md` and `docs/decisions/`; the exact rules
are in `docs/specs/`. Update this file when you add or move a module.

## Layers

```
app/ (Flutter)                       UI, navigation, platform glue (notifications, tile, widget,
  features/<screen>/                 watch bridge, geofence). No business rules.
  platform/
        │  uses
        ▼
packages/core/ (pure Dart)           Everything testable without Flutter:
  time/      LocalDate, intervals    calendar days in the home time zone, interval union/intersection
  rules/     holidays, …             calculations.md §2–§14 as pure functions
  search/    project search          (M1)
  data/      drift database          tables + SyncedRepository (row + field clock + outbox in one tx) (M1)
  sync/      HLC, ops, engine,       sync-format.md (M1: engine against fakes; M3: real WebDAV)
             WebDAV client
```

Rules for dependencies:
- `core` never imports Flutter. `app` never contains rules from `docs/specs/calculations.md`.
- Inside `core`, `rules/` are pure functions over plain values (no database), so they are trivial to test.
  `data/` maps database rows to those values.

## Module status

| Module | Spec | Status |
|---|---|---|
| `core/time` (LocalDate, intervals) | calculations §1 | in progress (M1) |
| `core/rules/holidays` | calculations §6 | in progress (M1) |
| everything else | | planned (see `docs/status.md`) |
