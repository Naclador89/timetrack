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
- An `extra_holiday` absence with fraction f reduces the target: `T(D) = T(D) × (1 − f)`, rounded to the minute.
- A **workday** is a day with `T(D) > 0`.

## §8 Credited time and overtime balance

- **Credited time** `Cr(D)`:
  - normally `W_eff(D)`;
  - on **trip days**, replaced by §9.
- **Absence credit**: each `vacation`, `sick` or `special_leave` absence on D with fraction f adds
  `f × T(D)` to `Cr(D)`, rounded to the minute. Several absences on D add up to at most `T(D)`.
- `comp_time` (Überstundenabbau / Gleittag) gives **no** credit, so the day's target lowers the balance.
- **Daily difference** `Δ(D) = Cr(D) − T(D)`.
- **Overtime balance** at the end of day D = `starting_balance` (setting, minutes, may be negative)
  + Σ Δ(d) for all d from `balance_start_date` (setting) through D.
- The UI shows "balance up to yesterday" and "today so far". Today counts `Cr(today)` so far
  against the full `T(today)`.

## §9 Travel: credited time on trip days

A **trip day** is every local date touched by `[trip.depart, trip.return)`. An open trip touches all
days up to today.

Day type of a trip day D:
1. `holiday`: D is a public holiday (§6).
2. `sunday`: weekday 7.
3. `saturday`: weekday 6.
4. `workday`: weekday 1–5 with `T(D) > 0`.
5. `day_off`: weekday 1–5 with `T(D) = 0`, for example a part-time day off. Treated like `saturday`
   (default; the user works full-time Mon–Fri, so this doesn't apply to them yet).

`Wt(D)` = `W_loc(D, travel)` (time in transit), `Wo(D)` = `W_eff(D) − Wt(D)` (all other work).

| Day type | Credited `Cr(D)` | Setting |
|---|---|---|
| workday | `T(D)` exactly, even if `W_eff` is longer **or shorter** | `travel.workday = target` |
| saturday | `min(Wt + Wo, cap)`, cap = 660 min: the cap covers travel **and** work together | `travel.saturday_cap_min = 660`, `travel.saturday_cap_scope = total` (alternative `travel_only`: `min(Wt, cap) + Wo`) |
| sunday | **0**; travel + work together become **Sunday hours** `S(D) = min(Wt + Wo, cap)`, cap = 660 min, reported for HR (extra pay), not in the balance | `travel.sunday = sunday_hours`, `travel.sunday_cap_min = 660` (alternative `work_only`: `Cr = Wo`, travel counts 0, no Sunday hours) |
| holiday | like sunday | `travel.holiday = like_sunday` |
| day_off | like saturday | `travel.day_off = like_saturday` |

The workday rule applies to **every** weekday of a trip, including days spent only working at the
destination.

Confirmed by the user on 2026-11-07: every trip day is a normal day; a short trip day still gets the
full target; the Saturday cap covers the whole day; holidays are treated like Sundays. Also
2026-11-07: on trip Sundays, travel and on-site work count as Sunday hours for HR (max 11 h); they
appear in the monthly timesheet but don't add to the overtime balance. Days that follow the Sunday
rule (holidays `like_sunday`, days off `like_sunday`) get Sunday hours too. Sundays without a trip
are not affected (normal `W_eff`, §8).

**Examples** (T = 480 Mon–Fri):
- Wed, 3 h train + 8 h on-site → `Cr = 480`, Δ = 0.
- Wed, 2 h train only, trip starts at 16:00 → `Cr = 480`, Δ = 0.
- Sat, 12 h train → `Cr = 660`, Δ = +660.
- Sat, 4 h train + 3 h on-site → `Cr = 420`.
- Sat, 8 h train + 5 h on-site → `Cr = 660` (the cap covers the whole day).
- Sun, 6 h train → `Cr = 0`, `S = 360`.
- Sun, 4 h train + 9 h on-site → `Cr = 0`, `S = 660` (the cap covers the whole day).

## §10 Vacation account

For calendar year Y:
- **Entitlement** = `annual_vacation_days` of the schedule valid on Y-01-01. If there is none (first
  schedule starts during Y), the first schedule starting in Y is used. Setting
  `vacation.entitlement.<Y>` overrides both, for example for a pro-rata first year.
- **Carry-over** = setting `vacation.carry_over.<Y>` (default 0).
- **Taken** = Σ fraction of `vacation` absences on **workdays** (§7) in Y up to today.
- **Planned** = the same for days after today.
- **Remaining** = entitlement + carry-over − taken − planned.

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
- **Amount** = the rate for the category from `per_diem_rates` for `trip.country`, using the row
  with the greatest `valid_from ≤ D`.
- **Meal reduction** for each provided meal (`trip_meals` for D): breakfast 20 %, lunch 40 %,
  dinner 40 % **of the full-day rate** (settings). The amount never goes below 0.
- Rate defaults to pre-fill: `DE`, valid from 2020-01-01: partial 14.00 €, full 28.00 €.
  Checked on 2026-11-07 against several secondary sources: still valid in 2026 (the discussed raise
  to 16/32 € wasn't enacted), and the meal reductions are 5.60 € / 11.20 € / 11.20 €. Foreign rates
  change yearly (BMF letter; the 2026 rates are from 5 Dec 2025) and are entered by the user.
- Not covered: the three-month rule, several countries in one trip (the trip has one `country`),
  accommodation and travel costs.

## §14 Display

- Durations as `H:MM`, negative as `−H:MM`. Totals are computed in minutes first and formatted last,
  so the rows of a report always add up to its total.
- Percentages are shown with no decimal places, rounded half up.
