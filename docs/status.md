# Status / handoff log

_Last updated: 2026-11-09 by Claude Code (handoff to GitHub Copilot)._
**Read this first, update it last** (see `AGENTS.md`).

## Where things stand (read this first)

- **Latest release: `v0.5.2`** (2026-11-09), `app/pubspec.yaml` `version: 0.5.2+8`. All planned
  milestones are done; work now comes as feedback from the user (German, often with screenshots
  from the Windows work PC or the Android phone).
- **Tests**: core 275, app 66 widget tests, all green; CI green on `main`.
- **Nothing is in progress.** No open task, no half-done branch.
- **Waiting for the user to test on real devices** (can't be tested here; fix what they report):
  - Windows: tray icon and menu, "Im Infobereich weiterlaufen" (close hides), "Mit Windows starten"
    and "Arbeits-PC" (question after sign-in), Windows notifications for reminders, the updater
    quitting through the channel without a ghost tray icon.
  - Android: reminders ("Pause fällig", "Langer Tag" with Ausstempeln), the finish time as
    notification subtext, the forgotten clock-out dialog.
  - Both: the new month view, the usual break, snack bars, "Tagesart entfernen".
- **Not wanted** (don't propose again unless the user asks): Garmin glance, auto clock-in by
  Wi-Fi/geofence, VPN sync testing, lock/sleep detection on Windows, copying hours into the company
  booking system.
- **How a change usually goes**: user reports a problem or wish → update the spec in `docs/specs/`
  → logic + tests in `packages/core` → UI in `app/` (strings in both ARB files) → widget test →
  a new section or entry below plus a session log line → commit → push. A release only when the
  user asks for it (`docs/dev-setup.md`, "Releasing").

## History by milestone (all done)

### M0: Setup
- [x] Toolbox `flutter` with Flutter 3.47.9, JDK 21 and Android SDK 36 (`docs/dev-setup.md`)
- [x] Repo skeleton: `packages/core`, `app/` (android, linux, windows), docs, ADRs 0001–0005, specs
- [x] CI workflow and Copilot setup steps. First manual run green: test 1:42, Linux 1:22,
      Android 4:54, Windows 7:56, so about 25 billed minutes for a full build
- [x] Local builds checked: Linux release bundle, Android release APK (signed with the debug key)
- [x] GitHub repo `Naclador89/timetrack` (public since 2026-11-08, ADR 0008; the old private repo
      with the original history is `Naclador89/timetrack-private`), pushed; `gh` is logged in inside the toolbox
      (push with `tool/dev.sh git push`)
- [x] Windows ZIP from CI starts on the user's Windows PC, and that PC reaches the Nextcloud WebDAV
      endpoint (2026-11-07). The M0 "done when" criterion is met.
- [x] Actions bumped to their current majors (checkout v7, upload-artifact v7, download-artifact v8,
      setup-java v6, action-gh-release v3); all jobs ran green in the v0.3.0 release.
- [x] Android release keystore (`docs/dev-setup.md` §5, 2026-11-08): local `key.properties` + `release.jks`
      (git-ignored), CI secrets set; local and CI APKs now share one key. The phone needs one reinstall.
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
- Windows works without VPN (2026-11-07). Testing over the company VPN was dropped by the user (2026-11-08).
- [x] Android background sync (WorkManager, every 15 min; also after each quick action).
- [x] Network-change trigger (`connectivity_plus`): 3 s after a new connection (Android/Windows:
      Wi-Fi ↔ mobile/ethernet, VPN; Linux: only offline → online, a VPN switch there waits for the
      60 s timer); logged as "nach Netzwechsel". Triggers during a running cycle are queued.
- [x] Sync log (`docs/specs/sync-log.md`, core `SyncLog`): last 100 cycles per device, idle runs
      folded into one line, errors without credentials; Einstellungen → Sync → Sync-Protokoll.

### M4: reports
- [x] core: `buildTimesheet`, `buildOrderReport`, `toCsv` (Excel flavour).
- [x] App tab "Berichte" (month picker): timesheet figures with PDF/CSV, order report with CSV,
      travel expenses (per-diem incl. provided meals) with PDF/CSV, simple statistics (hours by
      project, weeks), JSON backup of all rows. Exports: save dialog on desktop, share sheet on Android.
- [x] Trip dialog: meals per trip day (`trip_meals`, id `<tripId>_<date>`).
- [x] Tests: report tables/CSV/PDF/backup (German), PDF visually checked.
- [x] Editing per-diem rates (Settings → Nachweise → Tagespauschalen, `per_diem_rates_screen.dart`):
      rows per country with "gilt heute" (core `perDiemRateOn`); the built-in DE rate is locked and
      superseded by a newer row; delete with undo.
- [x] Restore from the JSON backup (`docs/specs/backup.md`; core `decodeBackup`, `restoreBackup`):
      Berichte → "Sicherung laden"; syncs first, then the user picks Zusammenführen (like a sync,
      original clocks) or Ersetzen (fresh writes, on all devices) with a preview of the counts.
- [ ] Nicer charts (fl_chart) if wanted.

### Releases
- `v0.1.0` (2026-11-07): GitHub Release with Windows ZIP, Android APK, Linux tar.gz; README and the
  repo's About link to `releases/latest`. It was signed with the CI debug key; since v0.3.0 every
  APK carries the permanent release key (`docs/dev-setup.md` §5, set up 2026-11-08; checked again
  on v0.5.0: certificate SHA-256 `23:D0:B2:…:A4:E8`).

- `v0.2.0` (2026-11-07): project time as duration with summary.
  (v0.1.0 and v0.2.0 exist only in the old private repo `timetrack-private`.)
- `v0.3.0` (2026-11-08): JSON restore, sync log, sync on network change, per-diem rates screen;
  first release with the release signing key (phones uninstall the old debug-signed app once).
  CI steps that run build hooks go through `tool/retry-download.sh`: GitHub release downloads (the
  sqlite3 hook fetches its binary from there) returned error pages for a while on that day.
- `v0.4.0`, `v0.4.1` (2026-11-08): in-app updates, hourglass icon, Aurora colours.
- `v0.5.0` (2026-11-08): work PC start prompt and the eight picked improvements (theme, shortcuts,
  finish-time forecast, forgotten clock-out + reminders, week check, project page with budget,
  vacation planner, Windows tray). The first release that reaches v0.4.1 through the updater.
- `v0.5.1` (2026-11-08): work-PC feedback: usual break settings, undo snack bars that go away,
  new month view, no target before the balance start, "Mit Windows starten" as its own switch.
- `v0.5.2` (2026-11-09): a day type can be removed again ("Tagesart entfernen", with undo).

### M5: Android quick access (done)
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
- [x] Tested on the phone by the user (2026-11-08): "everything seems to work".

### Changes requested 2026-11-08 (before release v0.3.0), done
- [x] Actual vs. credited time told apart everywhere: Geleistet (`W`) and Angerechnet (`Cr`) side by
      side on Today, day, week, reports and the timesheet (legend; break column = gaps only, a
      deducted missing break is noted).
- [x] A project per trip (`trips.project_id`, picker in the trip dialog, column in the travel report).
- [x] Preview of timesheet and travel report in the app (`report_preview.dart`); PDF/CSV are
      downloaded from the preview.
- [x] Saturday, Sunday and holiday rules apply on **every** such day, not only on trips
      (calculations §9; holidays like Sundays, confirmed by the user).
- [x] Session dialog in the calendar: location as buttons (chips) instead of a dropdown, plus a
      "Reisetag" button: selected if the day lies in a trip (tap edits that trip), otherwise tap
      creates a trip prefilled with the day and the session's times.
- [x] Trip days (user, 2026-11-08): plane icon in front in the week view (other days: icon of the
      main location); only travel and on-site in the session dialog, no project time; the day's
      time is booked to the trip's project (calculations §3, order report and statistics).
- [x] Timesheet shows the number of trip days.
- [x] "Reisekosten" became the **Reisebericht**: per day also travel and on-site time, totals; PDF in
      landscape. Fixed: € was a box in all PDFs (built-in fonts lack it), now "EUR".
- [x] **Day types** (calculations §15, data-model §12): Büro, Homeoffice, Dienstreise, Urlaub, Krank,
      Kinderkrankentag, Gleitzeit, Kurzarbeit, Feier-/Trauertag, picked in the day editor and on
      Today (`DayTypePicker`), icon per type in front of each day in the week view. Office/home are
      `days` rows (id = date); trips stay trips; the rest are absences (new kinds `child_sick`
      credits the target, `short_time` lowers it). Office/home days allow project time, trips show
      travel/on-site time (`TripBookingCard`), absence days record nothing. The session dialog's
      "Reisetag" button was replaced by the day type picker.
- [x] Week view: hours per project per day in small print (`bookedByProject`, incl. trip project);
      swipe left/right for the next/previous week.
- [x] Working time on absence days (vacation, flexitime, sick, …) can be recorded and counts as
      overtime (§15). Calendar: "Zu heute springen" icon in the week and day view.
- [x] Day view: an X on every session, break, project time and absence deletes it after a
      confirmation.

### Redesign 2026-11-08 ("modern, dynamic, easy to use, clear"; all nine pitched ideas), done
- [x] **Theme** (`app/lib/app/theme.dart`): Material You wallpaper colours on Android 12+
      (`dynamic_color` 1.x; 2.x pulls in the separate `material_ui` package and doesn't compile with
      Flutter's Material), teal elsewhere; flat rounded cards, stadium buttons, tabular figures,
      `FadeForwards` transitions; semantic colours: `deltaColor`, `dayTypeColor`, `projectColor`
      (a stable colour per project id; projects have no colour field).
- [x] **Motion** (`widgets/motion.dart`): counting numbers (`AnimatedMinutes`), progress ring,
      haptics on clock-in/out/break, animated switches.
- [x] **Undo instead of "Are you sure?"** (`widgets/undo.dart`): deletes happen at once, the
      snackbar restores them (`deleted: false`); quick entry, templates and assignments can be undone.
- [x] **Today**: status + day-type chip (sheet with the 9 types), ring worked/target, difference and
      balance (tap explains), one adaptive button row, project cards in project colours (running one
      filled with a live timer), editable timeline, home-office quota bars.
- [x] **Timeline** (`widgets/day_timeline.dart`): sessions/breaks and projects as two lanes; drag
      edges (5-min steps), tap a hatched gap to book it (`DayWork.unassignedSpans`).
- [x] **Needs attention** (`widgets/attention.dart`): review items as cards with a fix: add break
      (prefilled by `suggestBreak`), set end, assign unassigned time (`ReviewKind.unassigned`, finished
      non-trip days only), end an open trip, open day; dismissable; collapsed after 2–3.
- [x] **Calendar**: week/month switch, month grid (type icons, delta tint, holidays red), balance
      sparkline, pull to sync, coloured project dots, tap numbers to explain.
- [x] **Explain the numbers** (`explainDay`, calculations §16; `widgets/explain_sheet.dart`).
- [x] **Navigation**: 4 tabs; settings (now grouped in cards with a search) open over them from the
      gear icon; sync indicator in the app bars; Ctrl+K command palette (actions, screens, projects).
- [x] **Setup wizard** (`/setup`): state, working time, balance + vacation carry-over, home-office
      limit; reachable from Today (until set up) and the settings.
- [x] **Reports dashboard**: balance curve, project donut, week bars vs target, home-office share.
- [x] **Faster entry** (calculations §17): quick entry line (`parseQuickEntry`), copy previous day,
      day templates (`day_templates` table, data-model §13).
- Not yet seen on a real phone; screenshots only (Linux, wide and 412 px).
- [x] Notice settings (user, 2026-11-08): each notice category on/off, "ohne Projekt" from a
      threshold (default 0:30); × dismisses a card for good (synced, `dismissed_notices`), the
      calendar keeps a small dot on the day, the day view lists hidden notices ("show again");
      settings can restore all dismissed ones.
- [x] Booking project time as a bottom sheet (user chose layout A, 2026-11-08): search as you type
      with matches below the field (name, project/order number, client; recent 5 when empty; ↑↓
      Enter; create from the text), duration in hours with −/+ 0:15 and chips (0:15 … 8:00, rest of
      the day), optional start time (quarter hours, end shown), comment with the project's last
      comments as chips. Also opened by "Zuordnen" and by tapping a timeline gap (prefilled).
- [x] Account vs. records (user, 2026-11-08; calculations §9.1): trip-day steps on Today (Anfahrt
      starten → Beim Kunden angekommen → Rückfahrt starten → Rückfahrt beenden), "Reisenachweis"
      card with exact leg times (tap to correct) and the account credit beside it; the travel report
      has Anfahrt / Beim Kunden / Rückfahrt with from–to times plus "Angerechnet (Konto)"; settings
      grouped into Arbeitszeitkonto (with travel and weekend crediting, each explained) and
      Nachweise.
- [x] Back behaviour (user, 2026-11-08; `docs/specs/navigation.md`): close → page up → reset view →
      previous tab → on Today ask once, then move to the background; days open inside the current tab.

- [x] Polish: the day view's quick-entry button folds to its icon while scrolling down
      (`CollapsingFab`); the booking sheet's time switch reads "Startzeit angeben" with a hint.

### In-app updates (requested by the user 2026-11-08; spec `docs/specs/updates.md`, ADR 0008)
- [x] Repo made public: history checked (no secrets, keystores, databases, real URLs or personal
      data), rewritten with the noreply address, pushed to a new public repo; old one renamed to
      `timetrack-private`. Android secrets set on the new repo, fork workflows need approval.
      v0.3.0 rebuilt and released there.
- [x] core `src/update/update.dart`: `AppVersion`, `Release.fromGitHub`, `fetchLatestRelease`,
      `parseSha256Sums`, `sha256Hex`, `UpdateState` (local_values `update_state`), `UpdateChecker`
      (24-h pause, auto switch, skip, notification once per version).
- [x] app `lib/update/`: `UpdateController` (start/resume check, manual check, install, restart),
      `downloadVerified`, installers (Android `PackageInstaller` via `UpdateInstaller.kt`, Linux
      bundle swap with rollback, Windows PowerShell script), banner above all tabs with notes dialog,
      Einstellungen → App (version, manual check, auto switch, release page), Android background
      check + system notification (`UpdateNotice.kt`, opens `timetrack://update`).
- [x] CI: `SHA256SUMS` and generated notes on releases; tag must match the pubspec version.
- [x] Version 0.4.0+4.

### App icon (requested by the user 2026-11-08; `branding/README.md`)
- [x] The user's hourglass: Android adaptive icon (original colours) with a monochrome layer for
      themed icons (Android 13+ tints it in the wallpaper colours); notification/tile/update icon
      `ic_quick` is the hourglass too; Linux and Windows in the app's teal (user's choice, those
      systems don't recolour icons). All generated by `tool/make_icons.py`.
- [x] Linux: icon in the bundle (`data/app_icon.png`), window icon set by the runner, launcher on
      the maintainer machine points there.
- [x] Colours reworked (user, 2026-11-08): turquoise gradient "Aurora" (`#34D399` → `#22D3EE` →
      `#3B82F6`) on all platforms instead of orange/pink/purple and the separate teal desktop icon.
- [ ] Check on the phone (launcher, themed icons on/off, notification, tile) and on Windows (exe,
      taskbar) with the next release.
- [x] Released v0.4.0 (2026-11-08; with the hourglass icon). Checked against the real release: the
      Linux path (fetch, download, checksum, folder swap) works; APK signed with the release key.
- [ ] The user installs v0.4.0 once by hand on all three systems.
- [x] v0.4.1 released (2026-11-08): Aurora icon colours; the updater's real test release.
- [ ] With v0.4.1, test the updater for real: Android (unknown-apps permission, confirm,
      data kept), Linux (`~/.local/opt/timetrack` swap + restart), Windows (script replaces the
      folder, app restarts). The Windows script has not run on a real PC yet.

**Next tasks**: the user reinstalls the phone app once (new key, v0.3.0 or later) and re-enters the
three reset settings; then release v0.4.0 and test the updater with v0.4.1.

### Work PC start prompt (requested by the user 2026-11-08; spec `docs/specs/work-pc.md`)
- [x] core `StartPrompt` (`offer`, `decline`), `trackedToday`, `defaultClockInLocation` (shared
      with the quick actions).
- [x] app `lib/work_pc/`: Run key via `reg.exe`, setting Einstellungen → App → Arbeits-PC (Windows
      only), `StartPromptHost` (sync up to 20 s, then the dialog). Windows runner: `--autostart`
      starts minimized, channel `timetrack/window` `show`.
- [ ] Windows runner changes only built in CI so far. **User**: on the work PC switch it on, sign
      out and in (dialog comes), clock in, sign out and in again (stays minimized, no dialog).

### Improvements picked by the user (2026-11-08; 8 of 10 suggested ideas, one commit each)
Not wanted: lock/sleep detection on Windows, copying hours for the company booking system.
- [x] Theme: Einstellungen → App → Design (System/Hell/Dunkel), on Android 12+ "Farben vom
      Hintergrundbild" on/off; device-local (`local_values` `theme_mode`, `wallpaper_colors`), read
      before the first frame (`app/lib/app/appearance.dart`). Seed colour is now the icon's cyan
      `#22D3EE` instead of teal.
- [x] Keyboard shortcuts (navigation.md, "Keyboard shortcuts"): Ctrl+E/P/B/J, Ctrl+1–4, Ctrl+,, F5,
      F1/? help; ←/→, T, M on the calendar and day pages (`PageKeys`); plain keys stay out of text
      fields. Today, palette and keys share `app/lib/app/actions.dart`; the palette shows the keys.
- [x] Finish-time forecast (calculations §18, core `dayForecast`): Today shows "Soll erreicht um …
      (inkl. n min Pause) · 10 Std. um …" while clocked in; the Android notification shows the target
      time as subtext (`QuickStatus.targetAt`, `qa_finish_text`; Kotlin not yet built locally).
- [x] Forgotten clock-out and reminders (new spec `reminders.md`): core `forgottenClockOut` (suggested
      ends: last activity, target reached, usual finish), `TimeTracker.clockOut(at:)`,
      `nextReminders` (break due at 5:45 h of a stretch, long day at 9:45 h); app
      `ForgottenClockOutHost` (start and resume; "Ich arbeite noch" not asked again), settings
      Allgemein → Erinnerungen (Android/Windows), Android: one-off WorkManager task `reminder` at the
      next due time + `ReminderNotice.kt` (channel "Erinnerungen", action Pause/Ausstempeln); debug
      APK builds. **User**: check the reminders on the phone. Windows reminders come with the tray.
- [x] Week check (calculations §12, "Checking a week or month"): the week view sums its notices in
      one card ("6 Hinweise an 4 Tagen", a line per day) with "Woche prüfen"; the check steps
      through them (fix, Ausblenden, Überspringen, "Alles erledigt"); "Woche vollständig" /
      "Monat vollständig" (reports) when nothing is open (`openNoticesProvider`, `runReviewFlow`).
- [x] Project page with hour budget (calculations §3.1, data-model §3 `budget_min`): `/projects/<id>`
      with this week/month/year/total, budget bar (amber from 80 %, red above 100 %), recent weeks,
      history per day with the notes, start timer, book time (preset), CSV, favourite/archive; budget
      bars in the list; notices `project_budget_near`/`_over` (category "Projektbudget") open the
      page. Core `projectHistory`, `budgetItems`. The demo seed gives "Werk Süd Umbau" 20 h.
- [x] Vacation planner (calculations §10.1, core `bridgeDays`): Kalender → ⋮ → Abwesenheiten is now
      the "Urlaubsplaner": year switcher, vacation account, bridge days (1–3 workdays next to a
      holiday block, best ratio first, "Eintragen" with undo, a jump to next year when none are
      left), 12 mini months (holidays red, absences in their colours, bridge days ringed, tap adds
      an absence), the year's absences with undo-delete. Fixed: the absence dialog's type dropdown
      overflowed with long names.
- [x] Windows tray icon (work-pc.md §3): runner `Shell_NotifyIcon` (grey `app_icon_idle.ico` while
      clocked out, tooltip, menu from Dart via `setTray`, `trayAction` back, `notify` balloons,
      `hide`, `quit`, `setCloseToTray`, re-add on `TaskbarCreated`); Dart `TrayHost`: status,
      clock in/out, break, five projects, switch/book, open, quit; reminders as Windows
      notifications; Einstellungen → App → "Im Infobereich weiterlaufen" (default on; close hides);
      a quiet autostart goes to the tray; the updater quits through the channel. **Only compiled in
      CI; user test on the work PC pending.**

### Feedback from the work PC (2026-11-08, after v0.5.0), done
- [x] Usual break (calculations §4.1): settings "Übliche Pause: Beginn / Dauer" (synced, default
      12:00 / 30 min) prefill a new break, the missing-break fix (`suggestBreak(preferred:)`) and
      quick entry (`p` alone = usual length, placed at the usual start if it fits).
- [x] Snack bars: an "Undo" no longer stays until tapped (Flutter keeps snack bars with an action
      by default; now `persist: false`), and `SnackBarDismisser` (router observer) hides it when a
      dialog or sheet opens. It covered the booking sheet's "Buchen" on Windows.
- [x] Month view rebuilt: row height follows the window so six weeks fit; cells show hours and ±,
      day type, holiday, notice dot; calendar-week column with the week's ± (tap opens the week);
      tap a day opens the day; compact summary (worked, target, ±, balance, curve).
      `/calendar?view=month` opens it directly.
- [x] Days before the balance start (§8) show no target or ± and stay out of the totals and the
      curve (the schedule starts on 1 January for the vacation account, so October showed
      −176:00); a month before the start says so. `Ledger.inBalance`.
- [x] Windows: separate switch "Mit Windows starten" (the HKCU Run key, work-pc.md §1); "Arbeits-PC"
      is now only the question after sign-in (`local_values` `start_prompt`, default on so
      existing setups keep asking) and turns the autostart on with it.
- [x] A day type can be removed (calculations §15, `clearDayType`): "Tagesart entfernen" in the
      picker deletes the `days` row and the day's absences (not `extra_holiday`), with undo; a trip
      day points to the trip.

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
- **Dropped** (user, 2026-11-08): M6 Garmin glance, M7 auto clock-in (Wi-Fi/geofence) and testing
  sync over the company VPN. Don't plan them again unless the user asks.
- **Travel rules** confirmed: every weekday of a trip counts as a normal day (also days spent only
  working at the destination); a short trip day still gets the full target; the 11 h **Saturday cap
  covers travel and work together** (`SaturdayCapScope.total`); holidays like Sundays. Full-time
  Mon–Fri, so the day-off rule doesn't apply yet.
- **Trip Sundays → Sunday hours** (user, 2026-11-07): travel and on-site work on a trip Sunday count
  as Sunday hours for HR (extra pay), max 11 h, shown in the monthly timesheet, **not** in the
  overtime balance (`travel.sunday = sunday_hours`, `travel.sunday_cap_min = 660`, calculations §9).
  Holidays on trips follow the same rule. All travel rules are now editable in Settings.
- **Weekend and holiday rules apply on every day** (user, 2026-11-08), trip or not: Saturday work is
  overtime up to the cap, Sunday and holiday work become Sunday/holiday hours (not in the balance).
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
- **Windows PC is company-managed and sometimes on a VPN** (user, 2026-11-07; VPN testing dropped 2026-11-08). For M3:
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
- 2026-11-08, Claude Code: user confirmed M5 on the phone. Worked vs. credited everywhere, project per
  trip, report preview, weekend/holiday rules on all days, location and trip-day buttons in the
  session dialog, trip days booked to the trip project, Reisebericht, day types, project hours in the week,
  week swipe, quick delete. core 190 tests, app 14 widget tests.
- 2026-11-08, Claude Code: redesign (theme, motion, undo, Today, timeline, attention cards,
  calendar month view, explanations, navigation + command palette, settings search, setup wizard,
  reports dashboard, quick entry, day templates). Core: `explainDay`, `parseQuickEntry`, day
  templates, `unassignedSpans`, `ReviewKind.unassigned`, `suggestBreak`; 205 core tests, 19 widget
  tests green.
- 2026-11-08, Claude Code: notice settings and permanent dismissal (calculations §12, data-model §14);
  208 core tests, 20 widget tests green.
- 2026-11-08, Claude Code: project booking sheet (`snapToQuarter`, `recentNotes`); 210 core tests,
  21 widget tests green.
- 2026-11-08, Claude Code: travel record vs. overtime account (`tripLegs`, `tripSteps`); 213 core
  tests, 22 widget tests green.
- 2026-11-08, Claude Code: back navigation concept and implementation; 23 widget tests green.
- 2026-11-08, Claude Code: release v0.3.0 (GitHub release downloads served error pages; CI now
  retries that with `tool/retry-download.sh`). Repo made public with rewritten history (noreply
  address), old one kept as `timetrack-private`. In-app updates (spec `updates.md`, ADR 0008): core
  checker, app banner/settings/installers, Android notification, CI checksums and tag check.
- 2026-11-08, Claude Code: work PC start prompt on Windows (spec `work-pc.md`); 242 core tests,
  40 widget tests green.
- 2026-11-08, Claude Code: app review with 10 suggestions, the user picked 8 and all are built (one
  commit each): theme switch, keyboard shortcuts, finish-time forecast, forgotten clock-out +
  reminders, week check, project page with budget, vacation planner with bridge days, Windows tray.
  New spec `reminders.md`; calculations §3.1, §10.1, §12 (checks), §18. 272 core tests, 58 widget
  tests green.
- 2026-11-08, Claude Code: work-PC feedback after v0.5.0: usual break settings, snack bars that
  go away and don't cover sheets, new month view, no target/± before the balance start. 274 core
  tests, 63 widget tests green.
- 2026-11-08, Claude Code: Windows autostart as its own setting, split from "Arbeits-PC".
  65 widget tests green.
- 2026-11-08, Claude Code: day types can be removed (with undo). 275 core, 66 widget tests green.
- 2026-11-09, Claude Code: release v0.5.2; docs prepared for handoff to GitHub Copilot ("Where things stand" at the top, AGENTS.md: working with the maintainer, where things live, Copilot notes; prompt files in `.github/prompts/`; architecture module table and README brought up to date).
