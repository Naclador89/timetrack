// spec: calculations.md §18
import 'package:test/test.dart';
import 'package:timetrack_core/timetrack_core.dart';

const dev = 'aaaaaaaaaaaaaaaa';

void main() {
  late InMemorySyncStore store;
  late SyncedRepository repo;
  final wed = LocalDate(2026, 11, 4);

  setUp(() async {
    store = InMemorySyncStore();
    repo = await SyncedRepository.open(store, dev);
  });

  Future<void> schedule(int minutes) => repo.write('work_schedules', 'w', {
    'valid_from': '2026-01-01',
    for (final d in ['mon', 'tue', 'wed', 'thu', 'fri']) 'minutes_$d': minutes,
  });
  Future<void> work(String from, String? to, {String loc = 'office'}) =>
      repo.write('work_sessions', repo.newId(), {
        'start_utc': '2026-11-04T${from}Z',
        'end_utc': to == null ? null : '2026-11-04T${to}Z',
        'location': loc,
      });
  DateTime t(String hm) => DateTime.parse('2026-11-04T$hm:00Z');
  DayForecast forecast(String now, {int runningBreak = 0}) => dayForecast(
    appLedger(store.allRows.values, t(now)).day(wed),
    now: t(now),
    runningBreak: runningBreak,
  );

  test('§18 3 h worked of 8 h, no break yet → +5 h + 30 min break', () async {
    await schedule(480);
    await work('07:00:00', null);
    final f = forecast('10:00');
    expect(f.targetAt, t('15:30'));
    expect(f.breakIncluded, 30);
    expect(f.limitAt, t('17:45'), reason: '+7 h work, +45 min break');
  });

  test('§18 a break already taken is not added again', () async {
    await schedule(480);
    await work('07:00:00', '09:00:00');
    await work('09:30:00', null);
    final f = forecast('10:30');
    expect(f.targetAt, t('15:30'));
    expect(f.breakIncluded, 0);
    expect(f.limitAt, t('17:45'), reason: '15 more minutes for 45');
  });

  test('§18 a 9:30 h target needs 45 minutes of break', () async {
    await schedule(570);
    await work('07:00:00', null);
    final f = forecast('10:00');
    expect(f.targetAt, t('17:15'));
    expect(f.breakIncluded, 45);
  });

  test('§18 a running break of 15 min or more counts', () async {
    await schedule(480);
    await work('07:00:00', null);
    await repo.write('breaks', 'b', {
      'start_utc': '2026-11-04T10:00:00Z',
      'end_utc': null,
    });
    final f = forecast('10:20', runningBreak: 20);
    expect(f.targetAt, t('15:30'), reason: '5 h work + 10 min more break');
    expect(f.breakIncluded, 10);
  });

  test('§18 target reached → only the 10-hour limit', () async {
    await schedule(480);
    await work('05:00:00', null);
    final f = forecast('14:00');
    expect(f.targetAt, isNull);
    expect(f.limitAt, t('15:45'));
  });

  test('§18 10 hours reached → no limit time either', () async {
    await schedule(480);
    await work('04:00:00', null);
    expect(forecast('15:00').limitAt, isNull);
  });

  test('§18 trip day: the target is credited anyway', () async {
    await schedule(480);
    await repo.write('trips', 'trip', {
      'depart_utc': '2026-11-04T06:00:00Z',
      'return_utc': null,
    });
    await work('06:00:00', null, loc: 'travel');
    final f = forecast('08:00');
    expect(f.targetAt, isNull);
    expect(f.limitAt, isNotNull);
  });

  test('§18 half a day of vacation leaves half the target', () async {
    await schedule(480);
    await repo.write('absences', 'a', {
      'date': '2026-11-04',
      'kind': 'vacation',
      'fraction': 0.5,
    });
    await work('07:00:00', null);
    expect(forecast('09:00').targetAt, t('11:00'));
  });

  test('§18 no target (weekend) → no target time', () async {
    await schedule(480);
    await repo.write('work_sessions', 's', {
      'start_utc': '2026-11-07T08:00:00Z',
      'end_utc': null,
      'location': 'home',
    });
    final now = DateTime.utc(2026, 11, 7, 10);
    final f = dayForecast(
      appLedger(store.allRows.values, now).day(LocalDate(2026, 11, 7)),
      now: now,
    );
    expect(f.targetAt, isNull);
  });
}
