# TimeTrack (working title): concept & implementation plan

## Context

You want one personal app on **Linux (Fedora/GNOME)**, **Windows** and **Android** that records **working hours** (as an employee) and **time per project**, and **syncs automatically** between the devices. Nothing exists yet; this is a new project. Decisions we made together:

| Topic | Decision |
|---|---|
| Stack | **Flutter** (Dart): one codebase, native builds for all 3 platforms |
| Work context | **Employee**: target hours, overtime balance, vacation/sick days, public holidays, German Working Hours Act (ArbZG) checks |
| Time model | **Two layers**: attendance (clock in/out + breaks), with project timers running inside it. Time not assigned to a project is shown as "unassigned". |
| Projects | Each project has a **name, project number and order number**. A single search covers all three, plus the client. Project time is mainly recorded as a **duration (H:MM) with a short summary**; a start/end time is optional. Stopping the timer always asks for a summary |
| Docs for agents | AGENTS.md, specs, decision records, a status/handoff log and dartdoc, so any agent (GitHub Copilot, Claude Code, …) can continue at any time |
| Home office | Every session has a **location** (office / home / on-site / travel). Allowed home-office share as a **weekly or monthly percentage**, with "remaining" display, forecast and warning |
| Travel | **Trips** with travel calendar, **travel time** recorded separately, your employer's crediting rules (weekday = normal day, Saturday = overtime up to 11 h, Sunday = not counted), **per-diem basis** for expense claims |
| Sync | **Local-first, no own server.** Each device writes files that are never changed afterwards to **your Nextcloud via WebDAV** |
| Windows build | **GitHub Actions** (private repo); Flutter can't cross-compile to Windows |
| Outputs | Monthly **timesheet PDF**, **travel report**, **order report** (hours per order number), **CSV export**, **in-app statistics** |
| Extras, in order | 1. Android quick access, 2. Garmin fēnix 7 Pro glance, 3. Auto clock-in |

Assumptions (easy to change): UI in German and English; federal state (Bundesland) chosen in settings; home time zone Europe/Berlin; repo at `~/dev/timetrack`.

---

## 1. Architecture

```
 Android phone           Linux desktop           Windows PC
┌─────────────┐        ┌─────────────┐         ┌─────────────┐
│ Flutter UI  │        │ Flutter UI  │         │ Flutter UI  │
│ core (Dart) │        │ core (Dart) │         │ core (Dart) │
│ SQLite      │        │ SQLite      │         │ SQLite      │
└──────┬──────┘        └──────┬──────┘         └──────┬──────┘
       └────── WebDAV over HTTPS (Nextcloud app password) ──┘
                              ▼
        Nextcloud  /TimeTrack/devices/<deviceId>/ops/*.jsonl.gz.enc
 fēnix 7 Pro ── Connect IQ SDK (BLE) ──► Android app
```

- Each device keeps its **own SQLite database** and works fully offline. Sync merges in the background.
- All logic (database, rules, sync) lives in a **pure-Dart `core` package**. It can be tested with `dart test`, without Flutter or devices.
- The Flutter app contains only the UI and platform integrations (notifications, tile, widget, watch, geofence).

## 2. Domain model

Tables that sync (id = UUIDv7; each row also stores `field_clock` JSON and a `deleted` tombstone):

| Table | Fields (main) |
|---|---|
| `work_sessions` | start_utc, end_utc? (null = clocked in), tz, **location** (office / home / on_site = working at the destination / travel = time in transit), source (app/manual/auto/watch), note |
| `breaks` | start_utc, end_utc?, note. Matched to sessions by time interval, not by foreign key, which keeps merging simple |
| `projects` | **name, project_number, order_number**, client?, color, favorite, archived, last_used_at |
| `project_entries` | project_id, start_utc, end_utc? (null = running), note, source |
| `absences` | date, kind (vacation, sick, special_leave, comp_time, extra_holiday), fraction (1 or 0.5), note |
| `work_schedules` | valid_from, target minutes for each weekday Mon–Sun, annual vacation days. Several rows handle contract changes over time |
| `settings` | key/value: Bundesland, break-rule mode, starting overtime balance + date, vacation carry-over, reminders, home-office day rule, travel crediting rules (Saturday cap 11 h, …) |
| `home_office_rules` | valid_from, period (week/month), unit (days/hours), max_percent, basis (days worked / scheduled workdays). Several rules can apply at once, e.g. 50 %/week and 40 %/month |
| `trips` | depart_utc, return_utc? (null = still travelling), destination, country (ISO), purpose, project_id?, note |
| `trip_meals` | trip_id, date, breakfast / lunch / dinner provided (reduces the per-diem) |
| `per_diem_rates` | country, valid_from, rate for a partial day (>8 h, or arrival/departure day), rate for a full 24 h day. You can edit them |

