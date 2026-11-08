# 0008: Public repo, the app updates itself from GitHub Releases

- Status: accepted (2026-11-08). Supersedes the "private repo" part of [0005](0005-ci-github-actions-free.md).

## Context
The user wants the app to say when a new version is out and to update itself on Android, Linux and
Windows. The app needs to read the newest release and download its files. From a private repo that
needs a GitHub token, and a token shipped inside the app is no secret.

## Decision
- The repo is **public**. Before publishing, the whole history was checked for secrets, keystores,
  databases and personal data (none found). The user's personal email address was in every commit,
  so the history was rewritten with the GitHub noreply address and pushed to a **new** repo
  `Naclador89/timetrack`; the old private repo (original history) was renamed to
  `Naclador89/timetrack-private` and stays private. Commits use the noreply address from now on.
- The app reads `releases/latest` without a token and verifies every download against a
  `SHA256SUMS` file in the same release (spec: `docs/specs/updates.md`).
- Android installs through the system installer (same signing key required); Linux swaps the
  `bundle/` folder; Windows replaces its portable folder through a PowerShell script after quitting.
- Workflows from first-time and outside contributors need the owner's approval; the Android signing
  secrets are never given to fork PRs.

## Consequences
- Anyone can read the code and the history. Nothing personal may be committed (AGENTS.md).
- Standard GitHub runners are free for public repos; the build-only-on-tag rule from 0005 stays
  anyway (fast pushes).
- Linux and Windows builds are unsigned: whoever controls the GitHub account controls the updates.
  Keep 2FA on.
- The first version with the updater (v0.4.0) is installed by hand once.
