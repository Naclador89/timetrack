# Status / handoff log

_Last updated: 2026-11-07 by Claude Code._
**Read this first, update it last** (see `AGENTS.md`).

## Current milestone: M3 (Nextcloud sync) implemented; waiting for tests on the user's devices

### M0: Setup
- [x] Toolbox `flutter` with Flutter 3.47.9, JDK 21 and Android SDK 36 (`docs/dev-setup.md`)
- [x] Repo skeleton: `packages/core`, `app/` (android, linux, windows), docs, ADRs 0001–0005, specs
- [x] CI workflow and Copilot setup steps. First manual run green: test 1:42, Linux 1:22,
      Android 4:54, Windows 7:56, so about 25 billed minutes for a full build
- [x] Local builds checked: Linux release bundle, Android release APK (signed with the debug key)
- [x] Private GitHub repo `Naclador89/timetrack`, pushed; `gh` is logged in inside the toolbox
      (push with `tool/dev.sh git push`)
- [x] Windows ZIP from CI starts on the user's Windows PC, and that PC reaches the Nextcloud WebDAV
      endpoint (2026-11-07). The M0 "done when" criterion is met.
- [ ] Actions bumped to their current majors (checkout v7, upload-artifact v7, download-artifact v8,
      setup-java v6, action-gh-release v3) to drop the Node 20 deprecation warnings. Only `test` has run
      on them so far; the build and release jobs get checked at the next tag or manual run.
- [ ] Android release keystore (`docs/dev-setup.md` §5), needed before the phone installs CI-built APKs
- [x] Android application ID settled: `io.github.naclador89.timetrack` (also the Linux app ID)

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
- [x] Per-diem §13 (`perDiemForTrip`, `defaultPerDiemRates`)
- [x] Review list §12 (`reviewItems`)
- [x] Project search (`docs/specs/project-search.md`, `searchProjects`)
- [x] HLC, change format, merge (sync-format §3–§6): `Hlc`, `HlcClock`, `Change`, `applyChange`,
      `encodeBatch`/`decodeBatch`
- [x] End-to-end encryption (§10): `createEncryption`, `unlockEncryption`, `SyncCipher`
      (Argon2id + AES-256-GCM via `cryptography`)
- [x] Store abstraction `SyncStore` (+ `InMemorySyncStore`) and `SyncedRepository` (write path, §7)
- [x] Remote abstraction `RemoteFolder` (+ `InMemoryRemoteFolder`, which updates folder ETags like Nextcloud)
- [x] `SyncEngine` (push, pull, resolve §7.1) and `connectSyncFolder` (set up or join with passphrase)
- [x] Property-based convergence test: 3 devices, clock skew, random edits, syncs and connection
      losses, 30 seeds. Mutation-checked: it fails if merge or resolve is broken.
- [x] drift database implementing `SyncStore` (generic rows, ADR 0007) and mapping complete rows to
      the model classes (`docs/specs/data-model.md`, `ledgerDataFromRows`). The engine and
      convergence tests run against both the in-memory store and SQLite.

### M2: local MVP app (Flutter, no sync yet)
- [x] Commands in `core` for the two-layer rules (`TimeTracker`): clock in/out, location change,
      break start/end (with resume), start/switch/stop project with auto clock-in, start/end trip.
      Typed settings with defaults (`AppSettings`, `SettingKeys`, `saveSetting`).
      `SyncStore.watchRows` for reactive UIs.
- [x] App setup: Riverpod, go_router (adaptive shell), localization (de and en, 130 strings), SQLite
      in the app support folder (`~/.local/share/io.github.naclador89.timetrack/`,
      `%APPDATA%`, Android app storage), device id in `local_values`.
- [x] Today screen: clock in/out with location chips, break, trip prompts (travel → start trip,
      clock-out → end trip), favorite chips, project picker, worked/target/unassigned, balance,
      home-office quota, notices.
- [x] Project picker (search with highlights, create from search text) and projects screen with editor.
- [x] Week view (per-day worked/target/difference, locations, absences, trips, notice marker, balance)
      and day editor (sessions, breaks, project entries, absences; night work ends next day).
- [x] Absences (range entry on workdays, half days, vacation account), trips (with times, country,
      overnight), settings (state, Bavarian Assumption Day, schedules, home-office rules, starting
      balance and date, break mode, auto clock-in, resume after break, Saturday cap).
- [x] Checked on Linux with sample data (screenshots: Today, week, day editor, settings); widget tests
      for the main flows.
- [ ] **User**: try it on the Android phone (needs wireless debugging pairing, `docs/dev-setup.md` §3)
      and on Linux for real use.
- [ ] Not in M2 yet (later or nice to have): a visual timeline bar on Today, trip meals (needed with
      the travel report in M4), editing vacation entitlement and carry-over in the UI (setting keys
      exist), home-office quota by hours in the UI (core supports it), keyboard shortcut Ctrl+K for
      the picker.

