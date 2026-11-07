# Status / handoff log

_Last updated: 2026-11-07 by Claude Code._
**Read this first, update it last** (see `AGENTS.md`).

## Current milestone: M0 almost done (waiting for GitHub), M1 started

### M0: Setup
- [x] Toolbox `flutter` with Flutter 3.47.9, JDK 21 and Android SDK 36 (`docs/dev-setup.md`)
- [x] Repo skeleton: `packages/core`, `app/` (android, linux, windows), docs, ADRs 0001–0005, specs
- [x] CI workflow and Copilot setup steps (not run yet: no GitHub repo)
- [x] Local builds checked: Linux release bundle, Android release APK (signed with the debug key)
- [x] Private GitHub repo `Naclador89/timetrack`, pushed; `gh` is logged in inside the toolbox
      (push with `tool/dev.sh git push`)
- [ ] **User**: start the CI build manually, download the Windows ZIP, start it on the Windows PC and
      check that the PC can reach Nextcloud (the M0 "done when" criterion)
- [ ] Android release keystore (`docs/dev-setup.md` §5), needed before the phone installs CI-built APKs
- [ ] Settle the Android application ID before the first real install (currently `de.timetrack.timetrack`)

### M1: core logic (pure Dart)
- [x] `LocalDate` (calculations §1)
- [x] `Span` / `SpanSet` interval math (calculations §1–§2)
- [x] Public holidays for all 16 states (calculations §6)
- [x] Day evaluation in the home time zone (`HomeTimeZone`, `evaluateDay`): split at local midnight,
      `W(D)`, `W_loc` (§2), project time and unassigned (§3)
- [x] ArbZG breaks §4 (warn/deduct), other checks §5 (`evaluateBreaks`, `arbzgWarnings`)
- [x] Target §7 (`TargetCalendar`), credited time and balance §8, travel crediting §9 (`Ledger`,
      `tripDayCredit`, `TravelRules`)
- [x] Vacation account §10 (`vacationAccount`)
- [x] Home office: day value, quota, forecast, yearly count §11 (`evaluateQuota`, `homeOfficeValue`)
- [ ] Per-diem §13
- [ ] Review list §12
- [ ] Project search (concept §5, item 3)
- [ ] HLC, change format, merge (sync-format §3–§6)
- [ ] drift database and SyncedRepository (sync-format §7, write path)
- [ ] Sync engine against an in-memory fake WebDAV, plus the property-based convergence test (sync-format §7)

**Next task**: per-diem §13 (`core/lib/src/rules/per_diem.dart`; needs `per_diem_rates` and
`trip_meals` models), then the Review list §12, then project search. After that, the sync part of
M1 (HLC, change format, merge, database, engine).
Performance note: `Ledger` scans all rows for each day. That's fine for personal data volumes, but
add an index by date if balances over several years get slow.

## Known issues / open questions
- Travel-rule assumptions (calculations §9) not yet confirmed by the user:
  1. Every trip day uses the weekday rule.
  2. Short weekday trip days get the full target.
  3. The Saturday cap applies to travel time only.
  4. Holidays are treated like Sundays.
  5. A weekday without target is treated like a Saturday.
- Nextcloud: self-hosted or run by a provider? This decides how early to add end-to-end encryption.
  Ask at M3.
- The default per-diem rates (DE 14/28 €) must be checked (calculations §13).

## Session log
- 2026-11-07, Claude Code: agreed the concept with the user; M0 setup; started M1 (LocalDate,
  SpanSet, holidays; 26 tests green; Linux and APK builds OK).
- 2026-11-07, Claude Code: pushed to GitHub (`Naclador89/timetrack`, private), started the first
  manual CI run. M1: home time zone, day evaluation (§2/§3), ArbZG checks (§4/§5); 57 tests green.
  Changed the CI concurrency so pushes no longer cancel manual or tag builds.
  Then target §7, credit and balance §8, travel crediting §9 (`Ledger` ties all daily rules
  together); 81 tests green. Then vacation account §10 and home office §11; 92 tests green.
