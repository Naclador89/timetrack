# 0009: Fill the company booking form in an embedded WebView2, the user books

- Status: accepted (2026-11-09). Lifts the "copying hours into the company booking system" entry
  from the "Not wanted" list in `docs/status.md`.

## Context
The user books his project hours once a week in the company booking system (APplus 7, page
`ProZeitWochenEingabe.aspx`), which is only reachable inside the company network with Windows
login. Typing a week of hours by hand duplicates what TimeTrack already knows. The page has no
documented API; it is a script-heavy ASP.NET form (`app.form`, `app.soap`, `app.job`). APplus also
needs fields TimeTrack doesn't know (Projektposition, Kostengruppe, ReZu).

## Decision
- Windows only. TimeTrack opens the page in an **embedded WebView2** (`webview_windows`) and fills
  KW/Jahr and one row per project and order with the hours (rounded to 0.5 h). It **never books**:
  the user adds the missing fields, checks the hours and clicks "Buchen" himself.
- The fill script (`app/assets/booking/applus_fill.js`) goes through the page's own functions
  (`app.form.setFieldData`, `setVonBis`, the project service, `calculateSums`), so validation and
  sums work as if typed. It checks for the expected page parts first and reports instead of
  filling half.
- The address is a device-local setting, empty by default. The company host is never committed
  (public repo, ADR 0008).
- A booked week is remembered device-locally with a fingerprint of the rows, so the week view
  shows "transferred" or "changed since". Rules: `docs/specs/booking-transfer.md`.

Alternatives not taken: a bookmarklet or console script (clumsy, data has to be copied over);
posting straight to the booking job over HTTP (skips the page's checks and books without the
user's look); a browser extension (another thing to install and update).

## Consequences
- An APplus update can change field names or functions; the script then reports "unexpected page"
  and the user books by hand until the script is adjusted.
- WebView2 must be installed (it ships with Windows 10/11). The login uses
  `--auth-server-allowlist=<host>` so Windows login works without a prompt.
- Linux and Android are unaffected; the feature is hidden there.
