# TimeTrack

Personal time tracking for **Linux, Windows and Android** that syncs through your **Nextcloud**,
with no server of its own.

- Working hours as an employee: target and overtime balance, breaks (ArbZG), vacation and sick days,
  public holidays for every German state.
- Project time (name, project number, order number, with search across all three), which can be
  less than working time ("unassigned").
- Home-office days with a weekly or monthly quota. Business trips with your employer's crediting
  rules and a per-diem basis.
- Reports: monthly timesheet PDF, travel report, order report, CSV, statistics.

## Download

Always the latest release. From v0.4.0 on, the app tells you about new versions and updates itself
(Einstellungen → App):

| Platform | Download | Install |
|---|---|---|
| Windows | [timetrack-windows-x64.zip](https://github.com/Naclador89/timetrack/releases/latest/download/timetrack-windows-x64.zip) | Unzip, start `timetrack.exe` (SmartScreen: *More info → Run anyway*) |
| Android | [timetrack-android.apk](https://github.com/Naclador89/timetrack/releases/latest/download/timetrack-android.apk) | Open the APK, allow installing from this source |
| Linux | [timetrack-linux-x64.tar.gz](https://github.com/Naclador89/timetrack/releases/latest/download/timetrack-linux-x64.tar.gz) | Unpack, start `bundle/timetrack`; for a launcher use `bundle/data/app_icon.png` as icon |

On the work PC, switch on Einstellungen → App → **Arbeits-PC**: TimeTrack then starts when you sign in
to Windows and asks whether to start tracking, unless it already runs today.

All versions: [Releases](https://github.com/Naclador89/timetrack/releases). A new release is built by pushing a
tag `vX.Y.Z` that matches the version in `app/pubspec.yaml` (see `docs/dev-setup.md`).

**Status**: early development, see [`docs/status.md`](docs/status.md).
**Contributing, including AI agents**: start with [`AGENTS.md`](AGENTS.md).
**Concept**: [`docs/concept.md`](docs/concept.md).