Local only: `outbox`, `pending_batch`, `seen_files`, `sync_state`, HLC state, device id. The Nextcloud app password goes into `flutter_secure_storage` (libsecret on Linux, Credential Manager on Windows, Keystore on Android).

**How the two layers interact**
- Starting a project while clocked out clocks you in automatically (setting, on by default).
- Clocking out stops the running project.
- Starting a break stops the running project. Ending the break offers to resume the last project (or does it automatically, if set).
- Only one session and one project entry can run at a time. Starting project B stops project A at the same instant.
- **Location** is chosen when you clock in, with 🏢 office / 🏠 home / 📍 on-site / 🚆 travel next to the button. It defaults to the last location used, or an E3 rule sets it (home Wi-Fi → home). You can change it afterwards. A mixed day is simply several sessions, for example 🏠 → 🚆 → 📍.
- **Trips**: starting a 🚆 session when no trip is open starts a trip. The app asks for the destination; the country defaults to Germany. When you clock out of a travel session, it asks whether the trip has ended. Departure and return can be edited, and trips can also be entered afterwards.
- Forgotten clock-out: if a session has been open for more than 12 h, a notification appears. The next time you open the app it asks "Clocked in since yesterday 08:00. When did you finish?"

## 3. Calculations (`core`, fully unit-tested)

- **Worked time per day** = |union of sessions| − |union of breaks within sessions|, cut at local midnight. Unions make duplicate or overlapping entries (for example after an offline conflict) harmless to the totals.
- **Unassigned** = worked − |union of project entries within sessions|.
- **ArbZG checks:**
  - §4 breaks: ≥30 min if you work >6 h, ≥45 min if >9 h. Only break segments of ≥15 min count.
  - §3: more than 10 h per day.
  - §5: less than 11 h rest between working days.
  - §9: work on Sundays or public holidays.
  - Mode *warn* (default) or *auto-deduct missing break*. Auto-deduct never pushes the day below the threshold.
- **Target per day** comes from the schedule valid on that date. It is 0 on public holidays. Vacation, sick and special leave credit the target (× fraction). `comp_time` (Überstundenabbau) does not credit it, so it reduces the balance.
- **Overtime balance** = starting balance + Σ(credited − target) up to yesterday, with today shown live on top. *Credited* is the time worked, except on trip days (see Travel).
- **Vacation account**: entitlement + carry-over − vacation taken, counted in workdays (target > 0, not a holiday).
- **Home office**:
  - *Which days count*: a worked day is a home-office day if **most of its worked time** was at home (default). Alternatives: any time at home, or a share of the day (a half-and-half day counts as 0.5).
  - *Quota*: for each rule (week = Mon–Sun, or calendar month), used = home-office days (or hours) ÷ basis. The basis is **days actually worked** (default) or scheduled workdays (target > 0, without holidays and absences). Trip days count in the basis but never as home office.
  - *Forecast*: how many more home-office days fit into the rest of the period if you work every remaining scheduled day. Example: limit 40 %/month, 8 days worked of which 5 at home, 12 workdays left → 40 % of 20 = 8 → **3 more** allowed.
  - *Warning* (never a block) when clocking in at home would exceed a rule: a notice on clock-in plus an entry in the Review list.
  - *Yearly count* of home-office days, useful for the Homeoffice-Pauschale in your tax return.
- **Travel: credited working time.** These are your employer's rules, each one a setting. Every local date a trip touches is a trip day.

  | Trip day | Credited working time |
  |---|---|
  | Mon–Fri workday | exactly the day's **target** (a "normal workday"), even if work + travel took longer; no overtime, no minus |
  | Saturday | 🚆 travel and on-site work count as **overtime**, max **11 h** for the whole day (setting) |
  | Sunday | 🚆 travel time is **not counted**; work on-site counts as usual |
  | Public holiday | like Sunday (setting) |

  The actual times are still recorded and shown, and the ArbZG warnings use them.
