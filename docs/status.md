# Status / handoff log

_Last updated: 2026-11-07 by Claude Code._
**Read this first, update it last** (see `AGENTS.md`).

## Current milestone: M4 (reports) mostly done; release v0.1.0 published

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
- [x] User test 2026-11-07: sync works on Linux and the Windows company PC with the real Nextcloud.
- [x] Android release APK failed with "Failed host lookup": the `INTERNET` permission was missing from the
      main manifest (Flutter only adds it to debug/profile). Fixed, together with a `<queries>` entry
      for opening the browser (Login Flow) and the launcher label "TimeTrack".
- [x] Android: Login Flow didn't come back from the browser. Android freezes background apps
      (cached apps freezer), which left a poll hanging on a dead connection with no timeout.
      `LoginFlow.waitForApproval` now uses per-request timeouts, retries, a wall-clock deadline
      (20 min) and an immediate poll on app resume. Android opens the login in a Custom Tab.
- [x] User test 2026-11-07: the Android login and sync work with the fixed APK.
- [ ] **User**: Windows works without VPN (2026-11-07); with VPN not tested yet.
- [x] Android background sync (WorkManager, every 15 min; also after each quick action). Network-change trigger (optional) still open.
- [ ] Sync log screen (a list of the last cycles with errors). Today the status shows only the last error.

### M4: reports
- [x] core: `buildTimesheet`, `buildOrderReport`, `toCsv` (Excel flavour).
- [x] App tab "Berichte" (month picker): timesheet figures with PDF/CSV, order report with CSV,
      travel expenses (per-diem incl. provided meals) with PDF/CSV, simple statistics (hours by
      project, weeks), JSON backup of all rows. Exports: save dialog on desktop, share sheet on Android.
- [x] Trip dialog: meals per trip day (`trip_meals`, id `<tripId>_<date>`).
- [x] Tests: report tables/CSV/PDF/backup (German), PDF visually checked.
- [ ] Editing per-diem rates in the UI (rows exist; defaults DE 14/28 €).
- [ ] Restore from the JSON backup (export only so far).
- [ ] Nicer charts (fl_chart) if wanted.

