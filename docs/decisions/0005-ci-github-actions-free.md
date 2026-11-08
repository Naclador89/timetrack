# 0005: CI on GitHub Actions, sized for the free plan

- Status: accepted (2026-11-07); the private repo was replaced by a public one in [0008](0008-public-repo-self-update.md)

## Context
Windows builds need Windows. The user has a free GitHub account: 2,000 Actions minutes per month for
private repos, and Windows minutes count double.

## Decision
A private repo on GitHub. Tests (Linux) run on every push. Platform builds (Linux, Android, Windows)
run only on `v*` tags or manually; tags create a GitHub Release with all builds attached. Day to day,
Linux and Android are built locally.

## Consequences
- About 750 of the 2,000 minutes in an active month.
- Fallbacks if needed: a public repo (standard runners are free), or a local Windows VM.
