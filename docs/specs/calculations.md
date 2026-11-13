# Spec: calculations

Status: **normative**. The `core` package implements exactly these rules. Tests cite the sections
(`// spec: calculations.md §N`). When you change a rule, change this file in the same commit.

Each rule marked **(setting)** is a user setting; the value in the rule is its default.

---

## §1 Conventions

- **Instants** are stored in UTC and truncated to the full minute when recorded. All durations are
  whole **minutes** (`int`).
- **Calendar days** are evaluated in the **home time zone** (setting, default `Europe/Berlin`).
  A day is `[local 00:00, next local 00:00)` and can be 23 h or 25 h long on DST changes.
- **Intervals** are half-open `[start, end)`. An open interval (`end == null`) is evaluated with
  `end = now`. Intervals that cross midnight are split at local midnight.
- `|X|` is the total length in minutes of the union of the intervals in X. `∪` is the union and `∩` the intersection.
- Weekdays use ISO numbering: Monday = 1 … Sunday = 7. A week is Monday–Sunday (ISO week).
- Deleted rows (tombstones) are ignored everywhere.

## §2 Worked time

For a day D:

- `S(D)` = all work sessions clipped to D (any location).
- `B(D)` = all breaks clipped to D.
- **Working intervals** `WI(D) = ∪S(D) − ∪B(D)`. Breaks outside sessions have no effect.
- **Worked time** `W(D) = |WI(D)|`.
- `W_loc(D, l)` = worked time from sessions with location `l` (`office`, `home`, `on_site`, `travel`),
  minus breaks, using the same union logic. If sessions with different locations overlap, the overlap
  counts for the location of the session that **started later** (it is the more recent fact).

Overlapping or duplicated sessions, for example after a sync conflict, therefore never count twice.

**Example**: sessions 08:00–12:00 and 11:30–17:00, break 12:00–12:30 → `∪S` = 08:00–17:00 (540 min),
minus 30 min break → `W` = 510 min.

## §3 Project time and unassigned time

Project time comes from two kinds of `project_entries` (data-model §4):
- **Time spans** (timer or start/end): `P(D)` = these entries clipped to D. Their project time is
  `|∪P(D) ∩ WI(D)|`. Time outside working intervals isn't counted and is flagged in the Review list
  (§12).
- **Durations** (date + minutes, the usual way): each counts with its full duration on its date. It
  isn't intersected with working time, because it has no clock time.

`project time(D)` = span project time + Σ durations on D.
**Unassigned** `U(D) = max(0, W(D) − project time(D))`.
If the project time is larger than `W(D)`, the excess is flagged as `project_over_work` (§12).

Per-project totals: `|∪P_p(D) ∩ WI(D)|` + Σ durations of p on D. If two span entries overlap, both
projects get the overlap; it is flagged as `overlapping_project_entries`, so totals per project can
then add up to more than the project time.

**Trip days** (§9; user decision 2026-11-08): on trip days only travel and on-site time is recorded,
no project time. If a trip touching D has a `project_id` (the earliest such trip), `U(D)` is booked
to that project: it is added to the project's total for D (order report, statistics, with the
destination as the activity), and the day's unassigned time is 0.

**Booking project time** (user request 2026-11-08): durations are entered in hours on a 15-minute
grid (`snapToQuarter`: nearest step, at least 0:15); existing values off the grid stay as they are
until changed. A start time is optional (then the entry is a span `start + duration`, start on the
quarter hour). The sheet suggests the day's unassigned time ("rest of the day", snapped) and the last
three comments of the chosen project (`recentNotes`).

### §3.1 Project totals and budget

Requested by the user 2026-11-08 (project page). The **booked minutes** of a project on a day are its
share of `bookedByProject` (§3: interval entries inside working time, durations, and on trip days the
trip project's unassigned time). The project page shows them per day with the notes of that day's
entries and durations, and sums them for this week, month, year and in total.

A project may have a **budget** (`budget_min`, data-model §3). The running total in date order makes
two notices (§12, category `project_budget`): `project_budget_near` on the day the total first
reaches **80 %** of the budget and `project_budget_over` on the day it first exceeds **100 %**; when
both fall on the same day, only the second. Their fix opens the project page.

## §4 Breaks: ArbZG §4

Let `W = W(D)` before any deduction.

- **Required break** `R(W)`: `0` if `W ≤ 360`; `30` if `360 < W ≤ 540`; `45` if `W > 540` (minutes).
- **Countable break time** `C`: the sum of all **gaps between consecutive working intervals** within D
  that are **≥ 15 min** each. A gap is either a recorded break or time between clock-out and clock-in.
  Gaps shorter than 15 min don't count.
- **Missing break** `M = max(0, R(W) − C)`.
- **Continuous work check**: the worked minutes of every stretch of working intervals not separated
  by a countable gap (≥ 15 min) must be ≤ 360, otherwise warning `work_over_6h_without_break`.
  Gaps shorter than 15 min neither count as a break nor as work.
- **Mode (setting)**:
  - `warn` (default): `W_eff = W`. If `M > 0` → warning `break_missing` with M minutes.
  - `deduct`: deduct the **smallest** whole-minute `d ≥ 0` with `C + d ≥ R(W − d)` and set `W_eff = W − d`.
    This never pushes a day further than the threshold requires.

**Examples (deduct mode)**:

| W | C | d | W_eff | why |
|---|---|---|---|---|
| 6:00 | 0 | 0 | 6:00 | R(360) = 0 |
| 6:10 | 0 | 10 | 6:00 | R(360) = 0 ≤ 0 + 10 |
| 8:00 | 15 | 15 | 7:45 | R = 30 needs 15 more |
| 9:10 | 0 | 30 | 8:40 | d = 10 → R(9:00) = 30 > 10; d = 30 → R(8:40) = 30 ≤ 30 |
| 9:30 | 30 | 15 | 9:15 | R(9:15) = 45 ≤ 30 + 15 |

In `warn` mode `W_eff = W`. Everything below uses `W_eff`.

### §4.1 Usual break (defaults)

Two settings describe the user's usual break: `breaks.default_start_min` (minutes since local
midnight, default `720` = 12:00) and `breaks.default_min` (length, default `30`). They only prefill
times; they never create or deduct a break on their own.

