import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timetrack_core/timetrack_core.dart';

// The app's state graph. All business rules live in timetrack_core; providers
// only wire data from the store into the rules, so widgets stay thin.

/// The local store. Overridden in `main()` (SQLite) and in tests (in memory).
final storeProvider = Provider<SyncStore>(
  (ref) => throw UnimplementedError('storeProvider must be overridden'),
);

/// The only way to write synced data. Overridden together with [storeProvider].
final repositoryProvider = Provider<SyncedRepository>(
  (ref) => throw UnimplementedError('repositoryProvider must be overridden'),
);

/// The wall clock; overridden in tests.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// All synced rows, re-emitted after every local write or sync.
final rowsProvider = StreamProvider<List<StoredRow>>(
  (ref) => ref.watch(storeProvider).watchRows(syncedTables),
);

final _rows = Provider<List<StoredRow>>(
  (ref) => ref.watch(rowsProvider).value ?? const [],
);

/// "Now", refreshed every 20 seconds so running timers move.
final nowProvider = StreamProvider<DateTime>((ref) async* {
  final now = ref.watch(clockProvider);
  yield now();
  yield* Stream.periodic(const Duration(seconds: 20), (_) => now());
});

DateTime _now(Ref ref) =>
    ref.watch(nowProvider).value ?? ref.watch(clockProvider)();

/// Typed settings with defaults.
final settingsProvider = Provider<AppSettings>(
  (ref) => AppSettings.fromRows(ref.watch(_rows)),
);

/// The home time zone.
final zoneProvider = Provider<HomeTimeZone>(
  (ref) => HomeTimeZone(ref.watch(settingsProvider).homeTimeZone),
);

/// Today in the home time zone.
final todayProvider = Provider<LocalDate>(
  (ref) => ref.watch(zoneProvider).dateOf(_now(ref)),
);

/// Clock-in, break and project commands.
final trackerProvider = Provider<TimeTracker>((ref) {
  final s = ref.watch(settingsProvider);
  return TimeTracker(
    ref.watch(repositoryProvider),
    now: ref.watch(clockProvider),
    autoClockIn: s.autoClockIn,
    resumeAfterBreak: s.resumeAfterBreak,
  );
});

/// Whether clocking in or out and breaks ask for the time (calculations
/// §19); a provider of its own so tests can turn it off.
final askStampTimeProvider = Provider<bool>(
  (ref) => ref.watch(settingsProvider).askStampTime,
);

/// What is running right now.
final trackerStateProvider = Provider<TrackerState>(
  (ref) => TrackerState.fromRows(ref.watch(_rows)),
);

/// All complete, non-deleted projects.
final projectsProvider = Provider<List<Project>>(
  (ref) => [
    for (final r in ref.watch(_rows))
      if (r.table == 'projects') ?projectFromRow(r),
  ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())),
);

/// Projects by id.
final projectByIdProvider = Provider<Map<String, Project>>(
  (ref) => {for (final p in ref.watch(projectsProvider)) p.id: p},
);

/// How often each project was used in the last 90 days (search ranking).
final projectUsageProvider = Provider<Map<String, ProjectUsage>>((ref) {
  final since = epochMinute(_now(ref)) - 90 * 1440;
  final counts = <String, int>{};
  final last = <String, int>{};
  for (final e in ref.watch(ledgerDataProvider).entries) {
    final start = epochMinute(e.start);
    if (start < since) continue;
    counts[e.projectId] = (counts[e.projectId] ?? 0) + 1;
    if (start > (last[e.projectId] ?? -1)) last[e.projectId] = start;
  }
  return {
    for (final id in counts.keys)
      id: ProjectUsage(count: counts[id]!, lastUsedMinute: last[id]),
  };
});

/// Rows converted to the model classes the rules work on.
final ledgerDataProvider = Provider<LedgerData>(
  (ref) => ledgerDataFromRows(ref.watch(_rows)),
);

