# Navigation: what back does

User request 2026-11-08: back (button or gesture) closed the app too early. Back now walks these
steps in order and stops at the first that applies; only the last one leaves the app.

1. **Close what is open**: keyboard, bottom sheet, dialog, snackbar action sheet.
2. **One page up within the tab**: day → week, report preview → reports, settings sub-page →
   settings → the screen they were opened from. Settings and the setup wizard open over the tabs.
3. **Reset the tab's view** (`BackSteps`): the calendar returns to the current week (from another
   week, then from the month view), the reports to the current month.
4. **The previously visited tab** (`TabBackHandler`), in the order they were visited; without a
   history, Today.
5. **On Today**: the first back shows "Zum Verlassen nochmal zurück" (2 s); a second back within that
   time sends the app to the background (Android `moveTaskToBack`, like Home), so it reopens at once
   with its state. Other platforms close it.

**Days open in the current tab**: from Today a day opens at `/today/day/<date>`, from the calendar at
`/calendar/day/<date>` (`dayLocation`), so back returns to where the user came from.

Code: `app/lib/app/back_navigation.dart`, routes in `app/lib/app/router.dart`.

## Keyboard shortcuts (desktop)

Requested by the user 2026-11-08. They work anywhere in the tabs (not while a dialog or the settings
are open); F1 or `?` lists them, and the command palette shows each action's key.

| Key | Action |
|---|---|
| Ctrl+K | command palette |
| Ctrl+E | clock in or out (at the location Today would use; on a trip day it opens Today, whose steps decide) |
| Ctrl+P | start or end a break (while clocked in) |
| Ctrl+B | book project time for today |
| Ctrl+J | quick entry for today |
| Ctrl+1 … 4 | Today, Calendar, Projects, Reports |
| Ctrl+, | settings |
| F5 | sync now (if connected) |
| ← / → | previous / next week, month or day (calendar and day view) |
| T | back to today (calendar and day view) |
| M | switch week ↔ month (calendar) |
| F1, ? | the list of shortcuts |

Plain keys (←, →, T, M, ?) do nothing while a text field has the focus, so typing is never taken
over. Today's button, the palette and the keys share one set of actions (`app/lib/app/actions.dart`).

Code: `app/lib/widgets/shortcuts.dart` (`AppShortcuts` in the shell, `PageKeys` on the calendar pages).
