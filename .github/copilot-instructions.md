# Copilot instructions

All instructions for coding agents live in [`AGENTS.md`](../AGENTS.md) at the repo root. Read it first,
then [`docs/status.md`](../docs/status.md) ("Where things stand").

The short version:
- Read `docs/status.md` before starting and update it before finishing (a section entry and a session log line).
- Business logic goes in `packages/core` (pure Dart); `app/` holds only UI and platform glue.
- Follow the normative specs in `docs/specs/`; change a spec in the same commit as the behaviour it describes.
- Every public API in `core` needs `///` dartdoc. `dart format`, `dart analyze --fatal-infos` and the tests must pass.
- Every new UI string goes into both `app/lib/l10n/app_en.arb` and `app_de.arb`.
- The maintainer writes in German: answer in German. Code, comments, docs and commits are in English.
- The repo is public: no personal data, no secrets, no personal email. Never create a new Android signing key.
- Tags and releases only when the maintainer asks.
