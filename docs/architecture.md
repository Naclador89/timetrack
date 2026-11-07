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
  time/      LocalDate, Span(Set)     calendar days in the home time zone, interval union/intersection
  model/     plain value types      
  rules/     day_work, arbzg, …      calculations.md §2–§14 as pure functions
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
| `core/time` (`LocalDate`, `Span`/`SpanSet`, `HomeTimeZone`) | calculations §1 | done |
| `core/model/attendance` (`WorkSession`, `WorkBreak`, `ProjectEntry`) | calculations §2–§3 | done |
| `core/rules/day_work` (`evaluateDay`) | calculations §2–§3 | done |
| `core/rules/arbzg` (`evaluateBreaks`, `arbzgWarnings`) | calculations §4–§5 | done |
| `core/rules/holidays` | calculations §6 | done |
| `core/model/planning` (`WorkSchedule`, `Absence`, `Trip`) | calculations §7–§9 | done |
| `core/rules/target` (`TargetCalendar`) | calculations §7 | done |
| `core/rules/credit` (absence credit, travel rules) | calculations §8–§9 | done |
| `core/rules/ledger` (`Ledger`: per-day results, balance) | calculations §2–§9 | done |
| everything else | | planned (see `docs/status.md`) |
