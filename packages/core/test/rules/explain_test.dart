// spec: calculations.md §16
import 'package:test/test.dart';
import 'package:timetrack_core/timetrack_core.dart';

const dev = 'aaaaaaaaaaaaaaaa';

void main() {
  late InMemorySyncStore store;
  late SyncedRepository repo;
  final now = DateTime.utc(2026, 12, 31, 12);
  final holidays = HolidayCalendar(FederalState.nw);

  setUp(() async {
    store = InMemorySyncStore();
    repo = await SyncedRepository.open(store, dev);
    await repo.write('work_schedules', 'w', {
      'valid_from': '2026-01-01',
      for (final d in ['mon', 'tue', 'wed', 'thu', 'fri']) 'minutes_$d': 480,
    });
  });

  DayExplanation explain(LocalDate d) => explainDay(
    appLedger(store.allRows.values, now).day(d),
    isHoliday: holidays.isHoliday(d),
  );
  Future<void> work(String date, String from, String to, String loc) =>
      repo.write('work_sessions', repo.newId(), {
        'start_utc': '${date}T${from}Z',
        'end_utc': '${date}T${to}Z',
        'location': loc,
      });
  Future<void> trip(String from, String to) => repo.write('trips', 't', {
    'depart_utc': '${from}T05:00:00Z',
    'return_utc': '${to}T20:00:00Z',
  });

  test('§16 a normal workday: worked counts as is', () async {
    await work('2026-11-04', '07:00:00', '13:00:00', 'office');
    final e = explain(LocalDate(2026, 11, 4));
    expect(
      (e.rule, e.effective, e.ruleCredit, e.target, e.delta),
      (null, 360, 360, 480, -120),
    );
    expect(e.targetReason, TargetReason.schedule);
  });

  test('§16 trip weekday: credited = target however long it was', () async {
    await trip('2026-11-04', '2026-11-04');
    await work('2026-11-04', '05:00:00', '16:00:00', 'travel');
    final e = explain(LocalDate(2026, 11, 4));
    expect(e.rule, TripDayType.workday);
    expect(e.ruleCredit, 480);
    expect(e.notCounted, e.effective - 480);
    expect(e.delta, 0);
  });

  test('§16 Saturday is capped, Sunday becomes Sunday hours', () async {
    await trip('2026-11-07', '2026-11-08');
    await work('2026-11-07', '06:00:00', '19:00:00', 'travel'); // 13 h
    await work('2026-11-08', '08:00:00', '12:00:00', 'travel');
    // A service trip (the default): Saturday at most 8 h.
    final sat = explain(LocalDate(2026, 11, 7));
    expect((sat.rule, sat.ruleCredit), (TripDayType.saturday, 480));
    expect(sat.notCounted, sat.effective - 480);
    final sun = explain(LocalDate(2026, 11, 8));
    expect(
      (sun.rule, sun.ruleCredit, sun.sundayHours),
      (TripDayType.sunday, 0, 240),
    );
  });

  test('§16 vacation and holiday: credit and target reasons', () async {
    await setDayType(
      repo,
      LocalDate(2026, 11, 5),
      DayType.vacation,
      zone: HomeTimeZone(),
    );
    final v = explain(LocalDate(2026, 11, 5));
    expect(
      (v.absenceCredit, v.absenceKinds.join(), v.delta),
      (480, '${AbsenceKind.vacation}', 0),
    );
    final xmas = explain(LocalDate(2026, 12, 25));
    expect((xmas.target, xmas.targetReason), (0, TargetReason.holiday));
    expect(explain(LocalDate(2026, 11, 8)).targetReason, TargetReason.dayOff);
  });

  test(
    '§16 §6.1 Heiligabend: half the target; half a day off covers it',
    () async {
      // spec: calculations.md §6.1, §8
      await repo.write('absences', 'v', {
        'date': '2026-12-24',
        'kind': 'vacation',
        'fraction': 0.5,
      });
      final eve = LocalDate(2026, 12, 24);
      final e = explainDay(
        appLedger(store.allRows.values, now).day(eve),
        isHoliday: false,
        isHalfDay: holidays.isHalfDay(eve),
      );
      expect(
        (e.target, e.targetReason, e.absenceCredit, e.delta),
        (240, TargetReason.halfDay, 240, 0),
      );
    },
  );
}