- **Travel: per-diem basis** (Verpflegungsmehraufwand). For each trip day the app records hours away from home and a category:
  - single-day trip of more than 8 h;
  - arrival or departure day of a multi-day trip;
  - full 24 h day.

  A one-day trip that crosses midnight without an overnight stay counts on the day with more hours. Amounts come from `per_diem_rates`, pre-filled with the domestic rates; check them when implementing, and add foreign rates by country as needed. Meals that were provided reduce the amount.
- **Public holidays**: computed locally for all 16 Bundesländer (fixed dates, Easter-based dates, state-specific days, Buß- und Bettag). Extra company days off are entered as `extra_holiday` absences.

## 4. Sync design (Nextcloud / WebDAV, no server)

**Folder layout**
```
/TimeTrack/
  format.json                       # format version (newer format → app asks to be updated)
  devices/<deviceId>/device.json    # name, platform
  devices/<deviceId>/ops/<hlc>.jsonl.gz.enc   # encrypted, never changed after upload
```
Each device writes **only to its own folder**, so two devices never write the same file and file conflicts can't happen.

**Change format**: per-field last-writer-wins, ordered by a hybrid logical clock (HLC = millisecond timestamp + counter + device id, sortable as a string).
```json
{"tbl":"project_entries","id":"0193…","hlc":"1762502400123-0000-a1b2","set":{"end_utc":"2026-11-07T11:00:00Z"}}
```
Applying a change is **idempotent and order-independent**: a field is updated only if the incoming HLC is newer than that field's clock. Every device therefore reaches the same state no matter in which order files arrive. Per-field rather than per-row matters because it stops a stale note edit on one device from "un-stopping" a timer that was stopped on another.

**Write path**: one SQLite transaction updates the row, its `field_clock` and the `outbox`. Every write goes through one `SyncedRepository`.

**Sync cycle**
1. **Push**: freeze the outbox into a `pending_batch` (name + list of changes, stored locally), then `PUT` it with `If-None-Match: *`. A 412 response means an earlier attempt already uploaded it, so it counts as done. Then clear the outbox. A crash between steps therefore never loses or duplicates changes.
2. **Check**: `PROPFIND` (Depth 0) on `/TimeTrack`. Nextcloud updates a folder's ETag whenever anything inside it changes, so an unchanged ETag means there is nothing to pull.
3. **Pull**: list `devices/` (Depth 1). For each folder whose ETag changed, list its `ops/` and `GET` the files not yet in `seen_files`. Apply each file in a transaction.
4. **Resolve**: if more than one session or project entry is still open after merging, the older one is closed at the newer one's start time. Every device computes the same value, so the result converges. Anything else unusual goes to a **Review** list: overlapping project entries, project time outside a session, ArbZG warnings.

**Triggers**: 5 s after each local change (debounced); on app start and resume; every 60 s while the app is in the foreground; on network change; on Android, a WorkManager job every 15 min plus a one-off job after background writes (from notification, tile, widget or watch).
**Expected delay**: about 1 min between devices in the foreground; at most 15 min for background pulls on Android.

**Sign-in**: Nextcloud **Login Flow v2**. You enter the server URL, a browser opens, you approve, and the app receives its own app password, so you never type a password into the app.

**End-to-end encryption** (decided 2026-11-07, since your Nextcloud is run by a provider): every sync file is encrypted with AES-256-GCM, using a key derived from a sync passphrase you enter once per device. The provider only sees file names and sizes. Details: `docs/specs/sync-format.md` §10, ADR 0006.

**Later**: compaction (a device merges its own old files; applying changes twice is harmless).

## 5. UI (Material 3, phone and desktop layouts)

1. **Today**: large *Clock in/out* and *Break* buttons, the running timer, favorite projects as chips for one-tap switching, a timeline (session bar, project bars, unassigned gaps), worked vs target, the overtime balance, and the **home-office quota** ("🏠 5 of 8 this month · 3 left").
2. **Week/Calendar**: one row per day with a location icon, worked, credited, target, difference, absences, 🧳 trip days with destination, and warnings, plus a quota bar for the week and the month. Tapping a day opens the **day editor** (add or edit sessions, breaks and entries on the timeline).
3. **Projects**: create, edit, archive, colors, favorites, totals.
   - **Project picker with search**, used wherever you choose a project: Today, the day editor, the "Switch project" action in the notification, and report filters.
     - One field searches **name, project number, order number and client** together. Every word you type must match one of those fields, so `bosch 014` finds project 014 for the client Bosch.
     - Typing variations still match. Case doesn't matter, umlauts match both ways (ü = u = ue), and separators in numbers are ignored: `P-2026/014` is found by `2026014`, `2026/014` or `014`.
     - Order of results: exact number match, then numbers starting with your input, then numbers containing it, then fuzzy matches (letters in the right order). Within each group, recently and often used projects come first. Archived projects appear only when you switch them on.
     - Each result shows `Name · project no. · order no.` with the matching parts highlighted. On desktop, Ctrl+K opens the picker, ↑↓ moves, Enter selects. If nothing matches, you can create a project from the search text.
     - The search logic lives in `core` and runs in memory, which is instant for a few hundred projects. It is unit-tested.
