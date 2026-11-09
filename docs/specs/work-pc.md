# Work PC: ask to start tracking after sign-in, tray icon

Status: **normative**. Code: `packages/core/lib/src/tracking/start_prompt.dart` (whether to ask,
which location, "not today"), `app/lib/work_pc/` (autostart, prompt, tray), Windows runner
(`app/windows/runner/main.cpp`, `flutter_window.cpp`). Requested by the user 2026-11-08.

## 1. The settings (Windows only)

Two switches under Einstellungen → App, shown only on Windows, per device and never synced:

- **Mit Windows starten** (autostart; requested by the user 2026-11-08): on writes the Run key value
  `HKCU\Software\Microsoft\Windows\CurrentVersion\Run` → `TimeTrack` =
  `"<path of the running timetrack.exe>" --autostart` (per user, no admin rights; also listed under
  Task Manager → Startup apps). Off deletes that value.
  - The switch shows on only while the value exists and names the running exe, so the registry is
    the only source. After the folder moved it shows off; switching it on again repairs it. The
    in-app update replaces the folder in place, so the path stays valid.
- **Arbeits-PC**: ask after sign-in whether to start tracking (§2). `local_values` key
  `start_prompt` (`true`/`false`, default **on**, so installations from before the split keep
  asking). It needs the autostart: switching it on also turns the autostart on, and it is greyed
  out while the autostart is off.

## 2. After sign-in

Started with `--autostart`, the window first appears **minimized and without focus**. With
**Arbeits-PC** off nothing is asked: the window goes straight to step 4. Otherwise:

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
   - **Starten** asks for the time (calculations §19, now preselected) and clocks in at the chosen
     location.
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
  steps, time question (calculations §19) and summary prompt. Whatever may ask something (the time,
  a running project's summary, the end of a trip) brings the window up first.
- **Im Infobereich weiterlaufen** (Einstellungen → App, Windows only, per device in `local_values`
  `close_to_tray`, default on): the close button hides the window; it keeps running in the tray, and
  "Beenden" in the menu quits. Off: closing quits as before.
- **Notifications**: while the app runs, the reminders (reminders.md §2) are checked every minute and
  shown as Windows notifications through the tray icon.
- The icon is removed when the window is destroyed (quit, update; the updater quits through the
  channel instead of `exit`) and added again when Explorer restarts (`TaskbarCreated`).


## 4. Monthly balance reminder (Windows only)

Requested by the user 2026-11-09: after a change of month, remind them on the work PC to enter the
overtime balance in the employer's system.

- **Setting**: Einstellungen → App → **Erinnerung: Überstunden melden**, Windows only, per device in
  `local_values` `month_report_reminder` (default on; `false` switches it off).
- **Due** (core `monthReportDue`): the month before today's month, unless `local_values`
  `month_report_done` already holds it (`YYYY-MM`) or a later month, and only if that month ends on
  or after the balance start (§8 of calculations.md; before it there is no balance to report).
- **Card on Today** while due: "Überstundenkonto für Oktober melden", the balance at the end of that
  month (`Ledger.balanceAtEndOf`, signed `+12:30`) and the actions **Kopieren** (the balance as
  text) and **Erledigt** (stores the month in `month_report_done`; the card goes). Since step 4
  (calculations §21.3) the text also names the month's Sunday/holiday, special holiday and night
  hours, if any: "Zuschläge: Sonn-/Feiertagsstunden 3:00, Nachtstunden 2:00." Kopieren still copies
  only the balance.
- **Notification**: once per month, the first time the reminder check (§3) finds it due, a Windows
  notification with the same text (`local_values` `month_report_notified` = `YYYY-MM`).
