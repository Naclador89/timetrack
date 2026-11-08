# Work PC: ask to start tracking after sign-in, tray icon

Status: **normative**. Code: `packages/core/lib/src/tracking/start_prompt.dart` (whether to ask,
which location, "not today"), `app/lib/work_pc/` (autostart, prompt, tray), Windows runner
(`app/windows/runner/main.cpp`, `flutter_window.cpp`). Requested by the user 2026-11-08.

## 1. The setting (Windows only)

- Einstellungen → App → **Arbeits-PC**, shown only on Windows. It is per device and never synced.
- On: writes the Run key value `HKCU\Software\Microsoft\Windows\CurrentVersion\Run` → `TimeTrack` =
  `"<path of the running timetrack.exe>" --autostart` (per user, no admin rights; also listed under
  Task Manager → Startup apps). Off: deletes that value.
- The switch shows on only while the value exists and names the running exe, so the registry is
  the only source. After the folder moved it shows off; switching it on again repairs it. The
  in-app update replaces the folder in place, so the path stays valid.

## 2. After sign-in

Started with `--autostart`, the window first appears **minimized and without focus**. Then:

1. If a sync connection is set up (and sync isn't disabled for the build), sync until one cycle
   succeeds, for at most **20 s**, so a start on the phone counts. Offline, the check is local.
2. **Ask** only if all hold:
   - not clocked in;
   - no non-deleted work session overlaps today (home time zone; a night session ending after
     midnight counts for today, one ending exactly at midnight does not);
   - "not today" was not answered for today's date (`local_values` key `start_prompt_declined`).
   Weekends, holidays and absences are asked too (the user's choice).
3. If asked: restore the window and bring it to the front (channel `timetrack/window`, `show`;
   where Windows refuses the focus, the taskbar button flashes). Dialog *Tracking für heute
   starten?* with office / home office, preselected from today's day type, else the last session's
   location (as the quick actions do), office for anything else.
   - **Starten** clocks in at the chosen location.
   - **Nicht heute** stores today's date; further sign-ins today don't ask.
4. If not asked, the window goes to the tray (§3; hidden) when "Im Infobereich weiterlaufen" is on,
   else it stays minimized.

A start by hand (no `--autostart`) never asks.

## 3. Tray icon (Windows)

Requested by the user 2026-11-08. On Windows the app always has a tray icon (Shell_NotifyIcon in the
runner, channel `timetrack/window`):

- **Icon**: the app icon while clocked in, a grey one (`app_icon_idle.ico`, made by
  `tool/make_icons.py`) while clocked out. **Tooltip**: "TimeTrack · <status> · <today's worked>".
- **Left click** opens the window. **Right click** opens the menu:
  1. the status (greyed): "Eingestempelt seit 08:00 · Büro · 5:12", on a break "Pause seit …";
  2. Einstempeln / Ausstempeln, and while clocked in Pause starten / Pause beenden;
  3. up to five projects (favourites first, then by recent use; the running one ticked) to start or
     switch to;
  4. "Projekt wechseln…" and "Projektzeit buchen…" (open the window with the picker or sheet);
  5. "TimeTrack öffnen", "Beenden".
- The actions are the app's own (`app/lib/app/actions.dart`): the same location rules, trip-day
  steps and summary prompt. Whatever may ask something (a running project's summary, the end of a
  trip) brings the window up first.
- **Im Infobereich weiterlaufen** (Einstellungen → App, Windows only, per device in `local_values`
  `close_to_tray`, default on): the close button hides the window; it keeps running in the tray, and
  "Beenden" in the menu quits. Off: closing quits as before.
- **Notifications**: while the app runs, the reminders (reminders.md §2) are checked every minute and
  shown as Windows notifications through the tray icon.
- The icon is removed when the window is destroyed (quit, update; the updater quits through the
  channel instead of `exit`) and added again when Explorer restarts (`TaskbarCreated`).