4. **Absences**: calendar of vacation and sick days, vacation account.
5. **Reports**:
   - **Statistics** (fl_chart): hours per project, weekly worked vs target, overtime balance curve, home-office share per week/month against the limit.
   - **Monthly timesheet PDF**: per day start, end, breaks, worked, target, difference, **location**, trip marker and notes. Month totals, balance at the start and end of the month, vacation, **home-office days and % vs limit**, a signature line, and optionally a page with project totals.
   - **Travel report**, per trip and per day: departure and return, destination, travel time, credited time, hours away, per-diem category, meals provided and amount. Available as PDF and CSV as the basis for your expense claim.
   - **Order report**: hours per **order number** (and project number) per day or week, for copying into your company's booking system.
   - **CSV export**: entries (with location, project number and order number) and daily summaries, with an Excel-friendly option (`;` separator, UTF-8 BOM). Also a full JSON backup.
6. **Settings**: schedules, Bundesland, break rules, starting balance, home-office rules, travel rules and per-diem rates, Nextcloud connection with sync status and log, auto clock-in rules, watch.

## 6. Extras

**E1: Android quick access**
- An ongoing notification while clocked in, with a live timer (`usesChronometer`, no foreground service needed) and actions *Break/Resume*, *Clock out* and *Switch project*.
- A **Quick Settings tile** (Kotlin `TileService`) to clock in or out.
- A **home-screen widget** showing status, today's total and buttons; a native `Chronometer` keeps it ticking without updates.
- Tile, widget and notification all hand off to **one background Dart callback**, so all the logic stays in Dart. The database is opened in shared-isolate WAL mode so the UI, background handlers and WorkManager can all write safely.

**E2: Garmin fēnix 7 Pro glance** (reuses your `ciq` toolbox and developer key)
- A Connect IQ watch app with a glance for `fenix7pro`. The glance shows "● 3:42 · Project A". The app menu has Clock in/out, Break and Switch project (favorites).
- The Android app includes the **Connect IQ Mobile SDK** in a Kotlin bridge. The watch sends commands, and the phone answers with the current state, which the watch caches for the glance.
- **Spike first**: check that watch messages reach the app while it is in the background. Fallback: a small foreground service while clocked in.

**E3: Auto clock-in (Android)**
- Rules are based on **Wi-Fi name** (network callback through a PendingIntent; needs location permission) and/or a **geofence** (Play Services Geofencing).
- Each rule sets the session location too: office Wi-Fi → 🏢, home Wi-Fi → 🏠. That way home-office days are recorded correctly without you having to think about it.
- Each rule has a mode: *off*, *suggest* (default: notification with a "Clock in" action) or *automatic + Undo*.
- Leaving the office only ever suggests clocking out, using the time you actually left.

## 7. Repo layout, tooling, CI

```
~/dev/timetrack/
  AGENTS.md             # entry point for every coding agent (see section 8)
  CLAUDE.md             # symlink → AGENTS.md
  .github/copilot-instructions.md   # short pointer to AGENTS.md for GitHub Copilot
  packages/core/        # pure Dart: models, drift DB, rules, holidays, HLC, sync engine, WebDAV client, project search
  app/                  # Flutter: features/{today,calendar,projects,absences,reports,settings}, platform/
    android/…/kotlin/   # TileService, widget, Connect IQ bridge, network and geofence receivers
  garmin/               # Monkey C watch app + glance (built inside the `ciq` toolbox)
  docs/
    concept.md          # this concept
    status.md           # living progress and handoff log
    architecture.md
    dev-setup.md        # exact commands: toolbox, Flutter, Android, phone pairing, CI secrets
    specs/sync-format.md    # rules for the sync files and merging
    specs/calculations.md   # every time, overtime, home-office and travel rule, with worked examples
    decisions/NNNN-*.md     # architecture decision records (ADRs)
  .github/workflows/ci.yml
```

