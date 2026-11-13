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
| Ctrl+E | clock in or out (at the location Today would use; on a trip day it opens Today, whose steps decide); asks for the time first, calculations §19 |
| Ctrl+P | start or end a break (while clocked in; asks for the time first, calculations §19) |
| Ctrl+B | book project time for today |
| Ctrl+J | quick entry for today |
| Ctrl+1 … 5 | Today, Calendar, Planner, Projects, Reports |
| Ctrl+, | settings |
| F5 | sync now (if connected) |
| ← / → | previous / next week, month or day (calendar and day view) |
| T | back to today (calendar and day view) |
| M | switch week ↔ month (calendar) |
| F1, ? | the list of shortcuts |

Plain keys (←, →, T, M, ?) do nothing while a text field has the focus, so typing is never taken
over. Today's button, the palette and the keys share one set of actions (`app/lib/app/actions.dart`).

Code: `app/lib/widgets/shortcuts.dart` (`AppShortcuts` in the shell, `PageKeys` on the calendar pages).

## Settings structure

Requested by the user 2026-11-09 (the single list had grown to ~45 tiles). `/settings` is an
overview; each category opens its own page (`SettingsSection` in
`app/lib/features/settings/settings_sections.dart`):

| Overview tile | Route | Groups |
|---|---|---|
| Synchronisation | `/settings/sync` | connection, log |
| Arbeitszeit & Konto | `/settings/account` | Sollzeit (schedules, federal state), Arbeitszeitkonto (starting balance, balance start, traffic light), Urlaub (carry-over deadline) |
| Stempeln & Pausen | `/settings/clocking` | Stempeln, Pausen (missing-break rule, default break), Erinnerungen (where available) |
| Homeoffice-Regeln | `/settings/home-office` | |
| Reisen & Zuschläge | `/settings/travel` | crediting on trips, weekends and holidays (with special holidays), Nachtarbeit, Spesen (per-diem rates `/settings/per-diem`, site allowance `/settings/site-allowance`, mileage, laundry, claim deadline) |
| Hinweise | `/settings/notices` | threshold, one switch per category, restore dismissed |
| Darstellung & Updates | `/settings/app` | Darstellung, Updates |
| Arbeits-PC (Windows only) | `/settings/work-pc` | autostart, start prompt, tray, monthly reminder, booking URL |
| Einrichtung | `/setup` | at the bottom |

Each tile shows a one-line summary of its page. The search on the overview covers the tiles of
every page, grouped as "Page › Group", and works in place. Back from a page returns to the overview.

## Layout

The shell (`MainShell`, `app/lib/app/main_shell.dart`) follows the Material 3 window classes:

| Window width | Navigation |
|---|---|
| < 600 px | `NavigationBar` at the bottom |
| 600–1199 px | `NavigationRail`, labels below the icons, palette button |
| ≥ 1200 px | extended `NavigationRail`, labels beside the icons, palette button with its name |

Five tabs (Heute, Kalender, Planer, Projekte, Berichte; the Planer since 2026-11-13); Einstellungen
open from the gear. The tab that comes in fades through (250 ms); every tab keeps its state.

## Planer (trips and absences)

Requested by the user 2026-11-13: business trips and absences were only in the calendar's ⋮ menu,
where nobody found them. They now have their own tab (`/planner`, `?show=trips|absences` preselects
the filter; `app/lib/features/planner/planner_screen.dart`). From top to bottom, per year:

1. **The year in numbers**: vacation left of the entitlement with a bar of taken and planned days
   (carry-over edited here, calculations §10), the trips and days away with how many are still to
   claim (§13.5), and other absences per kind. Side by side from 640 px.
