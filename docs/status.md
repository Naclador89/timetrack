# Status / handoff log

_Last updated: 2026-11-07 by Claude Code._
**Read this first, update it last** (see `AGENTS.md`).

## Current milestone: M0 almost done (waiting for GitHub), M1 started

### M0: Setup
- [x] Toolbox `flutter` with Flutter 3.47.9, JDK 21 and Android SDK 36 (`docs/dev-setup.md`)
- [x] Repo skeleton: `packages/core`, `app/` (android, linux, windows), docs, ADRs 0001–0005, specs
- [x] CI workflow and Copilot setup steps (not run yet: no GitHub repo)
- [x] Local builds checked: Linux release bundle, Android release APK (signed with the debug key)
- [ ] **User**: create a private GitHub repo and push
- [ ] **User**: start the CI build manually, download the Windows ZIP, start it on the Windows PC and
      check that the PC can reach Nextcloud (the M0 "done when" criterion)
- [ ] Android release keystore (`docs/dev-setup.md` §5), needed before the phone installs CI-built APKs
- [ ] Settle the Android application ID before the first real install (currently `de.timetrack.timetrack`)

### M1: core logic (pure Dart)
- [x] `LocalDate` (calculations §1)
- [x] `Span` / `SpanSet` interval math (calculations §1–§2)
- [x] Public holidays for all 16 states (calculations §6)
- [ ] Day evaluation in the home time zone (`timezone` package): split at local midnight, `W(D)`,
      `W_loc` (§2), project time and unassigned (§3)
- [ ] ArbZG breaks §4 (warn/deduct), other checks §5
- [ ] Target §7, credited time and balance §8, travel crediting §9
- [ ] Vacation account §10
- [ ] Home office: day value, quota, forecast §11
- [ ] Per-diem §13
- [ ] Review list §12
- [ ] Project search (concept §5, item 3)
- [ ] HLC, change format, merge (sync-format §3–§6)
- [ ] drift database and SyncedRepository (sync-format §7, write path)
- [ ] Sync engine against an in-memory fake WebDAV, plus the property-based convergence test (sync-format §7)

**Next task**: day evaluation (`core/lib/src/rules/day.dart` or similar). Add the `timezone`
dependency, turn a `LocalDate` into a day `Span` in the home time zone (23/25 h on DST days),
then compute §2/§3 from sessions, breaks and project entries passed in as plain values.

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
