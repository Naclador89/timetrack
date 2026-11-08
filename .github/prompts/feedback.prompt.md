---
agent: agent
description: Turn feedback from the maintainer (often a screenshot) into a tested fix
---
Feedback from the maintainer (German, maybe with a screenshot): ${input:feedback:Was soll sich ändern?}

1. Read `AGENTS.md` and the top of `docs/status.md` ("Where things stand").
2. Find the cause in the code before changing anything. If the wish is ambiguous, ask one short question in German.
3. If a rule changes, update the right section in `docs/specs/` first.
4. Put logic in `packages/core` with a test that cites the spec section; UI in `app/`, with new strings in both ARB files (`flutter gen-l10n`) and a widget test.
5. Run `dart format`, `analyze --fatal-infos` and the tests for every package you touched.
6. Add an entry to the latest feedback section in `docs/status.md` and a session log line (with test counts).
7. Commit as Conventional Commit. Summarise in German what changed and what the maintainer should try on the device.
