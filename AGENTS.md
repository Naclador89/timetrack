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
| `app/` | Flutter app (Android, Linux, Windows): only UI and platform glue. Created in M0. |
| `garmin/` | Connect IQ watch app and glance (Monkey C), milestone M6. |
| `docs/concept.md` | The approved concept (features, architecture, milestones). |
| `docs/specs/` | Normative specs: `calculations.md` (time rules), `sync-format.md` (sync files and merging), `project-search.md`. |
| `docs/decisions/` | Architecture decision records (ADRs), numbered. |
| `docs/dev-setup.md` | How to set up the toolchain from scratch. |
| `tool/dev.sh` | Runs a command inside the maintainer's `flutter` toolbox (or directly, if there is no toolbox). |

## Commands

On the maintainer's Fedora machine the toolchain lives in the toolbox `flutter`. Prefix commands with `tool/dev.sh`. On CI or other machines with Flutter on the `PATH`, run them directly.

```bash
# core (pure Dart)
cd packages/core
../../tool/dev.sh dart pub get
../../tool/dev.sh dart format --set-exit-if-changed .
../../tool/dev.sh dart analyze --fatal-infos
../../tool/dev.sh dart test

# app (Flutter)
cd app
../tool/dev.sh flutter pub get
../tool/dev.sh flutter analyze --fatal-infos
../tool/dev.sh flutter test
../tool/dev.sh flutter run -d linux          # desktop
../tool/dev.sh flutter build apk --release   # Android (sideload)
```

Windows builds run only on GitHub Actions (`.github/workflows/ci.yml`, on a `v*` tag or a manual trigger), because Flutter can't cross-compile to Windows.

## Conventions

- **Logic goes in `core`, UI in `app`.** If you write an `if` about time rules in a widget, it belongs in `core`.
- **Specs first.** When you change a rule or the sync format, update `docs/specs/*` in the same commit. Changing the sync format also needs a format-version bump and a new ADR.
- **Synced data is only written through the synced repository** (row, field clock and outbox in one transaction; see `docs/specs/sync-format.md`). Never write synced tables directly.
- **Time**: store instants in UTC, truncated to the full minute. Work out calendar days in the configured home time zone (default `Europe/Berlin`). Durations are whole minutes (`int`).
- **IDs**: UUIDv7 strings.
- **Docs in code**: every public API in `core` has `///` dartdoc; the `public_member_api_docs` lint makes CI fail without it. Comments explain *why*, not *what*. Match the style of the code around you.
- **Tests** are named after the rule they check and cite the spec section, e.g. `test('§4 ArbZG: 6:01 h without break → 30 min missing', …)` with `// spec: calculations.md §4`.
- **Language**: code, comments and docs in English. UI strings go through ARB localization (`de` is the default, `en` is also provided).
- **Commits**: Conventional Commits (`feat(core): …`, `fix(app): …`, `docs: …`), small and focused.
- **Never commit secrets**: no keystores, Nextcloud credentials or personal time data.

## Definition of done

- `dart format`, `analyze --fatal-infos` and the tests pass for every package you touched.
- New behaviour has tests that cite the spec. Specs and ADRs are updated if behaviour or format changed.
- `docs/status.md` is updated.

## Environment notes (maintainer machine)

- Host: Fedora 44 (GNOME, Wayland) with no build tools on the host. Everything runs in the toolbox **`flutter`**. Its toolchain is in `~/dev/sdk/` (Flutter, JDK 21, Android SDK) and is loaded by `~/dev/sdk/env.sh`.
- `sudo` doesn't work non-interactively, either on the host or inside the toolbox. To install packages in the toolbox, use `podman exec -u root flutter dnf -y install <pkg>`.
- The Android phone connects over wireless debugging (`adb pair`, then `adb connect`). See `docs/dev-setup.md`.
- Garmin tools are in a separate toolbox, **`ciq`** (Ubuntu). See `~/connectiq/README.md` on the maintainer machine.