- **New break** in the editor: from the usual start for the usual length.
- **Missing-break fix** (`suggestBreak`): the usual slot (usual start, the missing length) if it lies
  completely inside one working interval of the day; otherwise centred in the longest working
  stretch, rounded down to 5 min.
- **Quick entry** (§17): a bare `p` / `pause` means the usual length; a break is put at the usual
  start if it fits completely inside the range, otherwise centred.

## §5 Other ArbZG checks (warnings only)

- §3 ArbZG: `W(D) > 600` → `over_10h`.
- §5 ArbZG: the time between the end of the last working interval of D−1 and the start of the first
  working interval of D is < 11 h (660 min) → `rest_under_11h`. Checked only if both days have work.
- §9 ArbZG: work on a Sunday or a public holiday → `sunday_or_holiday_work` (info).
- The checks use **actual** recorded times, also on trip days (§9).

## §6 Public holidays

Holidays for the configured **federal state** (setting: one of the 16 state codes
`BW BY BE BB HB HH HE MV NI NW RP SL SN ST SH TH`).

Easter Sunday is computed with the anonymous Gregorian algorithm (Meeus/Jones/Butcher). E = Easter Sunday.

| Holiday | Date | States |
|---|---|---|
| Neujahr | 01-01 | all |
| Heilige Drei Könige | 01-06 | BW, BY, ST |
| Internationaler Frauentag | 03-08 | BE (since 2019), MV (since 2023) |
| Karfreitag | E − 2 | all |
| Ostersonntag | E | BB |
| Ostermontag | E + 1 | all |
| Tag der Arbeit | 05-01 | all |
| Christi Himmelfahrt | E + 39 | all |
| Pfingstsonntag | E + 49 | BB |
| Pfingstmontag | E + 50 | all |
| Fronleichnam | E + 60 | BW, BY, HE, NW, RP, SL |
| Mariä Himmelfahrt | 08-15 | SL; BY only with setting `by_assumption_day` (default true) |
| Weltkindertag | 09-20 | TH (since 2019) |
| Tag der Deutschen Einheit | 10-03 | all |
| Reformationstag | 10-31 | BB, MV, SN, ST, TH; HB, HH, NI, SH (since 2018); **all** states in 2017 (one-off) |
| Allerheiligen | 11-01 | BW, BY, NW, RP, SL |
| Buß- und Bettag | Wednesday before 11-23 | SN |
| 1. Weihnachtstag | 12-25 | all |
| 2. Weihnachtstag | 12-26 | all |
| Tag der Befreiung | 05-08 | BE, **2020 and 2025 only** (one-off) |

Not covered (enter as `extra_holiday` absences): purely local holidays (Augsburger Friedensfest,
Fronleichnam in parts of SN/TH), future one-off holidays, company days off (e.g. 24.12/31.12).
Rules are applied from 1995 onwards (Buß- und Bettag stopped being nationwide in 1995); earlier years
aren't supported.

**Checks**: Easter 2026-04-05, 2027-03-28; Buß- und Bettag 2026-11-18, 2027-11-17.

## §7 Target time

- The **schedule** valid on D is the `work_schedules` row with the greatest `valid_from ≤ D`.
  Before the first schedule, the target is 0.
- `T_sched(D)` = the schedule's minutes for weekday(D).
- `T(D)` = 0 if D is a public holiday (§6); otherwise `T_sched(D)`.
- An `extra_holiday` or `short_time` (Kurzarbeit) absence with fraction f reduces the target:
  `T(D) = T(D) × (1 − f)`, rounded to the minute.
- A **workday** is a day with `T(D) > 0`.

## §8 Credited time and overtime balance

- **Credited time** `Cr(D)`:
  - normally `W_eff(D)`;
  - on **trip days, Saturdays, Sundays and public holidays**, replaced by §9.
- **Absence credit**: each `vacation`, `sick`, `child_sick` or `special_leave` absence on D with
  fraction f adds
  `f × T(D)` to `Cr(D)`, rounded to the minute. Several absences on D add up to at most `T(D)`.
