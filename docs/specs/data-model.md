# Spec: data model (fields of the synced tables)

Status: **normative**. These are the field names and value types in sync changes
(`sync-format.md` §4–§5) and in the local database. Mapping to model classes:
`packages/core/lib/src/data/mapping.dart`. Tests cite `data-model.md §N`.

Value types: `instant` = ISO-8601 UTC string with minute precision (`2026-11-07T08:00:00Z`);
`date` = `YYYY-MM-DD`; `int`; `num` (int or decimal); `bool`; `string`; `enum` = one of the listed
strings.

**Required** fields must be present for a row to be used. Rows missing a required field are
incomplete (for example while a sync is half applied) and are skipped (`sync-format.md` §6).
Optional fields fall back to the default shown. Unknown fields are kept in the database and ignored
by older app versions.

Every row also has the field `deleted` (`bool`, default `false`); deleted rows are skipped.

## §1 work_sessions
| Field | Type | Required | Default |
|---|---|---|---|
| start_utc | instant | ✓ | |
| end_utc | instant | | `null` = still clocked in |
| location | enum `office` `home` `on_site` `travel` | | `office` |
| tz | string (IANA) | | home time zone |
| source | enum `app` `manual` `auto` `watch` | | `app` |
| note | string | | `''` |

## §2 breaks
`start_utc` instant ✓, `end_utc` instant (null = running), `note` string.

## §3 projects
| Field | Type | Required | Default |
|---|---|---|---|
| name | string | ✓ | |
| project_number | string | | `''` |
| order_number | string | | `''` |
| client | string | | `''` |
| color | int (ARGB) | | app default |
| favorite | bool | | `false` |
| archived | bool | | `false` |

## §4 project_entries
A project time is **either a duration on a date** (the usual way) **or a time span**:

| Field | Type | Required | Default |
|---|---|---|---|
| project_id | string | ✓ | |
| date + duration_min | date + int (minutes) | ✓ unless `start_utc` is set | |
| start_utc | instant | ✓ unless `date` + `duration_min` are set | |
| end_utc | instant | | `null` = timer still running |
| note | string (short summary of the work) | | `''` |
| source | enum as in §1 | | `app` |

If `start_utc` is set, the row is a time span and `date`/`duration_min` are ignored.

## §5 absences
`date` date ✓, `kind` enum `vacation` `sick` `special_leave` `child_sick` `short_time` `comp_time`
`extra_holiday` ✓ (`child_sick` and `short_time` since 2026-11-08; older app versions skip them),
`fraction` num (1 or 0.5, default 1), `note` string.

## §6 work_schedules
`valid_from` date ✓, `minutes_mon` … `minutes_sun` int (default 0), `vacation_days` num (default 0).
(Lists aren't allowed as values, so there is one field per weekday.)

## §7 settings
Row id = setting key (e.g. `federal_state`), field `value` (string, num or bool) ✓.
All keys with their defaults are in `SettingKeys` / `AppSettings` (`core/lib/src/data/settings.dart`);
the rules they configure are in `calculations.md`. Enum values are stored in snake_case
(`like_sunday`, `travel_only`).

## §8 home_office_rules
`valid_from` date ✓, `period` enum `week` `month` ✓, `unit` enum `days` `hours` (default `days`),
`max_percent` int ✓, `basis` enum `worked` `scheduled` (default `worked`).

## §9 trips
| Field | Type | Required | Default |
|---|---|---|---|
| depart_utc | instant | ✓ | |
| return_utc | instant | | `null` = still travelling |
| destination | string | | `''` |
| country | string (ISO 3166-1 alpha-2) | | `DE` |
| purpose | string | | `''` |
| project_id | string | | none |
| overnight | bool | | `true` |
| note | string | | `''` |

## §10 trip_meals
`trip_id` string ✓, `date` date ✓, `breakfast` / `lunch` / `dinner` bool (default `false`).

## §11 per_diem_rates
`country` string ✓, `valid_from` date ✓, `partial_cents` int ✓, `full_cents` int ✓.

## §12 days
The day type picked for a date (calculations §15). **Row id = the date** (`YYYY-MM-DD`), so picks on
two devices merge by last-writer-wins. Only office and home office are stored here; business trips
are `trips`, absence types are `absences`.
`date` date ✓, `type` enum `office` `home` ✓. Since 2026-11-08.

## §13 day_templates
A saved typical day (calculations §17). `name` string ✓, `items` list ✓ of objects
`{kind: session|break|entry|duration, start, end (minutes since local midnight; end ≤ start = next
day), minutes (duration only), location (session), project_id (entry, duration), note}`.
Since 2026-11-08.

## §14 dismissed_notices
A notice card the user closed for good (calculations §12). **Row id = `noticeKey`**
(`YYYY-MM-DD/<review kind>[/<arbzg kind>][/<ref id>]`), so dismissals from two devices merge.
`date` date ✓. Undo / "show again" deletes the row (tombstone). Since 2026-11-08.

