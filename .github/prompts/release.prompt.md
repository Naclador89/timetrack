---
agent: agent
description: Cut a new release (only when the maintainer asked for it)
---
Cut release ${input:version:Version, z. B. 0.5.3}.

1. Check that `main` is clean, pushed and CI is green.
2. Bump `version:` in `app/pubspec.yaml` to `<version>+<build number + 1>`.
3. Add a line under "Releases" in `docs/status.md` with the date and what's new for the user.
4. Commit `chore: release v<version>` and push.
5. Create an annotated tag `v<version>` with a one-line message and push it. CI (`.github/workflows/ci.yml`) builds Windows, Linux and Android and publishes the release with `SHA256SUMS`.
6. Check the release: not a draft, four assets (APK, Windows ZIP, Linux tar.gz, SHA256SUMS), `releases/latest` points to it.
7. Tell the maintainer in German what's in it and that "Einstellungen → App → Nach Updates suchen" fetches it at once.
