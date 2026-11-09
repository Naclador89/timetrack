// spec: calculations.md §22
import 'package:test/test.dart';
import 'package:timetrack_core/timetrack_core.dart';

const dev = 'aaaaaaaaaaaaaaaa';

void main() {
  late InMemorySyncStore store;
  late SyncedRepository repo;

  setUp(() async {
    store = InMemorySyncStore();
    repo = await SyncedRepository.open(store, dev);
    await saveSetting(repo, SettingKeys.balanceStartDate, '2026-10-05');
  });

  // [hours] of work from 06:00 local (UTC+1 in November, +2 in October).
  Future<void> work(String date, int hours) {
    final offset = date.compareTo('2026-10-25') < 0 ? 2 : 1;
    final start = DateTime.parse('${date}T06:00:00Z')
        .subtract(Duration(hours: offset));
    return repo.write('work_sessions', 's-$date', {
      'start_utc': start.toIso8601String(),
      'end_utc': start.add(Duration(hours: hours)).toIso8601String(),
      'location': 'office',
    });
  }

  Future<void> week(String monday, List<int> hours) async {
    final m = LocalDate.parse(monday);
    for (final (i, h) in hours.indexed) {
      if (h > 0) await work('${m.addDays(i)}', h);
    }
  }

  Ledger ledger() =>
      appLedger(store.allRows.values, DateTime.utc(2026, 11, 10, 12));
  List<(LocalDate, ReviewKind, int)> items() {
    final l = ledger();
    return [
      for (final i in reviewItems(
        l,
        from: LocalDate(2026, 10, 1),
        to: LocalDate(2026, 11, 30),
        weekLimits: AppSettings.fromRows(store.allRows.values).weekLimits,
      ))
        if (NoticeCategory.of(i) == NoticeCategory.weekLimit)
          (i.date, i.kind, i.minutes),
    ];
  }

  test('a week above 60 h is a notice on its Sunday', () async {
    // Week of 26 Oct: 6 × 11 h = 66 h.
    await week('2026-10-26', [11, 11, 11, 11, 11, 11, 0]);
    expect(weekWorked(ledger(), LocalDate(2026, 10, 26)), 66 * 60);
    expect(
      items(),
      contains((LocalDate(2026, 11, 1), ReviewKind.weekOverMax, 66 * 60)),
    );
  });

  test('the rolling average counts weeks from the balance start', () async {
    // Weeks of 5 Oct and 12 Oct: 50 h each, then 46 h.
    await week('2026-10-05', [10, 10, 10, 10, 10, 0, 0]);
    await week('2026-10-12', [10, 10, 10, 10, 10, 0, 0]);
    await week('2026-10-19', [10, 10, 10, 8, 8, 0, 0]);
    final l = ledger();
    const limits = WeekLimits();
    expect(weekAverage(l, LocalDate(2026, 10, 5), limits), 50 * 60);
    expect(weekAverage(l, LocalDate(2026, 10, 19), limits), 48 * 60 + 40);
    expect(weekAverage(l, LocalDate(2026, 9, 28), limits), isNull);
    // Only the first week above 48 h on average is a notice.
    expect(items().where((i) => i.$2 == ReviewKind.weekAverageOver), [
      (LocalDate(2026, 10, 11), ReviewKind.weekAverageOver, 50 * 60),
    ]);
  });

  test('the running week is not checked; 0 switches a limit off', () async {
    // This week (9 Nov) has 33 h on Monday alone, but isn't finished.
    await week('2026-11-09', [33, 0, 0, 0, 0, 0, 0]);
    expect(items(), isEmpty);
    await week('2026-10-26', [11, 11, 11, 11, 11, 11, 0]);
    await saveSetting(repo, SettingKeys.weekMax, 0);
    await saveSetting(repo, SettingKeys.weekAverage, 0);
    expect(items(), isEmpty);
  });
}
