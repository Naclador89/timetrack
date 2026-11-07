import '../model/attendance.dart';
import '../model/planning.dart';
import '../model/project.dart';
import '../rules/holidays.dart';
import '../rules/ledger.dart';
import '../sync/change.dart';
import '../time/home_time_zone.dart';
import '../time/local_date.dart';
import '../time/span.dart';
import 'settings.dart';

/// Turns stored rows into model classes (spec: data-model.md).
///
/// Deleted rows and rows missing a required field are skipped: they are
/// tombstones or still incomplete after a partial sync (sync-format.md §6).
/// Every `…FromRow` function returns `null` for such rows.
LedgerData ledgerDataFromRows(Iterable<StoredRow> rows) {
  final byTable = <String, List<StoredRow>>{};
  for (final r in rows) {
    (byTable[r.table] ??= []).add(r);
  }
  List<T> all<T>(String table, T? Function(StoredRow) map) => [
    for (final r in byTable[table] ?? const <StoredRow>[]) ?map(r),
  ];
  return LedgerData(
    sessions: all('work_sessions', workSessionFromRow),
    breaks: all('breaks', workBreakFromRow),
    entries: all('project_entries', projectEntryFromRow),
    durations: all('project_entries', projectDurationFromRow),
    schedules: all('work_schedules', workScheduleFromRow),
    absences: all('absences', absenceFromRow),
    trips: all('trips', tripFromRow),
  );
}

/// data-model.md §1.
WorkSession? workSessionFromRow(StoredRow r) => _use(r, (f) {
  return WorkSession(
    id: r.id,
    start: f.instant('start_utc')!,
    end: f.instant('end_utc'),
    location: WorkLocation.parse(f.string('location') ?? 'office'),
  );
});

/// data-model.md §2.
WorkBreak? workBreakFromRow(StoredRow r) => _use(
  r,
  (f) => WorkBreak(
    id: r.id,
    start: f.instant('start_utc')!,
    end: f.instant('end_utc'),
  ),
);

/// data-model.md §3.
Project? projectFromRow(StoredRow r) => _use(
  r,
  (f) => Project(
    id: r.id,
    name: f.string('name')!,
    projectNumber: f.string('project_number') ?? '',
    orderNumber: f.string('order_number') ?? '',
    client: f.string('client') ?? '',
    favorite: f.boolean('favorite') ?? false,
    archived: f.boolean('archived') ?? false,
  ),
);

/// data-model.md §4: a project entry with a time span (`start_utc` set).
ProjectEntry? projectEntryFromRow(StoredRow r) => _use(
  r,
  (f) => ProjectEntry(
    id: r.id,
    projectId: f.string('project_id')!,
    start: f.instant('start_utc')!,
    end: f.instant('end_utc'),
    note: f.string('note') ?? '',
  ),
);

/// data-model.md §4: a project entry recorded as a duration (no `start_utc`).
ProjectDuration? projectDurationFromRow(StoredRow r) {
  if (r.fields['start_utc'] != null) return null; // a time span instead
  return _use(
    r,
    (f) => ProjectDuration(
      id: r.id,
      projectId: f.string('project_id')!,
      date: f.date('date')!,
      minutes: f.number('duration_min')!.toInt(),
      note: f.string('note') ?? '',
    ),
  );
}

/// data-model.md §5.
Absence? absenceFromRow(StoredRow r) => _use(
  r,
  (f) => Absence(
    id: r.id,
    date: f.date('date')!,
    kind: AbsenceKind.parse(f.string('kind')!),
    fraction: f.number('fraction')?.toDouble() ?? 1,
  ),
);

