# In-app updates

Status: **normative**. Code: `packages/core/lib/src/update/` (release, versions, check state),
`app/lib/update/` (download, install, banner); Android half in
`app/android/.../UpdateInstaller.kt` and `UpdateNotice.kt`. Decision: ADR 0008.

## 1. Source

- The newest release of the **public** GitHub repo `Naclador89/timetrack`, read without a token:
  `GET https://api.github.com/repos/Naclador89/timetrack/releases/latest` (GitHub never returns
  drafts or pre-releases there; a response with `prerelease` or `draft` true is ignored anyway).
- Files used, by platform (asset names are fixed by `.github/workflows/ci.yml`):

  | Platform | Asset |
  |---|---|
  | Android | `timetrack-android.apk` |
  | Linux | `timetrack-linux-x64.tar.gz` |
  | Windows | `timetrack-windows-x64.zip` |
  | all | `SHA256SUMS` (`<64 hex>  <name>` per line, as written by `sha256sum`) |

- A release without the platform's asset or without `SHA256SUMS` (e.g. v0.3.0 and older) is not
  offered.
- HTTP goes through the device's sync proxy setting if one is saved (the company PC), else the
  `HTTPS_PROXY` environment variable, else direct. No credentials are ever sent.

## 2. Versions

- The installed version is the app's `pubspec.yaml` version without the build number (`0.4.0+5` →
  `0.4.0`). The release version is its tag without the leading `v`.
- Versions compare as `major.minor.patch` numbers (`0.10.0` > `0.9.0`). A tag that isn't three
  numbers is ignored. A release is offered only if it is **newer** than the installed version.
- CI refuses a tag that doesn't match `pubspec.yaml` (§7), so the app never offers its own version
  as an update.

## 3. When the app checks

- **Automatically**, if turned on (default: on): when the app starts and when it returns to the
  foreground, at most once per **24 h**. On Android also in the periodic background job (every 15
  min, so in practice once a day as well).
- **By hand**: Einstellungen → App → "Nach Updates suchen", any time.
- Builds with `TIMETRACK_DISABLE_SYNC=true` (demo, screenshots) never check automatically.
- **State** (device-local, `local_values` key `update_state`, never synced), as JSON:

  ```json
  {"checked": "2026-11-08T10:00:00.000Z", "auto": true, "skipped": "0.4.0", "notified": "0.4.0"}
  ```

  - `checked`: last successful check; a failed check doesn't move it.
  - `auto`: the automatic check; missing = on.
  - `skipped`: "Diese Version überspringen". This version is not offered again automatically, but
    a newer one is, and a manual check always shows the newest.
  - `notified`: newest version the Android system notification was shown for (once per version).

## 4. Notice

- Banner above every tab and above Einstellungen (an update started from the manual check there
  must show its progress and *Neu starten*): "TimeTrack 0.4.0 ist verfügbar" with *Aktualisieren*, *Was ist neu*
  (the release notes) and *Später* (hidden until the next start) and, in the notes dialog,
  *Überspringen* (§3 `skipped`).
- Android: the background job additionally shows a system notification (channel "Updates"), once
  per version. Tapping it opens the app with the update dialog.
- Errors of an automatic check are silent; a manual check reports them ("Keine Verbindung zu
  GitHub").

## 5. Installing

Common steps, each only after the user tapped *Aktualisieren*:

1. Run one sync cycle (nothing unsent stays behind; the data stays anyway, see below).
2. Download the asset into the app's temporary folder, showing progress.
3. Check its SHA-256 against `SHA256SUMS` of the **same** release. A mismatch deletes the file and
   reports an error; nothing is installed.
4. Install (per platform below).

The database lives in the app support folder (`getApplicationSupportDirectory`), never in the
install folder, so no update touches it.

- **Android**: hand the APK to the system installer (`PackageInstaller` session). Android asks for
  "Unbekannte Apps installieren" for TimeTrack the first time; the app explains this and opens the
  setting. Android itself always asks to confirm, and only accepts an APK signed with the same key
  as the installed app.
- **Linux**: the install folder is the folder of the running executable (`bundle/` of the
  tar.gz, e.g. `~/.local/opt/timetrack`). If it or its parent isn't writable, only the release
  page is opened.
  1. Unpack with `tar` into `<parent>/<name>.new/`; the archive must contain `bundle/timetrack`.
  2. Rename `<name>` → `<name>.old`, then `<name>.new/bundle` → `<name>`. If the second rename
     fails, the first is undone.
  3. Offer *Neu starten*: start the new executable detached, then quit. The next start deletes
     `<name>.old` and `<name>.new`.
- **Windows**: the install folder is the folder of `timetrack.exe`. If it isn't writable (e.g.
  under `Program Files`), only the release page is opened. The running exe and its DLLs are locked,
  so the app writes `update.ps1` next to the download and starts it detached with
  `powershell -NoProfile -ExecutionPolicy Bypass -File`, then quits. The script:
  1. waits until the app's process id has ended (at most 60 s);
  2. unpacks the ZIP (`Expand-Archive`) into a temporary folder;
  3. copies it over the install folder (3 attempts, 2 s apart);
  4. starts `timetrack.exe` again and deletes the temporary files.
  No administrator rights are needed.

## 6. Integrity, known limits

- HTTPS to GitHub plus the checksum catch broken or cut-off downloads (e.g. the HTML error pages
  GitHub served instead of release files on 2026-11-08).
- On Android the signature check by the system is the real protection: only an APK signed with the
  release key installs over the app.
- Linux and Windows builds are **not signed**. Someone who can publish a release in the repo (i.e.
  controls the GitHub account) could ship anything; the checksum comes from the same release and
  doesn't protect against that. Keep 2FA on the GitHub account.

## 7. CI

- The release job attaches `SHA256SUMS` over the three builds and generates the release notes
  from the commits since the previous tag.
- On a `v*` tag the test job fails unless the tag equals `v` + the `pubspec.yaml` version without
  build number.
