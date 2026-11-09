# AGENTS.md: TimeTrack

Instructions for **every** coding agent (GitHub Copilot, Claude Code, Codex, Cursor, …) and for humans.
`CLAUDE.md` is a symlink to this file. `.github/copilot-instructions.md` points here.

## Start here

1. Read **`docs/status.md`**: the current milestone, the next tasks, known issues and the last session's notes.
2. Read **`docs/concept.md`** for what and why. **`docs/specs/`** has the exact rules; implement them, don't reinvent them. **`docs/decisions/`** has the decisions already made; don't silently reverse them.
3. Work in small, focused steps (one task from `status.md` or one GitHub issue at a time).
4. **Before you stop**, update `docs/status.md`: what you did, what's in progress, what's next, any open questions.

## What this is

A personal, local-first time tracker for an employee in Germany. It covers working hours with target and overtime, project time, home-office quota and business travel. It runs on Linux, Windows and Android and syncs through files on the user's Nextcloud (WebDAV). There is no server of our own. Written in Flutter/Dart.

## Repo map

| Path | Content |
|---|---|
| `packages/core/` | **All business logic**, in pure Dart with no Flutter imports: models, database, calculation rules, holidays, HLC, sync engine, WebDAV client, project search. Tested with `dart test`. |
| `app/` | Flutter app (Android, Linux, Windows): only UI and platform glue. `lib/app/` holds providers, router and formatting, `lib/features/<screen>/` the screens, `lib/l10n/` the ARB texts (de, en). |
| `docs/concept.md` | The approved concept (features, architecture, milestones). |
| `docs/specs/` | Normative specs: `calculations.md` (time rules), `sync-format.md` (sync files and merging), `data-model.md` (field names per synced table), `project-search.md`, `navigation.md` (back behaviour), `backup.md` (JSON backup and restore), `sync-log.md` (device-local sync log), `updates.md` (update notice and self-update), `work-pc.md` (Windows autostart, start prompt, tray icon), `reminders.md` (forgotten clock-out, reminders), `booking-transfer.md` (filling the company booking form, Windows). |
| `docs/decisions/` | Architecture decision records (ADRs), numbered. |
| `docs/dev-setup.md` | How to set up the toolchain from scratch. |
| `tool/dev.sh` | Runs a command inside the maintainer's `flutter` toolbox (or directly, if there is no toolbox). |
| `branding/`, `tool/make_icons.py` | App icon sources and the script that generates every platform's icons from them (`branding/README.md`). |
| `tool/retry-download.sh` | CI wrapper: retries a command only when a build hook's download fails its hash check. |

## Commands

On the maintainer's Fedora machine the toolchain lives in the toolbox `flutter`. Prefix commands with `tool/dev.sh`. On CI or other machines with Flutter on the `PATH`, run them directly.

```bash
# core (pure Dart)
cd packages/core
../../tool/dev.sh dart pub get
../../tool/dev.sh dart format --set-exit-if-changed .
../../tool/dev.sh dart analyze --fatal-infos
../../tool/dev.sh dart test
# after changing drift tables in lib/src/data/database.dart (generated code is committed):
../../tool/dev.sh dart run build_runner build --delete-conflicting-outputs && ../../tool/dev.sh dart format .

# app (Flutter)
cd app
../tool/dev.sh flutter pub get
../tool/dev.sh flutter analyze --fatal-infos
../tool/dev.sh flutter test
../tool/dev.sh flutter run -d linux          # desktop
../tool/dev.sh flutter build apk --release   # Android (sideload)
```

**Seeing the UI without clicking** (maintainer machine; synthetic clicks don't reach windows under
Wayland): fill an isolated database with a sample week, then screenshot any screen. The app opens on
a route given by `--dart-define=INITIAL_ROUTE=...`.

