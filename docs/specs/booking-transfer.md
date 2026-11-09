# Booking transfer: fill one week of project time into the company booking system

Status: **normative**. Code: `packages/core/lib/src/reports/week_booking.dart` (rows, rounding,
warnings, fingerprint), `app/lib/booking/` (setting, marker, preview, WebView),
`app/assets/booking/applus_fill.js` (fill script). Requested by the user 2026-11-09. Decision:
[ADR 0009](../decisions/0009-booking-transfer-webview.md).

TimeTrack **fills** the weekly project time form of the company booking system (APplus 7, page
`ProZeitWochenEingabe.aspx`) inside an embedded browser. The user checks the page, adds what
TimeTrack doesn't know (§4) and clicks **Buchen** himself. TimeTrack never books.

## 1. Where (Windows only)

- **Setting**: Einstellungen → App → **Buchungssystem (Adresse)**, shown only on Windows. Device
  local `local_values` key `booking_url`, empty by default, never synced. The address of the
  company page is typed in by the user and is **never** part of the repo (public, AGENTS.md).
- **Entry**: the week view of the calendar shows the action **An Buchungssystem übertragen** only
  on Windows and only while `booking_url` is set.

## 2. Rows (core: `buildWeekBooking`)

Input: the ledger, the projects, the Monday of the week.

1. For each day Monday–Sunday take the project time `DayResult.bookedByProject` (calculations §3,
   trip days included), the same source as the order report.
2. Projects **without a project number** are not transferred; they are listed as skipped with
   their minutes. Unknown project ids count as skipped too.
3. Group by **(project number, order number)**: projects with the same pair share one row; their
   minutes per day are added **before** rounding.
4. **Rounding** per row and day to half hours, nearest, halves up: `halfHours = (minutes + 15) ~/
   30`. So 0:14 → 0, 0:15 → 0,5 h, 0:44 → 0,5 h, 0:45 → 1 h.
5. Rows whose rounded week total is 0 are dropped (their time shows as a rounding difference, §3).
6. Order: project number, then order number.

Each row has the project number, order number, the names of the projects behind it and the half
hours Monday–Sunday. The week also carries its **ISO week number and ISO week year** (the year of
its Thursday), which are the page's `KW`/`JAHR`.

## 3. Warnings (shown in the preview, transfer still possible)

- **Running project timer**: a project entry without end that started in the week. Its time is
  counted up to now.
- **Unassigned time** per day (`DayResult.unassigned` > 0): worked time without a project.
- **Rounding difference**: per day where the transferred minutes (half hours × 30) differ from
  the exact project time of the transferred rows; also the week total of both.
- **Skipped projects** (§2.2).

## 4. What the user adds on the page

Only Projekt (project number), Auftrag (`ANP_AUFTRAG`, order number, left empty when the project
has none) and the hours are filled. Projektposition, Kostengruppe (required by the page), ReZu and
remarks are left to the user. No notes are sent.

## 5. Preview

A dialog lists the rows (project number / order / project names) × Mo–So in hours with a decimal
comma (`1,5`), row and day totals, the warnings and skipped projects, and the transfer marker
(§7). **Im Buchungssystem öffnen** is disabled when there are no rows.

## 6. Filling the page (embedded WebView2)

The page opens in a full window inside the app (WebView2, package `webview_windows`). The WebView
uses the Windows login (integrated authentication; the host of `booking_url` is passed as
`--auth-server-allowlist`). Popups of the page (pickers) are allowed. The fill script talks to the
page's own framework, so the page behaves as if the user had typed:

1. Wait until the page is ready (`app.readyState === "ready"` and `windowLoaded`), at most 30 s;
   otherwise show an error. If the expected fields (`KW`, `JAHR`, table `EDITOR`, `PROJEKT`,
   `DAUER`) are missing, stop with an error instead of filling half.
2. If the table already contains a project or a duration, ask in the app whether to replace it.
   No → stop, nothing changed. Yes → clear the form (`handleClearAll`).
3. Set `JAHR` and `KW` (as text) and run `setVonBis`, so the dates and locked days update.
4. Check each project number with the page's service (`checkProjekt`); unknown numbers are not
   filled and are reported.
5. Add rows as the page does on Tab in the last cell (clone the first row before `lastrow`,
   `setClonedNodes`). Per row set `PROJEKT` (the number returned by the check) and its name,
   `ANP_AUFTRAG`, and `DAUER` Mo–So in **seconds** (`halfHours × 1800`; the page's duration fields
   store seconds and show `hh:mm`). A day whose field is disabled (locked booking period) is not
   filled and is reported.
6. Recompute the sums (`setRowSums`, `setColSums`) and report: rows filled, unknown projects,
   locked days. The status bar then says to add Kostengruppe/Position and click Buchen.

## 7. Transfer marker

`local_values` key `booking_transfer/<ISO year>-W<week, 2 digits>` = JSON
`{"at": "<ISO 8601 UTC>", "fingerprint": "<§2 fingerprint>"}`, device local.

- The **fingerprint** is a text of the rows (project number, order number, half hours Mo–So); it
  changes exactly when the transferred values would change.
- Set when the page starts the booking job (`app.job.startJob(…, "insertWochenXmlJob", …)`,
  observed by a wrapper in the WebView). If that wasn't seen and the user closes the window after
  filling, ask **Wurde die Woche gebucht?**; Ja sets the marker.
- The week view shows **Übertragen am <date>**, or **Seit der Übertragung geändert** when the
  current fingerprint differs.
