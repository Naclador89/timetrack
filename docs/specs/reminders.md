# Forgotten clock-out and reminders

Requested by the user 2026-11-08. Normative for `core/lib/src/tracking/reminders.dart`, the app's
`ForgottenClockOutHost` and the Android/Windows reminder notifications.

## §1 Forgotten clock-out

A session is **probably forgotten** when it is still open and either started before today (home
time zone) or has been open longer than `open_session_limit_min` (default 720 min, the same limit as
the review item `open_session_over_12h`, calculations §12).

When the app starts or returns to the foreground with such a session, it asks once:
"Eingestempelt seit gestern 08:00 – wann war Feierabend?" The answers:

- a **suggested end** (chips, at most three, sorted by time; only times after the session start and
  not in the future; equal minutes shown once):
  - **Letzte Aktivität**: the latest start or end of a break or project entry inside the session;
  - **Soll erreicht**: when the session's day reached its target, by the forecast of calculations §18
    taken at the session start (target + the break §4 requires; none on days without a target);
  - **Üblicher Feierabend**: the median local end time of the last 20 finished sessions, on the
    session's start day;
- **Andere Zeit…**: date and time picker (after the session start, not in the future);
- **Ich arbeite noch**: nothing changes; the session id is stored on this device
  (`local_values` `forgotten_ack`) and the question is not asked again for it. The review card stays.

Clocking out at an earlier time `t` (`TimeTracker.clockOut(at: t)`) ends the session at `t`. A
running break or project entry ends at `t` too; one that only started after `t` is deleted.

## §2 Reminders

While working (clocked in, not on a break), three reminders, each switchable (synced settings,
default on):

| Kind | Setting | Due when | Key (shown once) |
|---|---|---|---|
| `break_due` | `reminders.break` | the current stretch without a countable break (§4: gaps ≥ 15 min) reaches 5:45 h | `<date>/break_due/<stretch start minute>` |
| `target_reached` | `reminders.target` | today's target is reached (`targetAt` of §18 calculations; due now once reached). Not on days without a target or on trip days | `<date>/target_reached` |
| `long_day` | `reminders.long_day` | today's worked time `W` reaches 9:45 h | `<date>/long_day` |

`nextReminders` returns them with their due instant (now or later). A reminder whose key was shown
already is skipped (`local_values` `reminders_shown`, the last 20 keys). Texts: "Seit 5:45 Std. ohne
Pause – Pause starten?" with the action **Pause starten**; "Gleich 10 Std. – noch eingestempelt?"
with the action **Ausstempeln**; "Soll erreicht – Feierabend möglich – dein Tagessoll ist geschafft."
with the action **Ausstempeln** (user, 2026-11-10).

**Android**: after every published status the app schedules a one-off WorkManager task `reminder` at
the earliest due time (policy replace); the task re-reads the state, shows what is due as a
notification on the channel "Erinnerungen" (`ReminderNotice.kt`) and schedules the next one. The
periodic 15-minute job checks as well, as a fallback. The actions use the quick action URIs
(`timetrack://quick/toggleBreak`, `…/clockOut`).

**Windows**: while the app runs (also in the tray, work-pc.md §3) a one-minute timer shows due
reminders as Windows notifications through the tray icon. Linux shows none.
