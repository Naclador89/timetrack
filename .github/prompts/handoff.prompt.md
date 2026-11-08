---
agent: agent
description: Update docs/status.md before stopping, so the next session can pick up
---
Before stopping, update `docs/status.md`:
- "Where things stand": latest release, test counts, what is in progress, what waits for a device test by the maintainer.
- The current section: what got done (with the files and spec sections), what is half done, what's next.
- "Known issues / open questions" if something is unclear.
- A session log line: date, agent (e.g. "GitHub Copilot"), what changed, test counts.
Then commit as `docs: …` and push.
