// spec: calculations.md §23
import 'package:test/test.dart';
import 'package:timetrack_core/timetrack_core.dart';

final berlin = HomeTimeZone();
LocalDate d(String iso) => LocalDate.parse(iso);

DateTime at(LocalDate date, String hhmm) {
  final p = hhmm.split(':');
  return instantOfEpochMinute(
    berlin.daySpan(date).start + int.parse(p[0]) * 60 + int.parse(p[1]),
  );
}

var _ids = 0;
WorkSession work(String date, String from, String to) => WorkSession(
  id: 's${_ids++}',
  start: at(d(date), from),
  end: at(d(date), to),
  location: WorkLocation.office,
);

/// 8 h with a 30 min break in between.
List<WorkSession> goodDay(String date, {String end = '16:30'}) => [
  work(date, '08:00', '12:00'),
  work(date, '12:30', end),
];

final schedule = WorkSchedule(
  id: 'full',
  validFrom: d('2026-01-01'),
  weekdayMinutes: [480, 480, 480, 480, 480, 0, 0],
  annualVacationDays: 30,
);

/// Patterns of November 2026 with "today" Monday 30 Nov, 23:00.
Map<PatternKind, List<LocalDate>> patterns(List<WorkSession> sessions) {
  final ledger = Ledger(
    data: LedgerData(schedules: [schedule], sessions: sessions),
    zone: berlin,
    holidays: HolidayCalendar(FederalState.nw),
    settings: LedgerSettings(balanceStart: d('2026-01-01')),
    nowMinute: epochMinute(at(d('2026-11-30'), '23:00')),
  );
  return {
    for (final p in monthPatterns(ledger, d('2026-11-01'))) p.kind: p.days,
  };
}

void main() {
  test('§23 missing break: from 2 days', () {
    expect(patterns([work('2026-11-02', '08:00', '16:00')]), isEmpty);
    final p = patterns([
      work('2026-11-02', '08:00', '16:00'),
      work('2026-11-03', '08:00', '16:00'),
    ]);
    expect(p[PatternKind.missingBreak], [d('2026-11-02'), d('2026-11-03')]);
  });

  test('§23 long days: over 10 h (ArbZG §3) on a single day', () {
    final p = patterns([
      work('2026-11-04', '07:00', '12:00'),
      work('2026-11-04', '12:45', '18:45'),
    ]);
    expect(p.keys, [PatternKind.longDays]);
  });

  test('§23 short rest: under 11 h before the day', () {
    final p = patterns([
      ...goodDay('2026-11-05', end: '22:00'),
      ...goodDay('2026-11-06'),
    ]);
    expect(p[PatternKind.shortRest], [d('2026-11-06')]);
    expect(p[PatternKind.lateFinish], isNull, reason: 'only one late day');
  });

  test('§23 Sunday work', () {
    final p = patterns(goodDay('2026-11-08'));
    expect(p[PatternKind.sundayWork], [d('2026-11-08')]);
  });

  test('§23 late finish: after 20:00 on 3 days', () {
    List<WorkSession> late(String date) => [
      work(date, '11:00', '15:00'),
      work(date, '15:30', '20:30'),
    ];
    expect(
      patterns([...late('2026-11-09'), ...late('2026-11-10')]),
      isNot(contains(PatternKind.lateFinish)),
    );
    final p = patterns([
      ...late('2026-11-09'),
      ...late('2026-11-10'),
      ...late('2026-11-11'),
    ]);
    expect(p[PatternKind.lateFinish], hasLength(3));
  });

  test('§23 all breaks kept: 10 workdays without a break finding', () {
    const days = [
      '2026-11-02',
      '2026-11-03',
      '2026-11-04',
      '2026-11-05',
      '2026-11-06',
      '2026-11-09',
      '2026-11-10',
      '2026-11-11',
      '2026-11-12',
      '2026-11-13',
    ];
    expect(
      patterns([for (final x in days.skip(1)) ...goodDay(x)]),
      isEmpty,
      reason: '9 days are too few',
    );
    final p = patterns([for (final x in days) ...goodDay(x)]);
    expect(p.keys, [PatternKind.allBreaksKept]);
  });
}
