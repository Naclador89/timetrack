// spec: calculations.md §21
import 'package:test/test.dart';
import 'package:timetrack_core/timetrack_core.dart';

const dev = 'aaaaaaaaaaaaaaaa';

void main() {
  late InMemorySyncStore store;
  late SyncedRepository repo;

  setUp(() async {
    store = InMemorySyncStore();
    repo = await SyncedRepository.open(store, dev);
    await repo.write('work_schedules', 'w', {
      'valid_from': '2026-01-01',
      for (final d in ['mon', 'tue', 'wed', 'thu', 'fri']) 'minutes_$d': 480,
    });
    await saveSetting(repo, SettingKeys.federalState, 'NW');
    await saveSetting(repo, SettingKeys.balanceStartDate, '2026-01-01');
  });

  // Times are UTC; Berlin is UTC+1 in November and December.
  Future<void> work(String id, String start, String end) => repo.write(
    'work_sessions',
    id,
    {'start_utc': '${start}Z', 'end_utc': '${end}Z', 'location': 'office'},
  );
  Ledger ledger() =>
      appLedger(store.allRows.values, DateTime.utc(2027, 1, 10, 12));

  group('§21.2 night work', () {
    test('a night of 3 h is split at midnight', () async {
      // Tue 21:00 – Wed 02:00 local.
      await work('s', '2026-11-03T20:00:00', '2026-11-04T01:00:00');
      final l = ledger();
      expect(l.day(LocalDate(2026, 11, 3)).nightHours, 60);
      expect(l.day(LocalDate(2026, 11, 4)).nightHours, 120);
    });

    test('less than 2 h in the night: no night hours', () async {
      // Tue 22:00 – Wed 00:30 local: 90 min in the night.
      await work('s', '2026-11-03T21:00:00', '2026-11-03T23:30:00');
      final l = ledger();
      expect(l.day(LocalDate(2026, 11, 3)).nightHours, 0);
      expect(l.day(LocalDate(2026, 11, 4)).nightHours, 0);
    });

    test('an early start: 04:00–06:00 is the end of a night', () async {
      await work('s', '2026-11-04T03:00:00', '2026-11-04T11:00:00');
      expect(ledger().day(LocalDate(2026, 11, 4)).nightHours, 120);
    });

    test('breaks in the night don\'t count', () async {
      await work('s', '2026-11-04T03:00:00', '2026-11-04T11:00:00');
      await repo.write('breaks', 'b', {
        'start_utc': '2026-11-04T04:00:00Z',
        'end_utc': '2026-11-04T04:30:00Z',
      });
      expect(ledger().day(LocalDate(2026, 11, 4)).nightHours, 0);
    });

    test(
      'count: credited as worked; exclude: left out of the account',
      () async {
        // Wed 04:00–14:00 local: 10 h, 2 h of them at night.
        await work('s', '2026-11-04T03:00:00', '2026-11-04T13:00:00');
        final date = LocalDate(2026, 11, 4);
        expect(ledger().day(date).credited, 600);
        await saveSetting(repo, SettingKeys.nightWorkCredit, 'exclude');
        final day = ledger().day(date);
        expect(day.nightHours, 120);
        expect(day.credited, 480);
        final e = explainDay(
          day,
          isHoliday: false,
          night: NightWorkCredit.exclude,
        );
        expect(e.nightExcluded, isTrue);
        expect(e.notCounted, 0, reason: 'the night is no rule');
      },
    );

    test('exclude: a service-trip workday still gets the target', () async {
      await saveSetting(repo, SettingKeys.nightWorkCredit, 'exclude');
      await repo.write('trips', 't', {
        'depart_utc': '2026-11-04T03:00:00Z',
        'return_utc': '2026-11-04T13:00:00Z',
      });
      await work('s', '2026-11-04T03:00:00', '2026-11-04T13:00:00');
      final day = ledger().day(LocalDate(2026, 11, 4));
      expect(day.nightHours, 120);
      expect(day.credited, 480);
    });

    test('the timesheet sums them', () async {
      await work('s', '2026-11-03T20:00:00', '2026-11-04T01:00:00');
      expect(buildTimesheet(ledger(), 2026, 11).nightHours, 180);
    });
  });

  group('§21.1 special holidays', () {
    test('Sunday hours of a special day are reported apart', () async {
      // Fri 25 Dec 2026, 08:00–12:00 local.
      await work('s', '2026-12-25T07:00:00', '2026-12-25T11:00:00');
      final date = LocalDate(2026, 12, 25);
      expect(ledger().day(date).sundayHours, 240);
      expect(ledger().day(date).specialHolidayHours, 0);
      await saveSetting(repo, SettingKeys.specialDays, 'christmas_day,may_day');
      final day = ledger().day(date);
      expect(day.sundayHours, 0);
      expect(day.specialHolidayHours, 240);
      expect(day.credited, 0);
      final sheet = buildTimesheet(ledger(), 2026, 12);
      expect(sheet.specialHolidayHours, 240);
      expect(sheet.sundayHours, 0);
    });

    test('dates of the movable days; unknown codes are skipped', () {
      expect(SpecialDay.easterSunday.inYear(2027), LocalDate(2027, 3, 28));
      expect(SpecialDay.whitSunday.inYear(2027), LocalDate(2027, 5, 16));
      expect(SpecialDay.parseList('may_day, nonsense,whit_sunday'), {
        SpecialDay.mayDay,
        SpecialDay.whitSunday,
      });
      expect(SpecialDay.parseList(null), isEmpty);
    });
  });
}