### M3: Nextcloud sync
- [x] `WebDavRemoteFolder` (PROPFIND/GET/PUT with `If-None-Match`/MKCOL/DELETE, ETags, path encoding)
      and Login Flow v2 (`LoginFlow`, `NextcloudCredentials`) in `core`.
- [x] Simulated Nextcloud for tests (`package:timetrack_core/testing.dart`, `fakeNextcloud`).
- [x] Integration tests against a real Nextcloud 34 in podman (`docs/dev-setup.md` §6): 412,
      ETag propagation, encrypted sync of two devices, wrong passphrase, third device joining.
- [x] Key derivation (Argon2id, 64 MiB) runs in `Isolate.run`, so the UI doesn't freeze.
- [x] App: `SyncController` (debounce 5 s after writes, every 60 s, on resume), config in secure
      storage (`SyncConfig`), setup screen (Login Flow in the browser or manual app password, new or
      joining passphrase, optional per-device proxy), status in settings. Widget test: a local write
      is uploaded encrypted after the debounce.
- [ ] **User**: connect each device to the real Nextcloud (Linux, Android, Windows PC with and
      without VPN). If the company network needs a proxy, enter it in the sync setup on that PC.
- [ ] Android background sync (WorkManager), planned with M5. Network-change trigger (optional).
- [ ] Sync log screen (a list of the last cycles with errors). Today the status shows only the last error.

**Next task**: after the user's device tests, fix what they find. Then continue M4. Already done in
`core/lib/src/reports/reports.dart`: `buildTimesheet` (monthly rows and totals), `buildOrderReport`
(minutes per day and order number) and `toCsv` (Excel flavour). Still to do: the app's Reports screen,
the PDF (packages `pdf` and `printing`), CSV/JSON export via share or save, trip meals, the travel
report (`perDiemForTrip`), and statistics charts.

## Decisions taken with the user (2026-11-07)
- **Travel rules** confirmed: every weekday of a trip counts as a normal day (also days spent only
  working at the destination); a short trip day still gets the full target; the 11 h **Saturday cap
  covers travel and work together** (`SaturdayCapScope.total`); holidays like Sundays. Full-time
  Mon–Fri, so the day-off rule doesn't apply yet.
- **Nextcloud is provider-hosted**, so end-to-end encryption is mandatory in sync format 1
  (ADR 0006, sync-format §10). It's part of M3.
- **App ID** `io.github.naclador89.timetrack`.
- **Per-diem rates** DE 14/28 € checked against secondary sources; still valid in 2026.

## Known issues / open questions
- **Windows PC is company-managed and sometimes on a VPN** (user, 2026-11-07). For M3:
  - Dart's `HttpClient` doesn't use the Windows system proxy by itself. Support the system or PAC
    proxy (for example read it via WinHTTP) or a manual proxy setting, and test with and without the VPN.
  - Treat network changes (VPN up or down) as a sync trigger and retry failed syncs with backoff.
  - Keep the Windows build portable (no admin rights needed, data in `%APPDATA%`).
- No open questions for the user right now.

## Session log
- 2026-11-07, Claude Code: agreed the concept with the user; M0 setup; started M1 (LocalDate,
  SpanSet, holidays; 26 tests green; Linux and APK builds OK).
- 2026-11-07, Claude Code: pushed to GitHub (`Naclador89/timetrack`, private), started the first
  manual CI run. M1: home time zone, day evaluation (§2/§3), ArbZG checks (§4/§5); 57 tests green.
  Changed the CI concurrency so pushes no longer cancel manual or tag builds.
  Then target §7, credit and balance §8, travel crediting §9 (`Ledger` ties all daily rules
  together); 81 tests green. Then vacation account §10 and home office §11; then per-diem §13; 98 tests green.
- 2026-11-07, Claude Code: M0 confirmed by the user (the Windows ZIP runs on the company PC and WebDAV
  is reachable). Review list §12, project search (new spec `project-search.md`); 108 tests green.
- 2026-11-07, Claude Code: resolved all open questions with the user (see Decisions). Saturday cap
  now covers the whole day; E2E encryption added to sync format 1 (ADR 0006); app ID changed; 109 tests.
- 2026-11-07, Claude Code: sync core: HLC, change format, merge, E2E encryption, store and remote
  abstractions, repository, engine, convergence test; 132 tests green. Remaining in M1: drift store.
- 2026-11-07, Claude Code: drift store (generic rows, ADR 0007), data-model spec, row mapping; sync
  tests also on SQLite; unknown tables and fields are now kept. **M1 done**, 148 tests green.
- 2026-11-07, Claude Code: M2 local app: TimeTracker commands, typed settings, all screens, l10n;
  found and fixed the database location (was Documents); checked on Linux with screenshots;
  `tool/seed_demo.dart` and `tool/screenshot.sh` for UI checks. core 163 tests, app 3 widget tests.
- 2026-11-07, Claude Code: M3 sync implemented: WebDAV client, Login Flow v2, integration tests against
  a real Nextcloud 34 (podman), app sync controller and setup screen, per-device proxy. core 167 tests
  (+2 integration), app 4 widget tests.