- **Key packages**:
  - drift (SQLite), flutter_riverpod, go_router, uuid (v7)
  - http + xml (a small custom WebDAV client: PROPFIND/MKCOL/PUT/GET/DELETE)
  - flutter_secure_storage, workmanager, flutter_local_notifications, home_widget
  - fl_chart, pdf + printing, share_plus/file_selector
  - timezone/flutter_timezone, connectivity_plus, url_launcher, flutter_localizations
- **Dev environment**: a new Fedora **toolbox `flutter`**. The host has no clang/cmake/ninja, and `sudo` on the host is awkward from here, while it works without a password inside a toolbox. Inside it: Flutter stable, clang, cmake, ninja, gtk3-devel, libsecret-devel, a JDK, Android cmdline-tools. The phone connects over **wireless debugging** (`adb pair`), which avoids USB permissions in the container.
- **CI (GitHub Actions, private repo, sized for the free plan)**: GitHub Free includes 2,000 Actions minutes per month for private repos. Windows minutes have counted double, so we assume that. Storage for Actions artifacts is limited (500 MB on Free).
  - **On every push**: tests only, on Linux (core, app, Nextcloud service container), about 5 min.
  - **Linux and Android**: built locally in the toolbox day to day. CI builds them only for releases.
  - **Windows**: built only on a `v*` tag or by manual trigger (`workflow_dispatch`), about 10–15 min, so about 20–30 billed minutes.
  - Flutter SDK and pub cache are reused between runs; build artifacts are kept for 7 days. The finished builds are attached to GitHub Releases, which doesn't use Actions storage.
  - Estimate: 60 pushes plus 10 releases a month is about 750 of the 2,000 minutes.
  - Build outputs: Linux `tar.gz`; Android signed APK (keystore stored in repo secrets); Windows **portable ZIP** (per-user, no admin rights, plus an optional per-user installer).
  - `gh` isn't installed. We'll set up the repo through the web UI or install `gh` in the toolbox.
  - **Fallbacks** if Actions on the free plan causes problems:
    1. Make the repo public: standard runners are then free with no minute limit. The code contains no personal data, and the keystore stays in secrets.
    2. A Windows VM in GNOME Boxes.
- **Installing**:
  - Linux: copy the bundle to `~/.local/opt/timetrack` and add a `.desktop` launcher, the same way as your `ciq-*` launchers.
  - Android: sideload the APK.
  - Windows: unzip and run. Unsigned builds trigger a SmartScreen warning once.

## 8. Documentation & agent handoff

Goal: any agent (GitHub Copilot, Claude Code, …) or person can take over at any point **without this conversation**.

- **`AGENTS.md`** is the single entry point. It covers what the app is, a map of the repo, the exact commands (setup, test, format, analyze, build, run on the phone), the code conventions and the definition of done. It also sets the rule: **read `docs/status.md` first, update it last.** `.github/copilot-instructions.md` and `CLAUDE.md` point to it, so every tool reads the same instructions.
- **`docs/status.md`** is the handoff log: current milestone, done / in progress / next tasks as checklists, known issues, and notes from the last session. It is updated at the end of every work session.
- **Specs before code**:
  - `specs/sync-format.md` describes the folders, the change format, the HLC, and the merge and resolve rules. It is precise enough that someone could write a compatible client from it.
  - `specs/calculations.md` gives every rule with worked examples.
  - Tests refer to the spec sections they check.
- **Decision records** (`docs/decisions/`): one short file per decision (context, decision, consequences), e.g. Flutter, the two-layer model, Nextcloud file sync, per-field last-writer-wins.
- **In the code**:
  - `///` dartdoc on every public API in `core`. The lint `public_member_api_docs` makes missing docs fail CI.
  - Comments explain *why*, not *what*.
  - A README for each package.
  - Tests are named after the rule they check, e.g. `ArbZG §4: 6:01 h without break → 30 min missing`, so they also serve as a spec you can run.