2. **One list** with the chips Alle / Reisen / Abwesenheiten: "Demnächst" (running or ahead, soonest
   first, "in n Tagen" or "läuft" beside the name) and "Vergangen" (newest first, five, then "n
   weitere anzeigen"). A trip shows its dates, order and project, the first line of its notes and
   the claim status, with the expense report on the right; tap edits it. Absences are blocks
   (calculations §10.4): a vacation week is one entry with its days; tap opens its first day, the
   bin deletes the whole block (undo).
3. **The year at a glance**: twelve mini months with holidays, absences and trip days in their day
   type's colour, bridge days ringed and the state's school holidays as a band behind the days
   (§10.5); tapping a trip day opens the trip, another day adds a trip or an absence from there.
   Below it the bridge days (§10.1) and the school holidays of the year with the state's name, each
   still ahead with "+" to enter it as vacation (the absence dialog with that range), and the
   source (OpenHolidays API, ODbL).

**Absence dialog** (since 2026-11-13, like the trip dialog): the period is one field that opens one
calendar; the first tap sets one end, the second the other, and it closes right away
(`pickDateRange`). From the day screen it picks one day. A range marks every date in it, weekends
and holidays too; for vacation the dialog shows how many days the account will count (§10, §6.1).

From 900 px the list and the year sit side by side. "Neu" adds a trip or an absence (asks which
while both are shown). The Urlaub tile on Today opens the planner with absences preselected; the
command palette has Planer, Abwesenheiten and Reisen.

## Day arc (hero card)

Requested by the user 2026-11-10 (`app/lib/widgets/day_arc.dart`). Once something is worked today,
the hero card shows an open 240° arc instead of the ring: from the first clock-in (label left) to
the 10-hour limit (label right; while clocked in `limitAt` of calculations §18, otherwise first
start + 10 h + the gaps so far). Worked spans are thick in `primary`, breaks and gaps between them a
thin `tertiary` line, a tick marks where the target is reached (§18 `targetAt`, or the minute it
was reached), a dot marks now while clocked in. Before any work, on absence days without work, the
ring stays. Worked time turns `positive` once the target is reached.

**Target moment**: when the credited time crosses the target while Today is on screen, the arc
pulses once (scale 1 → 1.04 → 1, a `positive` shimmer, ~0.7 s) with a haptic tick. Opening Today
after the target was reached plays nothing. With reduced motion only the colour changes.

## Today tiles

Requested by the user 2026-11-09. Below the hero card (stamping) and the project strip, Today shows
overview tiles, two columns from 300 px content width (phones too) (`DashboardGrid`,
`app/lib/features/today/dashboard.dart`). Each grows into its detail screen (container transform,
`OpenContainer`), pushed in the Today tab; back closes it like any page. Going to Today's start
(tapping the Today tab again, "Today" in the command palette, clocking on a trip day) closes it too.

| Tile | Figure | Opens |
|---|---|---|
| Zeitkonto | balance with traffic light dot, change this month, trend of the last month ends | month by month: change and closing balance (`BalanceDetailScreen`) |
| Diese Woche | credited of target (calculations §8: vacation and holidays count) | the week's days; a day opens its day view (`WeekDetailScreen`) |
| Urlaub | days left of entitlement + carry-over (with an entitlement or a planned vacation); below it the countdown to the next vacation (calculations §10.3) | the vacation planner |
| Homeoffice (one per day quota) | days left, used of allowed | the home-office rules |

The balance is no longer a figure of the hero card; the tile shows it.

## Motion and colours

- Cards on Today fade in and rise 8 % one after the other: 250 ms, `easeOutCubic`, 50 ms apart
  (`app/lib/widgets/staggered.dart`). It plays once per card, not on rebuilds.
- Calendar weeks and months slide sideways in the direction they move (shared axis, 300 ms); the
  week/month toggle zooms (`PageTransitionSwitcher` in `week_screen.dart`). The day view keeps its
  page transition.
- On Android the back gesture previews the page below (`PredictiveBackPageTransitionsBuilder`,
  `enableOnBackInvokedCallback`, Android 14+, user 2026-11-10). On the tab roots the back steps
  above keep handling back, so there is no preview there.
- With a mouse a tile lifts 2 px and gets a slightly stronger surface (180 ms).
- With the system's reduced motion (`MediaQuery.disableAnimations`) nothing animates; switching it
  keeps the cards as they are.
- The UI uses only `colorScheme` colours. Meaning colours (`positive`, `warning`, day types,
  projects) are extensions on `ColorScheme` in `app/lib/app/theme.dart`, harmonised with
  `primary`, so they follow the wallpaper (Android 12+) or accent colour (Windows, Linux). Without
  system colours the scheme comes from the icon's cyan (`fallbackScheme`, tonal spot).
