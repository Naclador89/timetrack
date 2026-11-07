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
`project_id` string ✓, `start_utc` instant ✓, `end_utc` instant (null = running), `note` string,
`source` enum as in §1.

## §5 absences
`date` date ✓, `kind` enum `vacation` `sick` `special_leave` `comp_time` `extra_holiday` ✓,
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