- `comp_time` (Überstundenabbau / Gleittag) gives **no** credit, so the day's target lowers the balance.
- **Daily difference** `Δ(D) = Cr(D) − T(D)`.
- **Overtime balance** at the end of day D = `starting_balance` (setting, minutes, may be negative)
  + Σ Δ(d) for all d from `balance_start_date` (setting) through D.
- **Balance by month** (Today's time account tile and its detail): per calendar month from the
  balance start, the change `Σ Δ(d)` over its counted days and the balance at its end. The month
  of `balance_start_date` opens with `starting_balance`; the current month ends today.
- The UI shows "balance up to yesterday" and "today so far". Today counts `Cr(today)` so far
  against the full `T(today)`.
- Days **before `balance_start_date`** are outside the balance: the calendar shows at most their
  worked time, no target, no `Δ`, and they are left out of week and month totals and the balance
  curve. (The schedule may start earlier, e.g. on 1 January for the vacation account, §10.)

## §9 Trip days, weekends and holidays: credited time and Sunday hours

A **trip day** is every local date touched by `[trip.depart, trip.return)`. An open trip touches all
days up to today.

**Which days follow §9** (user decision 2026-11-08): every trip day, and **every Saturday, Sunday and
public holiday, with or without a trip**. Workdays and days off without a trip are credited normally
(`Cr = W_eff`, §8).

Day type of D:
1. `holiday`: D is a public holiday (§6).
2. `sunday`: weekday 7.
3. `saturday`: weekday 6.
4. `workday`: weekday 1–5 with `T(D) > 0`.
5. `day_off`: weekday 1–5 with `T(D) = 0`, for example a part-time day off. Treated like `saturday`
   (default; the user works full-time Mon–Fri, so this doesn't apply to them yet).

**Service trip** (user decision 2026-11-09, from the employer's working-time rules): a trip with
`service = true` (data-model §9, default) is a business trip with service, installation or
commissioning work on a site. Its extra work is paid as a flat 35 % supplement per trip day, so
the account gets at most 8 h. Other business trips (`service = false`: fair, training, meeting)
get their real time, travel included, up to 10 h. A day touched by several trips is a service day
if any of them is a service trip. Days without a trip follow the "other" column.

`W_eff(D)` counts travel and all other work together; `Wt(D)` = `W_loc(D, travel)` (time in transit).

| Day type | Service trip | Other trip, or no trip | Setting |
|---|---|---|---|
| workday | `T(D)` exactly, however long or short the day was | `min(W_eff, 600)`; without a trip §8 (`W_eff`, no cap) | `travel.day_cap_min = 600` |
| saturday | `min(W_eff, 480)` | `min(W_eff, 600)` | `travel.service_saturday_cap_min = 480` |
| sunday | **0**; travel + work become **Sunday hours** `S(D) = min(W_eff, 720)`, reported for HR (extra pay), not in the balance | same | `travel.sunday = sunday_hours`, `travel.sunday_hours_cap_min = 720` (alternative `work_only`: `Cr = W_eff − Wt`, travel counts 0, no Sunday hours) |
| holiday | like sunday | like sunday | `travel.holiday = like_sunday` |
| day_off | like saturday | like saturday | `travel.day_off = like_saturday` |

**35 % days**: every day of a service trip except Sundays and public holidays (`DayResult.servicePayDay`).
They are counted per month (timesheet: screen and PDF), to check the payslip.

**Examples** (T = 480 Mon–Fri):

| Day | Service trip | Other trip |
|---|---|---|
| Wed, 2 h on site + 1 h travel | 480 | 180 |
| Wed, 3 h travel only | 480 | 180 |
| Wed, 7 h office + 2 h travel | 480 | 540 |
| Wed, a trip day without any work | 480 | 0 |
| Sat, 3 h on site + 2 h travel | 300 | 300 |
| Sat, 12 h travel | 480 | 600 |
| Sat, 6 h on site + 6 h travel | 480 | 600 |
| Sun, 4 h travel + 9 h on site | `Cr = 0`, `S = 720` | same |

History: until v0.6.2 every trip weekday got `T(D)`, Saturdays were capped at 11 h (travel and work
together) and Sunday hours at 11 h (user decisions 2026-11-07/08). The settings `travel.workday`,
`travel.saturday_cap_min`, `travel.saturday_cap_scope` and `travel.sunday_cap_min` are no longer
read. The Working Hours Act checks (§4, §5) still use the real recorded times.

### §9.1 Travel record (Reisenachweis)

The overtime account and the travel record are separate (user request 2026-11-08). §9 decides only
what the **account** credits (on a workday trip: the target, however long it took). The **travel
record** shows the real times of every trip day, to the minute, from the travel and on-site sessions
(`tripLegs`):

- **Anfahrt** (outbound): travel time that starts before the day's last on-site time; on a day
  without on-site time, unless it is the trip's last day (and not also its first).
- **Beim Kunden** (on site): on-site time.
- **Rückfahrt** (inbound): travel time after the day's last on-site time; on the trip's last day
  without on-site time.

The travel report lists, per trip day, the from–to times of each leg, the travel and on-site sums,
what the account credited, hours away and the per-diem. On Today a trip day offers the next step
(`tripSteps`): start outbound → arrived at the customer (travel ends and on-site starts in the same
minute) → start the way back → back home (clock out, offer to end the trip); clocking out in between
(end outbound, done at the customer) is the second choice.

## §10 Vacation account

For calendar year Y:
- **Entitlement** = `annual_vacation_days` of the schedule valid on Y-01-01. If there is none (first
  schedule starts during Y), the first schedule starting in Y is used. Setting
  `vacation.entitlement.<Y>` overrides both, for example for a pro-rata first year.
- **Carry-over** = setting `vacation.carry_over.<Y>` (default 0). Entered in the setup and on the
  vacation planner's account card; unset, the dialog suggests the remaining days of Y−1.
- **Taken** = Σ fraction of `vacation` absences on **workdays** (§7) in Y up to today.
- **Planned** = the same for days after today.
- **Remaining** = entitlement + carry-over − taken − planned.

### §10.1 Bridge days (vacation planner)

Requested by the user 2026-11-08. A day is **free** if its target is 0 (§7: weekend, public holiday,
`extra_holiday`, no scheduled work) or it has a full-day absence. Free days in a row form a block; a
block **has a holiday** if one of its days is a public holiday (§6) or an `extra_holiday`.

A **bridge** is a run of 1–3 working days between two free blocks where at least one of the two
blocks has a holiday (so the plain week between two weekends is never one). Taking those days off
joins both blocks: **free days** = from the first day of the left block to the last day of the
right block. Only bridges whose working days all lie in the year and not before today are
suggested, sorted by free days per vacation day (descending), then by date. `bridgeDays` implements
this; the vacation planner marks the days and offers to book them as vacation.

### §10.2 Carry-over deadline

Requested by the user 2026-11-09. Carried-over vacation must be taken by the end of month N of the
year; setting `vacation.carry_deadline_months` (default **3**, the statutory 31 March of § 7 (3)
BUrlG; 0 = off). From 1 January until that deadline, **open carry-over** = carry-over − vacation
days (taken and planned, workdays only, as above) from 1 January through the deadline. While it is
above 0, Today shows "Resturlaub aus <Y−1>: noch n Tage bis <deadline> verplanen"
(`vacationCarryLeft`). After the deadline nothing is shown. Only vacation has such a deadline: the
overtime balance is carried over without one (user 2026-11-09).

### §10.3 Next vacation

Requested by the user 2026-11-10. Vacation days (workdays only, as in §10) joined only by free days
(target 0: weekend, holiday) form a **block**; a workday without vacation ends it. The **next
vacation** is the first block whose first vacation day lies after today. The block today belongs to
is skipped, also on its weekend (the last workday before a free today is a vacation day): that
vacation is already running. Its **days** are the vacation fractions in the block. Today's vacation
tile shows "Nächster Urlaub in n Tagen · d Tage" ("morgen" for tomorrow; `nextVacation`).

## §11 Home office

### §11.1 Home-office value of a day

For a day D with `W(D) > 0` that is **not a trip day**, with `h = W_loc(D, home)`:

| Mode (setting `home_office.day_rule`) | `H(D)` |
|---|---|
| `majority` (default) | 1 if `h > W(D) / 2`, otherwise 0. Exactly half is 0. |
| `any` | 1 if `h > 0`, otherwise 0 |
| `proportional` | `h / W(D)` |

Trip days and days without work have `H(D) = 0`.

### §11.2 Quota

A rule has `period` (`week` | `month`), `unit` (`days` | `hours`), `max_percent` and
`basis` (`worked` | `scheduled`). Rows with the same `(period, unit)` are versions of one rule. The
version with the greatest `valid_from ≤ first day of the period` applies to the **whole** period.

For a period P, evaluated on day `today`, with `P≤` = the days of P up to and including today:

- unit `days`:
  - `used = Σ H(D)` over `P≤`.
  - basis `worked`: `base = #{D ∈ P≤ : W(D) > 0}`.
  - basis `scheduled`: `base = Σ (1 − absence fraction) over workdays D ∈ P`. This is the **whole**
    period, including future days. Absences here are vacation, sick, special leave and comp time.
  - `percent = used / base` (0 if base = 0).
- unit `hours`: `used = Σ W_loc(D, home)` over `P≤`, `base = Σ W(D)` over `P≤`.

### §11.3 Forecast (unit `days`)

- `remaining` = workdays in P **after today** without a full-day absence. Today counts too if it is a
  workday without work yet.
- basis `worked`: `allowed_total = floor(max_percent × (base + remaining))`.
- basis `scheduled`: `allowed_total = floor(max_percent × base)`.
- `left = max(0, allowed_total − used)`.

**Example**: 40 %/month, basis worked. So far 8 days worked, 5 of them at home, 12 workdays left →
`floor(0.4 × 20) = 8` → **3 left**.

### §11.4 Warning

When clocking in with location `home` would make `used + 1 > allowed_total` for any rule, the app
warns. It never blocks. The warning also appears in the Review list.

### §11.5 Yearly count

`Σ H(D)` per calendar year, using the `majority` rule regardless of the setting. Tax law counts days
"überwiegend" at home.

## §12 Review list (anomalies)

Computed, never stored:
- `open_session_over_12h`: a session open for more than 12 h (setting).
- `overlapping_sessions`: overlaps between sessions (harmless to totals, see §2).
- `overlapping_project_entries` (§3).
- `project_outside_session` (§3).
- `project_over_work`: more project time than worked time on a day (§3).
- ArbZG warnings (§4, §5).
- Home-office quota warnings (§11.4).
- `project_budget_near`, `project_budget_over`: a project's budget reached 80 % / 100 % (§3.1).
- `balance_zone`: the overtime balance entered a worse zone (§20.1).
- `week_over_max`, `week_average_over`: weekly limits (§22).
- `unassigned` (only when asked for): worked time without a project on a day that is done (not
  today while clocked in) and not a trip day (§3). `suggestBreak` places a missing break in the
  middle of the day's longest working stretch, on a 5-minute grid.

**Which items become cards** (user request 2026-11-08): items fall into categories
(`NoticeCategory`: unassigned, breaks, long day, rest, Sunday work, open session, overlaps, project
time, home-office quota, open trip, project budget, balance zone, week limit), each switched on or off by the setting `notices.show.<category>`
(default on). Unassigned time is an item only from `notices.unassigned_min` minutes on (default 30).
A card closed with × is dismissed for good: its key (`noticeKey` = date/kind[/arbzg][/ref]) is written
to `dismissed_notices` (data-model §14), so it stays hidden on every device. Switched-off and
dismissed items still put a small marker on their day in the calendar, and the day view lists them
("n hidden notices", dismissed ones can be shown again). "More than 6 h without a break" is not shown
when the same day has the missing-break item (one fix covers both).

**Accepted** (user request 2026-11-13): a card, a hidden notice in the day view and a step of the
check also offer **Akzeptieren**: the finding stays a rule violation, but the user accepts it. The
key is written to `dismissed_notices` with `accepted = true` (data-model §14). An accepted item is
neither a card nor a hidden notice, puts no marker on its day and doesn't count in the pattern hints
(§23). Settings → Hinweise counts them, can accept all dismissed ones at once and can report all
accepted ones again.

**Checking a week or month** (user request 2026-11-08): a range is **complete** when it has no
shown items (category on, not dismissed) up to today. The week view sums its items in one card
("5 Hinweise an 3 Tagen", a line per day) with **Woche prüfen**, or shows "Woche vollständig"; the
timesheet in the reports shows "Monat vollständig" or the open count with **Monat prüfen**. Checking
steps through the items one at a time: the fix, **Ausblenden** (dismiss for good) or
**Überspringen**; a fix that only opens the day ends the check there; at the end "Alles erledigt".

## §13 Per-diem basis (Verpflegungsmehraufwand)

For each trip with `depart` and `return`. An open trip has no per-diem yet.

- **Absence per day** `A(D)` = `|[depart, return) ∩ D|` in minutes.
- **Single local date** (depart and return on the same date): category `partial` if `A > 480`,
  otherwise `none`.
- **Several dates, `overnight = false`** ("Mitternachtsregel"): the whole duration counts as one
  day, assigned to the date with the larger `A`; a tie goes to the departure date. Category `partial`
  if the total is more than 480 min. All other dates get `none`.
- **Several dates, `overnight = true`**: the departure date and the return date are `partial`
  (regardless of hours); every date in between is `full`.
- **Location of a day** (§13.1): country and city in effect on D. **Amount** = the rate for the
  category for that location (§13.0).
- **Meal reduction** for each provided meal (`trip_meals` for D): breakfast 20 %, lunch 40 %,
  dinner 40 % **of the full-day rate of that day's location** (settings). The amount never goes
  below 0.

### §13.0 Rates

Requested by the user 2026-11-09 (step 5). Rates are public values and built in; the user's own
rows (`per_diem_rates`, data-model §11) supersede them.

- **Built in**: `DE` from 2020-01-01: partial 14 €, full 28 €, lodging 20 € (R 9.7 (3) LStR), and
  every country and city of the BMF letter of 5 Dec 2025 (BStBl I 2025, 2078) from 2026-01-01:
  partial, full and lodging (`bmfRates2026`, generated from the letter's table with ISO codes). The
  letter's notes are built in too: Micronesia (`FM`) uses the Philippines' rates; Antigua and
  Barbuda, Dominica, Grenada, Guyana, St. Kitts and Nevis, St. Lucia, St. Vincent and the
  Grenadines and Suriname use those of Trinidad and Tobago; **any other country not listed uses
  Luxembourg's rates**. Older foreign rates are not built in (user rows).
- **Lookup** for country C, city Y, date D (`perDiemRateOn`): among the rows of C (after the alias
  above) with `valid_from ≤ D`, the rows for city Y if any exist, otherwise the rows without a city;
  the greatest `valid_from` wins, user rows win ties. If C has no row at all, Luxembourg's.
- Checked 2026-11-09: the 2026 domestic rates are unchanged (14/28 €); meal reductions 5.60 € /
  11.20 € / 11.20 €.

### §13.1 Several places in one trip

A trip has a country and an optional city (data-model §9). **Stops** (`trip_stops`, data-model
§9.1) change the place from a date on: the place of D is the stop with the greatest date ≤ D, else
the trip's own. This follows the BMF rules: the arrival and in-between days use the place reached
before midnight (enter the stop on that date), the return day keeps the last place of work abroad.

### §13.2 Lodging

Trip field `lodging`: `company` (default: booked and paid by the employer, nothing to claim),
`flat` (lump sum) or `receipt` (field `lodging_cents`, the total of the receipts). **Nights** = every
date of an overnight trip except the last. `flat`: Σ over the nights of the lodging rate of that
night's place (§13.0). No lump sum for nights on a plane, train or ship: pick `receipt` or adjust.

### §13.3 Mileage

Trip field `car_km` (own car, default 0). Amount = km × `travel.mileage_cents_per_km` (default 30,
the tax-free maximum of § 9 (1) no. 4a EStG).

### §13.4 Site allowance

Employers may pay an allowance per site day of a service trip; rates are settings per country
(`site_allowances`, data-model §11.1; country `*` = every other country), none built in.

- A **site day** is a date of a service trip (§9) with on-site time.
- If the trip has at least `travel.site_allowance_min_days` (default 2) site days in a row
  (consecutive dates), **allowance days** are all dates from its first to its last site day,
  continuously; otherwise none.
- Amount per allowance day = the rate for that day's place (§13.1), greatest `valid_from ≤ D`;
  missing rate → 0 and flagged.
- It is paid with the salary (taxable), so it is not part of the claim total. The timesheet counts
  the month's allowance days and amount (§21.3 style, only if there are any).

### §13.5 Trip expense report and claim deadline

Per finished trip (`tripExpenses`): the per-diem days (§13) with place, the lodging (§13.2),
mileage (§13.3), **claim total** = per-diem + lodging + mileage, the site allowance (§13.4) apart,
and two hints:

- **Laundry**: if the trip touches more than `travel.laundry_after_days` dates (default 0 = off;
  the user sets 5), "laundry can be claimed".
- **Claim deadline**: setting `travel.claim_deadline_months` (default 0 = off; the user sets 3).
  Deadline = the return date plus N months (the same day of month, or the month's last day). Trip
  field `claimed_on` (date) marks it as claimed. From the return until the deadline, while not
  claimed, Today shows a card "Reisekosten <destination> abrechnen bis <date>" with **Abgerechnet**
  (sets `claimed_on` to today); it turns red in the last 14 days. After the deadline nothing is
  shown.

Not covered: the higher per-diem when a return day is followed by another trip, flights over two
days (the BMF letter's Austria rate), and travel costs other than mileage (tickets are booked by the
employer or claimed with receipts).

## §14 Display

- Durations as `H:MM`, negative as `−H:MM`. Totals are computed in minutes first and formatted last,
  so the rows of a report always add up to its total.
- Percentages are shown with no decimal places, rounded half up.

## §15 Day types

Every date has at most one **day type** (user request 2026-11-08), shown with an icon in the
calendar and picked in the calendar and on Today:

| Type | Stored as | What can be recorded |
|---|---|---|
| Büro (`office`) | `days` row | sessions at the office, project time |
| Homeoffice (`home`) | `days` row | sessions at home, project time |
| Dienstreise (`business_trip`) | the day lies in a `trip` (§9) | travel and on-site time (booked to the trip's project, §3) |
| Urlaub | absence `vacation` | sessions at office/home, project time if worked; counts as overtime |
| Krank | absence `sick` | sessions at office/home, project time if worked; counts as overtime |
| Kinderkrankentag | absence `child_sick` (credits the target, §8) | sessions at office/home, project time if worked; counts as overtime |
| Gleitzeit | absence `comp_time` (no credit, costs the balance, §8) | sessions at office/home, project time if worked; counts as overtime |
| Kurzarbeit | absence `short_time` (lowers the target, §7) | sessions at office/home, project time if worked; counts as overtime |
| Feier-/Trauertag | absence `special_leave` (credits the target, §8) | sessions at office/home, project time if worked; counts as overtime |

**Work on absence days** (user request 2026-11-08): working time can be recorded on every type.
On absence days `W_eff` is credited on top of the absence credit (§8), so it counts fully as
overtime; on a Gleitzeit day it reduces the day's cost (`Δ = W_eff − T`).

**Derived type** of D: a full-day absence (its type); else a trip day → business trip; else the
`days` row; else, if worked, home office if more than half of `W(D)` was at home, otherwise office;
else a half-day absence; else none.

**Picking a type** (`setDayType`): office or home writes the `days` row and moves the sessions
starting on D to that location; an absence type writes one full-day absence of that kind; any type
removes the other absences on D (`extra_holiday` stays) and, unless office/home, the `days` row.
Business trip: the app creates or opens the trip. A day inside a trip can't get another work type
until the trip is changed; absence types are allowed (a full-day absence wins).

**Removing the type** (`clearDayType`, user request 2026-11-08, e.g. a weekend picked by mistake):
deletes the `days` row and the absences on D (`extra_holiday` stays); sessions and trips stay, so
the day falls back to its derived type (worked → office/home, else none). The app offers undo. A
day inside a trip stays a business trip; the app points to the trip instead.

## §16 Explaining a day's numbers

`explainDay` breaks `Cr(D)` and `T(D)` into the steps above, so the app can show *why* a figure is
what it is (tap on a number): `W(D)` → break deduction (§4) → `W_eff(D)` → the §9 rule that applied
(`creditRule`: trip workday = target, Saturday cap, Sunday rule, holiday, day off; `null` = counts as
is) → absence credit (§8) → `Cr(D)`; the target with its reason (schedule, holiday, lowered by
`extra_holiday`/`short_time`, no scheduled work); Sunday hours. `notCounted = W_eff − rule credit` is
the time a rule didn't count (negative: credited more than worked, e.g. a short trip workday).

## §17 Quick entry and day templates

**Quick entry** parses one line (`parseQuickEntry`):

| Token | Meaning |
|---|---|
| `8-16:30`, `08.15–12`, `8 - 16` | working time from–to, local; an end at or before the start is the next day |
| `1:30`, `1,5h`, `90m` | a project duration instead (only without a range) |
| `p30`, `p0:45`, `pause 30`, `p` | break length (`p` alone: the usual length, §4.1); placed at the usual start if it fits in the range, otherwise centred, rounded down to 5 min |
| `@home`, `@ho`, `@büro`, `@office` | location (default office) |
| `: ` and everything after it | note of the project entry |
| other words | project search (project-search.md); the best match is used |

A range creates a session, the break and a project entry over the whole range (the break is cut out
of project time by §3). A line without a range or duration records nothing.

**Day templates** (data-model §13) hold a day's rows in local wall-clock minutes. "Copy yesterday"
captures the previous day's finished sessions, breaks, entries and durations (`captureDay`) and
applies them to the chosen day (`applyDayTemplate`); saved templates work the same. Applying only
adds rows; the UI offers undo.

## §18 Finish-time forecast

Requested by the user 2026-11-08. While clocked in, Today shows when the day's target will be
reached and when 10 hours of work (ArbZG §3, §5) are reached, at the current pace. It assumes the
user works on without interruption **and takes the break still required by §4** (it is added once).

With `W`, `C`, `R` from §4, `d` the §4 deduction and `Cr` the credited time (§8) of today:

- **Countable break** `C' = C + b`, where `b` is the running break if it is at least 15 min long
  (it counts once work resumes), else 0.
- **Target**: if `T(D) > 0`, the day is no trip day (§9 credits the target there anyway) and
  `Cr + d < T(D)`, then `rest = T(D) − (Cr + d)` and
  `targetAt = now + rest + max(0, R(W + rest) − C')`; the second term is shown as "incl. n min break".
  Otherwise there is no target time (reached, or nothing to reach).
- **10-hour limit**: if `W < 600`, `limitAt = now + (600 − W) + max(0, 45 − C')`; otherwise none
  (the §5 warning covers it).
- On a break, both assume work resumes now. Times are whole minutes and move with the clock.

`dayForecast` implements this; the Android notification shows the target time as its subtext.

## §19 Stamping at another time

Requested by the user 2026-11-09. Clocking in or out, starting or ending a break, a location change
and the trip steps (§9.1) first ask for the time, with the current time preselected (Flutter time
picker; its title is the button's label). Cancelling stamps nothing. Synced setting
`ask_stamp_time` (Einstellungen, default **on**); off stamps right away, as before. The Android
notification, tile and widget run without a window and always stamp now.

The picked local time means today (home time zone); if that is still in the future, the user is
clocked in and the earliest instant (below) lies before today, yesterday (a session that runs past
midnight; `stampInstant`). A clock-in while clocked out never moves to yesterday: a time ahead of
now is refused, even when the last session ended days ago (else 08:00 picked at 07:58 on a Monday
would clock in on Sunday). A time in the future or before the earliest instant is refused with a snack bar
and nothing is stamped. Earliest instants (`TimeTracker.earliestAt`), so nothing overlaps:

| Stamp | Not before |
|---|---|
| clock in | the end of the latest finished session |
| clock out | the session start and the end of every finished break or project entry of the session |
| start break | as clock out, and the start of the running project entry |
| end break | the break start |
| location change (also clock in while clocked in elsewhere) | the session start |

The stamp is stored at the picked minute; the rows it ends end there too (a running project at the
break start or clock-out, the session at a location change). A project resumed after a break
(`resume_after_break`) starts when the break ends. Ending the trip after the last trip step uses
the clock-out time. `TimeTracker` throws an `ArgumentError` for a time in the future or before the
earliest instant (for clock-out: before the session start, reminders.md §1).

## §20 Balance traffic light

Requested by the user 2026-11-09. Employers often set zones for the overtime account; every limit
is a setting (minutes, positive; unset = no limit), none is built in:

| Setting | Meaning |
|---|---|
| `balance.yellow_plus_min`, `balance.yellow_minus_min` | yellow above +x / below −x |
| `balance.red_plus_min`, `balance.red_minus_min` | red above +x / below −x |
| `balance.max_plus_min`, `balance.max_minus_min` | the account's hard limit: above +x / below −x |

### §20.1 Zone

The zone of a balance B (§8, the running balance including the starting balance) is the worst that
applies: **over limit** if B > max⁺ or B < −max⁻, else **red** if B > red⁺ or B < −red⁻, else
**yellow** if B > yellow⁺ or B < −yellow⁻, else **green**. Without any limit set there is no zone
(`balanceZone` returns `null`) and nothing is shown.

- Today and the week view mark the balance with a dot in the zone's colour (green, amber, red;
  over limit red with an outline).
- **Notice** (`balance_zone`, §12, category `balance_zone`): on the first finished day whose closing
  balance is in a worse zone than the day before (green → yellow, yellow → red, red → over limit, or
  a jump), "Zeitkonto im gelben Bereich (+301:00)". Today is left out: its balance counts the full
  target against the time so far. Dismissed like any notice.

## §21 Supplement hours: special holidays and night work

Requested by the user 2026-11-09 (step 4 of the employer rules). Employers often pay supplements for
Sunday, holiday and night work; the app counts the hours per day and month so the payslip can be
checked. It computes no money.

### §21.1 Special holidays

Setting `supplement.special_days`: a comma-separated list of codes, default empty (none built in):
`new_year` (1 Jan), `easter_sunday`, `easter_monday`, `may_day` (1 May), `whit_sunday`,
`whit_monday`, `christmas_day` (25 Dec), `boxing_day` (26 Dec). Easter and Whit Sunday are Sundays,
the others nationwide public holidays, so every special day follows the Sunday rule of §9.

On a special day the Sunday hours `S(D)` of §9 are reported as **special holiday hours** instead
(`DayResult.specialHolidayHours`); `sundayHours` is then 0, so the two sums never overlap (user
decision: separate sums, e.g. for a 70 % and a 150 % supplement). With `travel.sunday = work_only`
there are no Sunday hours and so no special holiday hours either.

### §21.2 Night work

Night time is 23:00–06:00 local (§ 2 (3) ArbZG). A **night** of D runs from D 23:00 to D+1 06:00.
Night work counts if the working time `W` (sessions minus breaks, §2) inside one night is **at least
2 h** (the employer's rule; § 2 (4) ArbZG says "more than two hours"). Its minutes are split by
calendar day: the part before midnight belongs to D, the part after to D+1. **Night hours**
`N(D)` = the counting parts of the night of D−1 (00:00–06:00) and of the night of D (23:00–24:00).

Setting `night_work.credit`:

- `count` (default): `N(D)` is only reported; the credited time is unchanged.
- `exclude` (the user's choice: night work is paid out, not put on the account): the time basis of
  §8/§9 is `W_eff(D) − N(D)` (not below 0): days without a rule credit it, Saturday and other-trip
  caps apply to it, the `work_only` Sunday rule subtracts travel from it. A service-trip workday
  still gets `T(D)`, and Sunday hours (§9, §21.1) still count the full `W_eff(D)`, because the
  supplements add up.

### §21.3 Display

Day, week and Today show special holiday hours and night hours next to the Sunday hours when they
are above 0. The day explanation (§16) lists them, and for `exclude` it says the night hours are
not on the account. The timesheet (screen and PDF) has a column and a total for each. The monthly
reminder on the work PC (work-pc.md §4) names the month's Sunday/holiday, special holiday and night
hours next to the balance.

## §22 Weekly limits

Requested by the user 2026-11-09 (step 6 of the employer rules). The Working Hours Act allows
8 h per workday (Monday–Saturday), up to 10 h if the average stays at 8 h over 6 months or 24 weeks
(§ 3 ArbZG); per week that is at most 60 h and 48 h on average. Both are public defaults and
settings (0 = off):

| Setting | Default | Meaning |
|---|---|---|
| `limits.week_max_min` | 3600 | most worked time in one week |
| `limits.week_avg_min` | 2880 | most average worked time per week |
| `limits.avg_weeks` | 24 | weeks of the rolling average |

- **Worked time of a week** `W_week` = Σ `W(D)` Monday–Sunday: all recorded work including travel,
  minus breaks (§2), whatever the account credits (user decision).
- **Rolling average** of the week starting Monday M = Σ `W_week` of the last N weeks up to and
  including M's, divided by their number; weeks before the week of the balance start (§8) are left
  out, so early on fewer weeks count.
- **Notices** (`week_limit`, category `week_limit`, dated the week's Sunday, only finished weeks):
  `week_over_max` for a week with `W_week` above the maximum; `week_average_over` for the first week
  whose average is above the limit after a week at or below it.
- The week view shows the week's worked time and the average next to the week total, in the error
  colour when above the limit.

## §23 Pattern hints

Requested by the user 2026-11-10. The month report (Berichte) shows a card with friendly hints about
the month shown, up to today (`monthPatterns`). They come only from the day results and their
Working Hours Act findings (§4, §5); none is a new rule or a notice:

| Kind | Days counted | Shown from |
|---|---|---|
| `missingBreak` | a §4 finding: break missing or over 6 h without a break | 2 days |
| `longDays` | a §3 finding: over 10 h worked | 1 day |
| `shortRest` | a §5 finding: under 11 h rest before the day | 1 day |
| `sundayWork` | work on a Sunday or public holiday | 1 day |
| `lateFinish` | the last worked span ends after 20:00 (today only once finished) | 3 days |
| `allBreaksKept` | positive: at least 10 days with work and no break finding (accepted or not) | — |

A finding whose notice was accepted (§12) doesn't count; for the break findings that is the day's
break notice (the missing break if the day has one, else "over 6 h without a break").

A hint opens the first day it counts (in the Berichte tab); the positive one opens nothing. The card
is hidden when no hint applies.
