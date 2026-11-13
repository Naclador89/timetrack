// spec: calculations.md §10.1
import 'package:test/test.dart';
import 'package:timetrack_core/timetrack_core.dart';

const dev = 'aaaaaaaaaaaaaaaa';

void main() {
  late InMemorySyncStore store;
  late SyncedRepository repo;

  setUp(() async {
    store = InMemorySyncStore();
    repo = await SyncedRepository.open(store, dev);
    await repo.write('settings', SettingKeys.federalState, {'value': 'nw'});
  });

  Future<void> schedule(List<String> days) => repo.write(
    'work_schedules',
    'w',
    {'valid_from': '2020-01-01', for (final d in days) 'minutes_$d': 480},
  );
  List<BridgeSuggestion> bridges(int year, {LocalDate? today}) => bridgeDays(
    appLedger(store.allRows.values, DateTime.utc(year - 1, 12, 1)),
    year,
    today: today ?? LocalDate(year - 1, 12, 1),
  );
  String show(BridgeSuggestion s) =>
      '${s.vacationDays.join('+')} → ${s.freeFrom}…${s.freeTo} (${s.freeDays})';
  const weekdays = ['mon', 'tue', 'wed', 'thu', 'fri'];

  test('§10.1 NRW 2026: Thursday holidays make Friday bridges', () async {
    await schedule(weekdays);
    final all = bridges(2026).map(show).toList();
    // New Year (Thu), Ascension (Thu 14 May), Corpus Christi (Thu 4 June).
    // Mon–Wed before them join the weekend too, at a worse ratio.
    expect(all, [
      '2026-01-02 → 2026-01-01…2026-01-04 (4)',
      '2026-05-15 → 2026-05-14…2026-05-17 (4)',
      '2026-06-05 → 2026-06-04…2026-06-07 (4)',
      '2026-05-11+2026-05-12+2026-05-13 → 2026-05-09…2026-05-14 (6)',
      '2026-06-01+2026-06-02+2026-06-03 → 2026-05-30…2026-06-04 (6)',
    ]);
  });

  test('§10.1 §6.1 Heiligabend and Silvester use half a day', () async {
    await schedule(weekdays);
    final all = bridges(2029);
    // Mon 24 Dec 2029 joins the weekend and Christmas: 5 days for ½ day.
    final eve = all.singleWhere(
      (s) => s.vacationDays.first == LocalDate(2029, 12, 24),
    );
    expect((eve.daysUsed, eve.freeDays), (0.5, 5));
    expect(all.first, eve);
  });

  test('§10.1 NRW 2028: a Tuesday and a Wednesday holiday', () async {
    await schedule(weekdays);
    final all = bridges(2028).map(show).toList();
    // 3 Oct is a Tuesday: take Monday. 1 Nov is a Wednesday: two days
    // on either side make five.
    expect(all, contains('2028-10-02 → 2028-09-30…2028-10-03 (4)'));
    expect(
      all,
      containsAll([
        '2028-10-30+2028-10-31 → 2028-10-28…2028-11-01 (5)',
        '2028-11-02+2028-11-03 → 2028-11-01…2028-11-05 (5)',
      ]),
    );
    expect(
      all.indexOf('2028-10-02 → 2028-09-30…2028-10-03 (4)'),
      lessThan(
        all.indexOf('2028-10-30+2028-10-31 → 2028-10-28…2028-11-01 (5)'),
      ),
      reason: '4 per day beats 2.5 per day',
    );
  });

  test('§10.1 free days without a holiday are no bridge', () async {
    // Part time Mon, Wed, Fri: Wednesday sits between two free days.
    await schedule(['mon', 'wed', 'fri']);
    final all = bridges(2026);
    expect(
      all.where((s) => s.vacationDays.first == LocalDate(2026, 3, 11)),
      isEmpty,
    );
  });

  test('§10.1 booked or past days are not suggested', () async {
    await schedule(weekdays);
    await repo.write('absences', 'a', {
      'date': '2026-05-15',
      'kind': 'vacation',
      'fraction': 1,
    });
    final all = bridges(2026, today: LocalDate(2026, 3, 1)).map(show);
    // 15 May is booked: Mon–Wed now join 9 free days.
    expect(all, [
      '2026-06-05 → 2026-06-04…2026-06-07 (4)',
      '2026-05-11+2026-05-12+2026-05-13 → 2026-05-09…2026-05-17 (9)',
      '2026-06-01+2026-06-02+2026-06-03 → 2026-05-30…2026-06-04 (6)',
    ]);
    final later = bridges(2026, today: LocalDate(2026, 5, 20)).map(show);
    expect(later, ['2026-06-05 → 2026-06-04…2026-06-07 (4)', isA<String>()]);
  });
}