### Releases
- `v0.1.0` (2026-11-07): GitHub Release with Windows ZIP, Android APK, Linux tar.gz; README and the
  repo's About link to `releases/latest`. Release APKs are signed with the CI debug key, which
  changes with every run, until a release keystore is set up (`docs/dev-setup.md` §5; waiting for
  the user's OK).

- `v0.2.0` (2026-11-07): project time as duration with summary.

### M5: Android quick access (implemented, **not yet tested on the phone**)
- [x] Design: Kotlin (`android/.../QuickAccess.kt`) draws notification, tile and widget from one
      snapshot in the home_widget preferences (`qa_*` keys, written by `lib/quick/quick_access.dart`).
      Buttons send `timetrack://quick/<action>` to the Dart handler `onQuickAction`, which runs
      core `runQuickAction` in a background engine, publishes, syncs, publishes again.
- [x] Ongoing notification while clocked in: chronometer (today's total, or the break's length),
      actions Pause/Weiter, Ausstempeln, Projekt wechseln (opens the app with the picker).
      POST_NOTIFICATIONS asked at the first clock-in (Android 13+).
- [x] Quick Settings tile (toggle clock in/out at the last location), home-screen widget (status,
      chronometer, clock and break buttons).
- [x] Background handlers open their **own** DB connection (drift's isolate sharing doesn't work
      across Flutter engines); WAL + busy_timeout 5 s (`lib/app/services.dart`). The UI re-reads on
      resume (`SyncStore.notifyExternalChange`).
- [x] Summary prompt for timers stopped outside the app: queued in `local_values`
      (`PendingSummaries`), asked when the app opens or resumes.
- [ ] Test on the phone (user): tile, widget, notification actions, background sync, summary prompt.

**Next task**: user tests M5 on the phone. The user re-enters the three reset settings. Then:
release keystore (if approved), M6 Garmin glance.

## Project time as duration with summary (requested by the user 2026-11-07, done in v0.2.0)

1. **Project time mainly as a duration.** The user mostly wants to record *how long* they worked on a
   project, as `H:MM`. A start/end time stays possible but is secondary. Sketch:
   - data-model §4: `project_entries` get `date` and `duration_min`. Required is `project_id` plus
     either `start_utc` (a time span, as today) or `date` + `duration_min`.
   - calculations §3: duration entries count on their date with their duration (no interval). Project
     time = interval entries inside working time + durations. Unassigned = worked − project time
     (never below 0). Durations above the worked time go into the Review list.
   - UI: a quick "Projektzeit eintragen" dialog (project via search, date, H:MM, summary) on Today and
     in the day editor. The timer stays as an option.
   - Done: `ProjectDuration` (core), `projectDurationFromRow`, §3 and §12 (`projectOverWork`) in
     `evaluateDay`/`reviewItems`, `app/lib/features/projects/project_time_dialog.dart`.
2. **A short summary per project time** ("what did I do?"). The `note` field already exists in
   `project_entries` (data-model §4) but has no UI yet:
   - entry in the quick dialog and the day editor;
   - optionally asked when stopping a running project timer;
   - shown in the day editor and the order report (an extra column "Tätigkeit"/"Activity" in CSV).
   Decided by the user: stopping a running project timer (stop, switch, break, clock out) **always
   asks** for a summary; the user may skip it. Done: `withSummaryPrompt`, notes shown in the day
   editor and Today, column "Tätigkeit" in the order report.

## Decisions taken with the user (2026-11-07)
- **Travel rules** confirmed: every weekday of a trip counts as a normal day (also days spent only
  working at the destination); a short trip day still gets the full target; the 11 h **Saturday cap
  covers travel and work together** (`SaturdayCapScope.total`); holidays like Sundays. Full-time
  Mon–Fri, so the day-off rule doesn't apply yet.
- **Trip Sundays → Sunday hours** (user, 2026-11-07): travel and on-site work on a trip Sunday count
  as Sunday hours for HR (extra pay), max 11 h, shown in the monthly timesheet, **not** in the
  overtime balance (`travel.sunday = sunday_hours`, `travel.sunday_cap_min = 660`, calculations §9).
  Holidays on trips follow the same rule. All travel rules are now editable in Settings.
- **Nextcloud is provider-hosted**, so end-to-end encryption is mandatory in sync format 1
  (ADR 0006, sync-format §10). It's part of M3.
- **App ID** `io.github.naclador89.timetrack`.
- **Per-diem rates** DE 14/28 € checked against secondary sources; still valid in 2026.

## Known issues / open questions
- **Incident 2026-11-07 (resolved):** a screenshot build with the sample database found the user's
  sync connection in the OS keyring (stored per app id) and uploaded the sample week to the real
  Nextcloud (device folder `devices/c75e1649ff1b05c3`). Cleaned up with the user's consent: 19
  tombstones and 3 settings reset to "unset" (`federal_state`, `starting_balance`,
  `balance_start_date`), which the user re-enters. Keep that device folder: other devices need its
  tombstones. Prevention: `SyncConfig.deviceId` binds the connection to its database,
  `TIMETRACK_DISABLE_SYNC` for demo/screenshot builds, `saveSetting` writes `deleted: false`.
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
- 2026-11-07, Claude Code: Android fixes (INTERNET permission, Login Flow in a frozen app); M4 reports and
  trip meals; incident (demo data synced) cleaned up and prevented; README downloads, About link,
  release v0.1.0.
- 2026-11-07, Claude Code: project time as duration (H:MM) with summary, summary prompt on timer stop;
  core 176 tests, app 9 widget tests. Version 0.2.0.
- 2026-11-07, Claude Code: M5 Android quick access (notification, tile, widget, WorkManager sync);
  travel settings UI and Sunday hours for HR (§9). core 182 tests, app 10 widget tests.