```bash
D=$(mktemp -d)
(cd packages/core && ../../tool/dev.sh dart run tool/seed_demo.dart $D/io.github.naclador89.timetrack/timetrack.sqlite)
tool/screenshot.sh /calendar /tmp/week.png $D     # also /today, /calendar/day/2026-11-05, /settings, /projects
```

Windows builds run only on GitHub Actions (`.github/workflows/ci.yml`, on a `v*` tag or a manual trigger), because Flutter can't cross-compile to Windows.

## Conventions

- **Logic goes in `core`, UI in `app`.** If you write an `if` about time rules in a widget, it belongs in `core`.
- **Specs first.** When you change a rule or the sync format, update `docs/specs/*` in the same commit. Changing the sync format also needs a format-version bump and a new ADR.
- **Synced data is only written through `SyncedRepository`** (row, field clock and outbox in one transaction; see `docs/specs/sync-format.md`). Never write `synced_rows` directly. Field names and types come from `docs/specs/data-model.md`, and reading goes through `core/lib/src/data/mapping.dart`.
- **Time**: store instants in UTC, truncated to the full minute. Work out calendar days in the configured home time zone (default `Europe/Berlin`). Durations are whole minutes (`int`).
- **IDs**: UUIDv7 strings.
- **Docs in code**: every public API in `core` has `///` dartdoc; the `public_member_api_docs` lint makes CI fail without it. Comments explain *why*, not *what*. Match the style of the code around you.
- **Tests** are named after the rule they check and cite the spec section, e.g. `test('§4 ArbZG: 6:01 h without break → 30 min missing', …)` with `// spec: calculations.md §4`.
- **Language**: code, comments and docs in English. UI strings go through ARB localization: add every new string to **both** `app/lib/l10n/app_en.arb` (the template) and `app_de.arb`, then run `flutter gen-l10n`. German is the user's language.
- **Commits**: Conventional Commits (`feat(core): …`, `fix(app): …`, `docs: …`), small and focused.
- **Android permissions go into `app/android/app/src/main/AndroidManifest.xml`.** Flutter adds `INTERNET` only to the debug/profile manifests, so a missing permission shows up only in release builds (that's how sync broke on the phone once). Intents opened via `url_launcher` need a `<queries>` entry.
- **Demo data never meets real accounts.** The sync connection lives in the OS keyring per *app id*, not per database. A demo or screenshot build of the same app would find it, so it must be built with `--dart-define=TIMETRACK_DISABLE_SYNC=true` (`tool/screenshot.sh` does this). The connection is also bound to the device id of its database (`SyncConfig.deviceId`). On 2026-11-07 a screenshot run once uploaded sample data to the user's Nextcloud; it was cleaned up with tombstones.
- **Never commit secrets**: no keystores, Nextcloud credentials or personal time data. **The repo is public** (ADR 0008): nothing personal either, and commits use the GitHub noreply address, never a personal email.
- **Releases** only when the maintainer asks for one: bump `version:` in `app/pubspec.yaml` (the build number after `+` must grow for Android), add a line under "Releases" in `docs/status.md`, commit, then an annotated tag `v<that version>` and push both. CI refuses a tag that doesn't match, because the in-app updater compares the two (`docs/specs/updates.md`). Steps: `docs/dev-setup.md`, "Releasing".

## Working with the maintainer

- The maintainer writes in **German** and usually reports from real use, often with a screenshot from the Windows work PC or the Android phone. Answer in German; code, docs and commits stay in English.
- **Ask before anything outward-facing or hard to undo**: tags, releases, changing repo settings or secrets, deleting data, anything that touches the real Nextcloud.
- **Never publish personal data**: no personal email address anywhere (commits use `210590356+Naclador89@users.noreply.github.com`), no names, no real time data in tests or screenshots (use `tool/seed_demo.dart`).
- The Android signing key exists since v0.3.0 (`docs/dev-setup.md` §5, CI secrets `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEY_PROPERTIES`). **Never create a new one**: phones could no longer update.
- A bug report usually becomes: spec section → core fix with a test citing it → UI → widget test → `docs/status.md`. Look in `docs/status.md` for the latest sections first; they say which files a feature lives in.

## Where things live (common tasks)

| Task | Look here |
|---|---|
| A time rule (target, balance, breaks, travel, home office) | `docs/specs/calculations.md` → `packages/core/lib/src/rules/` (`ledger.dart` ties them together) |
| Clocking, breaks, projects, day types, quick entry | `packages/core/lib/src/tracking/` (`time_tracker.dart`, `day_types.dart`, `quick_entry.dart`) |
| A new synced field or setting | `docs/specs/data-model.md`, `core/lib/src/data/settings.dart` (`SettingKeys`, `AppSettings`), `mapping.dart` |
| Device-local values (theme, Windows switches) | `local_values` via the store, e.g. `app/lib/app/appearance.dart`, `app/lib/work_pc/work_pc.dart` |
| A screen | `app/lib/features/<today\|calendar\|projects\|reports\|settings>/`, routes in `app/lib/app/router.dart` |
| Actions shared by Today, command palette, shortcuts and tray | `app/lib/app/actions.dart` |
| Snack bars with undo | `app/lib/widgets/undo.dart` (always `persist: false`) |
| UI texts | `app/lib/l10n/app_en.arb` + `app_de.arb`, then `flutter gen-l10n` |
| Android notification, tile, widget, reminders | `app/lib/quick/`, `app/lib/reminders/`, Kotlin in `app/android/app/src/main/kotlin/` |
| Windows tray, autostart | `app/lib/work_pc/`, `app/windows/runner/` (C++, only built in CI) |
| Updates | `docs/specs/updates.md`, `core/lib/src/update/`, `app/lib/update/` |
| Transfer a week to the booking system (Windows) | `docs/specs/booking-transfer.md`, `core/lib/src/reports/week_booking.dart`, `app/lib/booking/`, `app/assets/booking/applus_fill.js` |
| CI and releases | `.github/workflows/ci.yml` |
| Widget test helpers | `app/test/helpers.dart` (`settle`, in-memory store); see `app/test/ui_fixes_test.dart` for a recent example |

## Notes for GitHub Copilot

- `.github/copilot-instructions.md` points here; `.github/workflows/copilot-setup-steps.yml` installs Flutter (version from `app/pubspec.yaml`) and the Linux libraries for the **coding agent**, so `dart test`, `flutter test` and `flutter analyze` work there. `tool/dev.sh` runs commands directly when there is no toolbox.
- The coding agent has no Windows, no phone, no keystore and no Nextcloud. Windows and Android code only gets compiled by `ci.yml` (manual *Run workflow* on the branch); say in the PR what the maintainer has to test on the device.
- Integration tests against a real Nextcloud (`packages/core/test/integration/`) are skipped while `NEXTCLOUD_URL` is not set; that's expected.
- Reusable prompts for VS Code Copilot Chat are in `.github/prompts/` (`/feedback`, `/release`, `/handoff`).

## Definition of done

- `dart format`, `analyze --fatal-infos` and the tests pass for every package you touched.
- New behaviour has tests that cite the spec. Specs and ADRs are updated if behaviour or format changed.
- `docs/status.md` is updated.

## Environment notes (maintainer machine)

- Host: Fedora 44 (GNOME, Wayland) with no build tools on the host. Everything runs in the toolbox **`flutter`**. Its toolchain is in `~/dev/sdk/` (Flutter, JDK 21, Android SDK) and is loaded by `~/dev/sdk/env.sh`.
- `sudo` doesn't work non-interactively, either on the host or inside the toolbox. To install packages in the toolbox, use `podman exec -u root flutter dnf -y install <pkg>`.
- The Android phone connects over wireless debugging (`adb pair`, then `adb connect`). See `docs/dev-setup.md`.