/// Home-office rule versions.
final homeOfficeRulesProvider = Provider<List<HomeOfficeRule>>(
  (ref) => [
    for (final r in ref.watch(_rows))
      if (r.table == 'home_office_rules') ?homeOfficeRuleFromRow(r),
  ]..sort((a, b) => b.validFrom.compareTo(a.validFrom)),
);

/// Public holidays of the configured state (NW until a state is chosen; the
/// Today screen asks for it).
final holidaysProvider = Provider<HolidayCalendar>((ref) {
  final s = ref.watch(settingsProvider);
  return HolidayCalendar(
    s.federalState ?? FederalState.nw,
    options: s.holidayOptions,
  );
});

/// The school holidays of the configured state touching a year
/// (calculations §10.5).
final schoolHolidaysProvider = Provider.family<List<SchoolHoliday>, int>(
  (ref, year) => schoolHolidays(ref.watch(holidaysProvider).state, year),
);

/// Evaluates days and the balance. Rebuilt when data, settings or "now" change.
final ledgerProvider = Provider<Ledger>((ref) {
  final data = ref.watch(ledgerDataProvider);
  final settings = ref.watch(settingsProvider);
  final zone = ref.watch(zoneProvider);
  final now = _now(ref);
  final firstSchedule = data.schedules.isEmpty
      ? null
      : data.schedules
            .map((s) => s.validFrom)
            .reduce((a, b) => a.isBefore(b) ? a : b);
  return Ledger(
    data: data,
    zone: zone,
    holidays: ref.watch(holidaysProvider),
    settings: LedgerSettings(
      balanceStart: settings.balanceStart ?? firstSchedule ?? zone.dateOf(now),
      startingBalance: settings.startingBalance,
      breakMode: settings.breakMode,
      travel: settings.travel,
      expenses: settings.expenses,
    ),
    nowMinute: epochMinute(now),
  );
});

/// The overtime balance month by month through today (calculations §8),
/// computed once per ledger for Today's tile and its detail screen.
final monthlyBalancesProvider = Provider<List<MonthBalance>>(
  (ref) => ref.watch(ledgerProvider).monthlyBalances(ref.watch(todayProvider)),
);

/// The vacation account of a year as of today (calculations §10), with the
/// year's entitlement and carry-over settings.
final vacationAccountProvider = Provider.family<VacationAccount, int>((
  ref,
  year,
) {
  final data = ref.watch(ledgerDataProvider);
  final settings = ref.watch(settingsProvider);
  return vacationAccount(
    year: year,
    targets: ref.watch(ledgerProvider).targets,
    schedules: data.schedules,
    absences: data.absences,
    today: ref.watch(todayProvider),
    entitlementOverride: settings.number(SettingKeys.vacationEntitlement(year)),
    carryOver: settings.number(SettingKeys.vacationCarryOver(year)) ?? 0,
  );
});

/// The next vacation block after today (calculations §10.3), for the
/// countdown on Today's vacation tile.
final nextVacationProvider = Provider<NextVacation?>(
  (ref) => nextVacation(
    targets: ref.watch(ledgerProvider).targets,
    absences: ref.watch(ledgerDataProvider).absences,
    today: ref.watch(todayProvider),
  ),
);

/// The home-office quotas that apply today (one per rule series).
final homeOfficeQuotasProvider = Provider<List<HomeOfficeQuota>>((ref) {
  final ledger = ref.watch(ledgerProvider);
  final rules = ref.watch(homeOfficeRulesProvider);
  final dayRule = ref.watch(settingsProvider).homeOfficeDayRule;
  final today = ref.watch(todayProvider);
  return [
    for (final period in QuotaPeriod.values)
      for (final unit in QuotaUnit.values)
        if (ruleForPeriod(
              rules,
              period: period,
              unit: unit,
              periodStart: periodAround(today, period).$1,
            )
            case final rule?)
          evaluateQuota(ledger, rule, dayRule: dayRule),
  ];
});

