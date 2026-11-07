# Copilot instructions

All instructions for coding agents live in [`AGENTS.md`](../AGENTS.md) at the repo root. Read it first.

The short version:
- Read `docs/status.md` before starting and update it before finishing.
- Business logic goes in `packages/core` (pure Dart); `app/` holds only UI and platform glue.
- Follow the normative specs in `docs/specs/`; change a spec in the same commit as the behaviour it describes.
- Every public API in `core` needs `///` dartdoc. `dart format`, `dart analyze --fatal-infos` and the tests must pass.
