# Architecture

How the code is organised. The *why* is in `docs/concept.md` and `docs/decisions/`; the exact rules
are in `docs/specs/`. Update this file when you add or move a module.

## Layers

```
app/ (Flutter)                       UI, navigation, platform glue (notifications, tile, widget,
  app/providers.dart                 watch bridge, geofence). No business rules.
  app/router.dart                    Riverpod providers wire store rows → core rules (Ledger,
  features/<screen>/                 TrackerState, quotas); widgets only read providers and call
  l10n/                              TimeTracker / SyncedRepository. go_router with an adaptive
                                     shell (bottom bar < 720 px, rail above).
        │  uses
        ▼
packages/core/ (pure Dart)           Everything testable without Flutter:
  time/      LocalDate, Span(Set)     calendar days in the home time zone, interval union/intersection
  model/     plain value types      
  rules/     day_work, arbzg, …      calculations.md §2–§14 as pure functions
  search/    project search          (M1)
  data/      drift database          generic synced rows + local sync state (ADR 0007), mapping to models
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
| `core/rules/vacation` (`vacationAccount`) | calculations §10 | done |
| `core/rules/home_office` (day value, quota, forecast) | calculations §11 | done |
| `core/rules/per_diem` (`perDiemForTrip`) | calculations §13 | done |
| `core/rules/review` (`reviewItems`) | calculations §12 | done |
| `core/model/project`, `core/search/project_search` | project-search | done |
| `core/sync/hlc`, `change`, `batch` (clock, changes, merge, batch files) | sync-format §3–§6 | done |
| `core/sync/crypto` (Argon2id key, AES-256-GCM files) | sync-format §10 | done |
| `core/sync/store`, `repository` (`SyncStore`, `SyncedRepository`) | sync-format §7 | done |
| `core/data/database`, `drift_sync_store` (SQLite via drift, generic rows) | sync-format §7, ADR 0007 | done |
| `core/data/mapping` (rows → models) | data-model | done |
| `core/data/settings` (`AppSettings`, `SettingKeys`) | data-model §7 | done |
| `core/tracking/time_tracker` (`TimeTracker`, `TrackerState`) | concept §2 | done |
| `app` screens: Today, week, day editor, absences, trips, projects, settings, schedules, home-office rules | concept §5 | M2 done (local only) |
| `core/sync/remote` (`RemoteFolder`, in-memory fake) | sync-format §2, §7 | done |
| `core/sync/webdav` (`WebDavRemoteFolder`, `LoginFlow`) | sync-format §2, §7, §10 | done |
| `core/testing.dart` (`fakeNextcloud` for tests) | | done |
| `app/lib/sync` (`SyncController`, `SyncConfig` in secure storage) | sync-format §7.2 | done |
| `core/sync/engine` (`SyncEngine`, `connectSyncFolder`) | sync-format §7, §7.1 | done |
| everything else | | planned (see `docs/status.md`) |