/// The setup is complete: a federal state and at least one schedule.
final isSetUpProvider = Provider<bool>(
  (ref) =>
      ref.watch(settingsProvider).federalState != null &&
      ref.watch(ledgerDataProvider).schedules.isNotEmpty,
);

/// Meals provided on trip days (reduce the per-diem, calculations.md §13).
final tripMealsProvider = Provider<List<TripMeals>>(
  (ref) => [
    for (final r in ref.watch(_rows))
      if (r.table == 'trip_meals') ?tripMealsFromRow(r),
  ],
);

/// Per-diem rates: the user's own rows first (they win ties), then the
/// pre-filled domestic defaults.
final perDiemRatesProvider = Provider<List<PerDiemRate>>(
  (ref) => [
    for (final r in ref.watch(_rows))
      if (r.table == 'per_diem_rates') ?perDiemRateFromRow(r),
    ...defaultPerDiemRates(),
  ],
);

/// Saved day templates (data-model §13), by name.
final dayTemplatesProvider = Provider<List<DayTemplate>>(
  (ref) => [
    for (final r in ref.watch(_rows))
      if (r.table == 'day_templates') ?dayTemplateFromRow(r),
  ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())),
);

/// Keys of notices the user dismissed for good (data-model §14), accepted
/// ones included.
final dismissedNoticesProvider = Provider<Set<String>>(
  (ref) => dismissedNoticeKeys(ref.watch(_rows)),
);

/// Keys of notices the user accepted: reported nowhere (calculations §12).
final acceptedNoticesProvider = Provider<Set<String>>(
  (ref) => acceptedNoticeKeys(ref.watch(_rows)),
);

/// The Review items of a `(from, to)` range that show up somewhere (cards
/// or the calendar marker): all of them, with unassigned time from the
/// threshold on (calculations §12). Quotas are added by the caller.
final noticesProvider =
    Provider.family<List<ReviewItem>, (LocalDate, LocalDate)>((ref, range) {
      final settings = ref.watch(settingsProvider);
      return reviewItems(
        ref.watch(ledgerProvider),
        from: range.$1,
        to: range.$2,
        openSessionLimitMinutes: settings.openSessionLimitMinutes,
        includeUnassigned: true,
        unassignedMinMinutes: settings.noticeUnassignedMinMinutes,
        projects: ref.watch(projectsProvider),
        balanceLimits: settings.balanceLimits,
        weekLimits: settings.weekLimits,
      );
    });

/// A project's booked days, oldest first (calculations §3.1).
final projectHistoryProvider = Provider.family<List<ProjectDay>, String>(
  (ref, id) => projectHistory(ref.watch(ledgerProvider), id),
);

/// The notices of a `(from, to)` range that are shown as cards: their
/// category is on and they weren't dismissed (calculations §12). None
/// means the range is complete.
final openNoticesProvider =
    Provider.family<List<ReviewItem>, (LocalDate, LocalDate)>((ref, range) {
      final settings = ref.watch(settingsProvider);
      return splitNotices(
        ref.watch(noticesProvider(range)),
        shows: (c) => settings.showsNotice(c.wireName),
        dismissed: ref.watch(dismissedNoticesProvider),
        accepted: ref.watch(acceptedNoticesProvider),
      ).shown;
    });

/// The days of a `(from, to)` range with notices, shown or hidden but not
/// accepted: the small marker in the calendar.
final noticeDaysProvider =
    Provider.family<Set<LocalDate>, (LocalDate, LocalDate)>(
      (ref, range) => {
        for (final i in splitNotices(
          ref.watch(noticesProvider(range)),
          shows: (_) => true,
          dismissed: const {},
          accepted: ref.watch(acceptedNoticesProvider),
        ).shown)
          i.date,
      },
    );