/// data-model.md §6.
WorkSchedule? workScheduleFromRow(StoredRow r) => _use(
  r,
  (f) => WorkSchedule(
    id: r.id,
    validFrom: f.date('valid_from')!,
    weekdayMinutes: [
      for (final day in const ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'])
        f.number('minutes_$day')?.toInt() ?? 0,
    ],
    annualVacationDays: f.number('vacation_days')?.toDouble() ?? 0,
  ),
);

/// data-model.md §8.
HomeOfficeRule? homeOfficeRuleFromRow(StoredRow r) => _use(
  r,
  (f) => HomeOfficeRule(
    id: r.id,
    validFrom: f.date('valid_from')!,
    period: QuotaPeriod.values.byName(f.string('period')!),
    unit: QuotaUnit.values.byName(f.string('unit') ?? 'days'),
    maxPercent: f.number('max_percent')!.toInt(),
    basis: QuotaBasis.values.byName(f.string('basis') ?? 'worked'),
  ),
);

/// data-model.md §9.
Trip? tripFromRow(StoredRow r) => _use(
  r,
  (f) => Trip(
    id: r.id,
    depart: f.instant('depart_utc')!,
    returnAt: f.instant('return_utc'),
    destination: f.string('destination') ?? '',
    country: f.string('country') ?? 'DE',
    overnight: f.boolean('overnight') ?? true,
  ),
);

/// data-model.md §10.
TripMeals? tripMealsFromRow(StoredRow r) => _use(
  r,
  (f) => TripMeals(
    id: r.id,
    tripId: f.string('trip_id')!,
    date: f.date('date')!,
    breakfast: f.boolean('breakfast') ?? false,
    lunch: f.boolean('lunch') ?? false,
    dinner: f.boolean('dinner') ?? false,
  ),
);

/// data-model.md §11.
PerDiemRate? perDiemRateFromRow(StoredRow r) => _use(
  r,
  (f) => PerDiemRate(
    id: r.id,
    country: f.string('country')!,
    validFrom: f.date('valid_from')!,
    partialCents: f.number('partial_cents')!.toInt(),
    fullCents: f.number('full_cents')!.toInt(),
  ),
);

/// Runs [build] unless the row is deleted. A missing required field (a `!`
/// on null) or a malformed value means the row is incomplete: skip it.
T? _use<T>(StoredRow r, T Function(_Fields f) build) {
  if (r.isDeleted) return null;
  try {
    return build(_Fields(r.fields));
  } on TypeError {
    return null;
  } on FormatException {
    return null;
  } on ArgumentError {
    return null;
  }
}

/// Typed access to the JSON field values of a row.
extension type _Fields(Map<String, Object?> map) {
  String? string(String key) => map[key] as String?;
  bool? boolean(String key) => map[key] as bool?;
  num? number(String key) => map[key] as num?;
  DateTime? instant(String key) {
    final v = string(key);
    return v == null ? null : DateTime.parse(v).toUtc();
  }

  LocalDate? date(String key) {
    final v = string(key);
    return v == null ? null : LocalDate.parse(v);
  }
}

/// The [Ledger] the app evaluates: [rows] with their settings, at [now].
///
/// Without a configured state it uses NW holidays, and the balance starts at
/// the first schedule (or today) unless `balance_start_date` is set.
Ledger appLedger(Iterable<StoredRow> rows, DateTime now) {
  final data = ledgerDataFromRows(rows);
  final settings = AppSettings.fromRows(rows);
  final zone = HomeTimeZone(settings.homeTimeZone);
  final firstSchedule = data.schedules.isEmpty
      ? null
      : data.schedules
            .map((s) => s.validFrom)
            .reduce((a, b) => a.isBefore(b) ? a : b);
  return Ledger(
    data: data,
    zone: zone,
    holidays: HolidayCalendar(
      settings.federalState ?? FederalState.nw,
      options: settings.holidayOptions,
    ),
    settings: LedgerSettings(
      balanceStart: settings.balanceStart ?? firstSchedule ?? zone.dateOf(now),
      startingBalance: settings.startingBalance,
      breakMode: settings.breakMode,
      travel: settings.travel,
    ),
    nowMinute: epochMinute(now),
  );
}
