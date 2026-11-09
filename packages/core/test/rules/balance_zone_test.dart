// spec: calculations.md §20, §10.2
import 'package:test/test.dart';
import 'package:timetrack_core/timetrack_core.dart';

const dev = 'aaaaaaaaaaaaaaaa';

void main() {
  late InMemorySyncStore store;
  late SyncedRepository repo;

  setUp(() async {
    store = InMemorySyncStore();
    repo = await SyncedRepository.open(store, dev);
  });

  Future<void> setting(String key, Object value) =>
      saveSetting(repo, key, value);
  Future<void> schedule(String from, List<int> minutes) =>
      repo.write('work_schedules', repo.newId(), {
        'valid_from': from,
        for (final (i, d) in [
          'mon',
          'tue',
          'wed',
          'thu',
          'fri',
          'sat',
          'sun',
        ].indexed)
          'minutes_$d': minutes[i],
      });
  Ledger ledger(DateTime now) => appLedger(store.allRows.values, now);

  group('§20.1 zone', () {
    const limits = BalanceLimits(
      yellowPlus: 300 * 60,
      redPlus: 350 * 60,
      maxPlus: 400 * 60,
      yellowMinus: 100 * 60,
      redMinus: 150 * 60,
      maxMinus: 200 * 60,
    );

    test('green inside, yellow/red/over limit beyond each limit', () {
      expect(balanceZone(300 * 60, limits), BalanceZone.green);
      expect(balanceZone(-100 * 60, limits), BalanceZone.green);
      expect(balanceZone(300 * 60 + 1, limits), BalanceZone.yellow);
      expect(balanceZone(-100 * 60 - 1, limits), BalanceZone.yellow);
      expect(balanceZone(351 * 60, limits), BalanceZone.red);
      expect(balanceZone(-151 * 60, limits), BalanceZone.red);
      expect(balanceZone(401 * 60, limits), BalanceZone.overLimit);
      expect(balanceZone(-201 * 60, limits), BalanceZone.overLimit);
    });

    test('no limit set: no zone; one side only', () {
      expect(balanceZone(1000 * 60, const BalanceLimits()), isNull);
      const plusOnly = BalanceLimits(yellowPlus: 60);
      expect(balanceZone(-100000, plusOnly), BalanceZone.green);
      expect(balanceZone(61, plusOnly), BalanceZone.yellow);
    });

    test('limits are read from the settings; 0 or missing = none', () async {
      await setting(SettingKeys.balanceYellowPlus, 18000);
      await setting(SettingKeys.balanceRedMinus, 0);
      final s = AppSettings.fromRows(store.allRows.values);
      expect(s.balanceLimits.yellowPlus, 18000);
      expect(s.balanceLimits.redMinus, isNull);
      expect(s.balanceCarryDeadlineMonths, 0);
      expect(s.vacationCarryDeadlineMonths, 3);
    });

    test('a notice on the first finished day in a worse zone', () async {
      await schedule('2026-11-02', [480, 480, 480, 480, 480, 0, 0]);
      await setting(SettingKeys.balanceStartDate, '2026-11-02');
      await setting(SettingKeys.startingBalance, -95 * 60);
      await setting(SettingKeys.balanceYellowMinus, 100 * 60);
      await setting(SettingKeys.balanceRedMinus, 110 * 60);
      // Nothing worked: −103 h on Mon 2 Nov, −111 h on Tue; today (Mon 9
      // Nov) is left out.
      final items = reviewItems(
        ledger(DateTime.utc(2026, 11, 9, 12)),
        from: LocalDate(2026, 11, 1),
        to: LocalDate(2026, 11, 30),
        balanceLimits: AppSettings.fromRows(store.allRows.values).balanceLimits,
      ).where((i) => i.kind == ReviewKind.balanceZone);
      expect(items.map((i) => (i.date, i.refId, i.minutes)), [
        (LocalDate(2026, 11, 2), 'yellow', -103 * 60),
        (LocalDate(2026, 11, 3), 'red', -111 * 60),
      ]);
      expect(NoticeCategory.of(items.first).wireName, 'balance_zone');
    });
  });

  group('§20.2 year-end carry-over', () {
    test('plus: open is the carry still above zero', () async {
      // Only Mondays have a target, nothing is worked.
      await schedule('2027-01-01', [480, 0, 0, 0, 0, 0, 0]);
      await setting(SettingKeys.balanceStartDate, '2027-01-01');
      await setting(SettingKeys.startingBalance, 60 * 60);
      await setting(SettingKeys.balanceCarryDeadline, 3);
      final l = ledger(DateTime.utc(2027, 2, 10, 12));
      final c = balanceCarryOver(l, months: 3)!;
      // Six Mondays by 9 Feb: 60 h − 48 h.
      expect(c.carry, 60 * 60);
      expect(c.open, 12 * 60);
      expect(c.deadline, LocalDate(2027, 3, 31));
      expect(c.expired, isFalse);
      expect(balanceCarryOver(l, months: 0), isNull);
    });

    test('plus: reduced to zero → nothing open', () async {
      await schedule('2027-01-01', [480, 0, 0, 0, 0, 0, 0]);
      await setting(SettingKeys.balanceStartDate, '2027-01-01');
      await setting(SettingKeys.startingBalance, 40 * 60);
      expect(
        balanceCarryOver(ledger(DateTime.utc(2027, 2, 10, 12)), months: 3),
        isNull,
      );
    });

    test('minus: worked off in part; after the deadline expired', () async {
      await setting(SettingKeys.balanceStartDate, '2026-12-01');
      await setting(SettingKeys.startingBalance, -20 * 60);
      // A Saturday in January: 5 h credited (no target, no schedule).
      await repo.write('work_sessions', 's', {
        'start_utc': '2027-01-09T08:00:00Z',
        'end_utc': '2027-01-09T13:00:00Z',
        'location': 'office',
      });
      final jan = balanceCarryOver(
        ledger(DateTime.utc(2027, 1, 20, 12)),
        months: 3,
      )!;
      expect(jan.carry, -20 * 60);
      expect(jan.open, -15 * 60);
      final apr = balanceCarryOver(
        ledger(DateTime.utc(2027, 4, 2, 12)),
        months: 3,
      )!;
      expect(apr.expired, isTrue);
    });

    test('balance starting after 1 January: no carry-over', () async {
      await setting(SettingKeys.balanceStartDate, '2027-01-04');
      await setting(SettingKeys.startingBalance, 10 * 60);
      expect(
        balanceCarryOver(ledger(DateTime.utc(2027, 2, 10, 12)), months: 3),
        isNull,
      );
    });
  });

  group('§10.2 vacation carry-over deadline', () {
    final targets = TargetCalendar(
      schedules: [
        WorkSchedule(
          id: 'w',
          validFrom: LocalDate(2026, 1, 1),
          weekdayMinutes: const [480, 480, 480, 480, 480, 0, 0],
          annualVacationDays: 30,
        ),
      ],
      holidays: HolidayCalendar(FederalState.nw),
    );
    Absence vacation(LocalDate date, [double f = 1]) => Absence(
      id: '$date',
      date: date,
      kind: AbsenceKind.vacation,
      fraction: f,
    );

    test('taken and planned workdays up to the deadline count', () {
      final left = vacationCarryLeft(
        carryOver: 5,
        months: 3,
        targets: targets,
        absences: [
          vacation(LocalDate(2027, 1, 4)), // Monday, taken
          vacation(LocalDate(2027, 1, 9)), // Saturday: no workday
          vacation(LocalDate(2027, 3, 5), 0.5), // planned
          vacation(LocalDate(2027, 4, 6)), // after the deadline
        ],
        today: LocalDate(2027, 2, 1),
      )!;
      expect(left.open, 3.5);
      expect(left.deadline, LocalDate(2027, 3, 31));
    });

    test('nothing after the deadline, without carry or all planned', () {
      Object? left(double carry, LocalDate today, [int months = 3]) =>
          vacationCarryLeft(
            carryOver: carry,
            months: months,
            targets: targets,
            absences: [vacation(LocalDate(2027, 1, 4))],
            today: today,
          );
      expect(left(2, LocalDate(2027, 4, 1)), isNull);
      expect(left(0, LocalDate(2027, 1, 2)), isNull);
      expect(left(1, LocalDate(2027, 1, 2)), isNull);
      expect(left(2, LocalDate(2027, 1, 2), 0), isNull);
    });
  });
}
