# Work PC: ask to start tracking after sign-in

Status: **normative**. Code: `packages/core/lib/src/tracking/start_prompt.dart` (whether to ask,
which location, "not today"), `app/lib/work_pc/` (autostart, prompt), Windows runner
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
4. If not asked, the window stays minimized.

A start by hand (no `--autostart`) never asks.