- **Checks in CI**: `dart format`, `dart analyze --fatal-infos` and the tests. Any agent gets immediate feedback.
- **Tasks as GitHub issues**: each milestone is split into small issues with acceptance criteria, so you can hand a single task to any agent (for example Copilot's coding agent, if your Copilot plan includes it). Commits follow Conventional Commits, each small and focused.

## 9. Milestones

| # | Content | Done when |
|---|---|---|
| M0 | Toolbox, Flutter and Android SDK, repo + GitHub, CI builds an empty app for all 3 platforms, `AGENTS.md`, `docs/` skeleton with the concept, first decision records and `status.md` | The Windows ZIP from CI starts on your Windows PC and that PC can reach Nextcloud |
| M1 | `core`: models, DB, interval math, ArbZG, holidays, overtime and vacation, home-office quota, travel crediting and per-diem, project search, HLC, change merging, sync engine against fakes | `dart test` is green, including the sync convergence tests |
| M2 | Local MVP app: Today (with location and quota), day editor, week view, projects, absences, schedules, home-office rules, trips, project picker and settings | Usable every day on Linux and Android, still without sync |
| M3 | Nextcloud sync: WebDAV client, Login Flow v2, end-to-end encryption, proxy/VPN handling, triggers, status and log, Review list | Two real devices stay in sync through your Nextcloud |
| M4 | Reports: statistics, monthly PDF, order report, travel report, CSV and JSON backup | The PDF and travel report for one month match figures calculated by hand |
| M5 | E1 Android quick access | Clock in/out from the tile, widget and notification without opening the app |
| M6 | E2 Garmin glance (after a feasibility spike) | Clock in on the watch; the desktop shows it after the next sync |
| M7 | E3 Auto clock-in | The office Wi-Fi rule triggers the suggestion and auto mode reliably |

Every milestone also ends with: docs updated (`status.md`, specs, decision records) and CI green.

## 10. Verification

- **Unit tests (core)**: holidays for each Bundesland against known 2026/2027 calendars; ArbZG edge cases (6:00 vs 6:01, break segments shorter than 15 min); DST days; sessions over midnight; contract changes in mid-period; half vacation days; overtime and vacation balances; home-office quota (mixed days, weeks spanning two months, holidays and vacation in the basis, business-trip days, the forecast, a rule change in mid-month).
- **Travel**:
  - Crediting: a weekday trip day longer or shorter than the target; Saturday under and over 11 h; Sunday; a public holiday; a trip that spans a weekend.
  - Per-diem: a day trip of 7:59 vs 8:01 h; a multi-day trip; a day trip crossing midnight; reductions for provided meals.
- **Project search**: `P-2026/014` found by `2026014`, `014` and `2026/014`; several words must all match (`bosch 014`); umlaut folding; ranking order; archived projects hidden.
- **Handoff test**: a new agent session that has only the repo (no chat history) can follow `AGENTS.md` to run the setup and the tests and name the next open task.
- **Sync convergence (property-based)**: 3 simulated devices make random changes, sync in random order with simulated crashes and repeated uploads. Every device must end with an identical database, and no change may be lost or applied twice.
- **WebDAV integration**: a local Nextcloud run with `podman` (`nextcloud:stable`, SQLite) runs the real push/pull code and Login Flow v2. The same tests run in CI. Development never touches your real Nextcloud.
- **End-to-end by hand**:
  1. Clock in on the phone; the desktop shows it within about 1 min.
  2. Put the phone in airplane mode and edit on both devices; after reconnecting, both show the same data.
  3. Clock in on both devices while offline; after sync, the older session is closed at the newer one's start.
  4. Stop from the tile, widget or watch; the change reaches the desktop.
- **CI**: all three builds green on every push; release artifacts install and start.

## Risks / open points

- **Travel rules, confirmed 2026-11-07**:
  1. The weekday rule applies to **every** day of a trip.
  2. A shorter weekday trip day also gets the full target.
  3. The 11 h Saturday cap covers travel **and** work together.
  4. Public holidays are treated like Sundays.

- **Background delivery of watch messages on Android**: checked in the M6 spike.
- **Your Nextcloud** is run by a provider, so end-to-end encryption is part of M3 (ADR 0006). The URL is entered at M3.
- **Windows PC**: it's company-managed and sometimes on a VPN. M0 confirmed that the portable ZIP runs and Nextcloud WebDAV is reachable. In M3, handle the system proxy and VPN changes (see `docs/status.md`).
- **GitHub Free**: some users have recently reported "Usage blocked" in private repos without a payment method, even with minutes left. M0 checks this with the first Windows build; if it happens, use a fallback from section 7.
- **GNOME/Wayland**: no tray icon needed for now (not chosen), which avoids the AppIndicator dependency.
