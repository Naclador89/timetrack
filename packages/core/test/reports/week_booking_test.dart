// booking-transfer.md §2, §3, §7
import 'package:test/test.dart';
import 'package:timetrack_core/timetrack_core.dart';

final berlin = HomeTimeZone();
LocalDate d(String iso) => LocalDate.parse(iso);
DateTime at(String date, String hm) {
  final p = hm.split(':');
  return berlin.instantAt(d(date), int.parse(p[0]), int.parse(p[1]));
}

var _n = 0;
WorkSession work(String date, String from, String to) => WorkSession(
  id: 's${_n++}',
  start: at(date, from),
  end: at(date, to),
  location: WorkLocation.office,
);
ProjectDuration dur(String project, String date, int minutes) =>
    ProjectDuration(
      id: 'p${_n++}',
      projectId: project,
      date: d(date),
      minutes: minutes,
    );

Ledger ledger(LedgerData data, {String now = '2026-11-15'}) => Ledger(
  data: data,
  zone: berlin,
  holidays: HolidayCalendar(FederalState.nw),
  settings: LedgerSettings(balanceStart: d('2026-10-01'), startingBalance: 0),
  nowMinute: epochMinute(at(now, '20:00')),
);

const projects = {
  'a': Project(
    id: 'a',
    name: 'Werk Süd',
    projectNumber: 'P100',
    orderNumber: '7',
  ),
  'b': Project(
    id: 'b',
    name: 'Werk Nord',
    projectNumber: 'P100',
    orderNumber: '7',
  ),
  'c': Project(id: 'c', name: 'Intern', projectNumber: 'P050'),
  'x': Project(id: 'x', name: 'Ohne Nummer'),
};

final monday = d('2026-11-09');

void main() {
  test('§2.4 rounding to half hours, nearest, halves up', () {
    expect([0, 14, 15, 29, 44, 45, 74, 75, 480].map(roundToHalfHours), [
      0,
      0,
      1,
      1,
      1,
      2,
      2,
      3,
      16,
    ]);
  });

  test('§2.3 same project and order number share a row, summed before '
      'rounding; §2.6 sorted by project number', () {
    final l = ledger(
      LedgerData(
        sessions: [work('2026-11-09', '08:00', '18:00')],
        durations: [
          dur('a', '2026-11-09', 10),
          dur('b', '2026-11-09', 10),
          dur('c', '2026-11-09', 120),
          dur('c', '2026-11-15', 60),
        ],
      ),
    );
    final w = buildWeekBooking(l, projects, monday: monday);
    expect(
      w.rows.map((r) => '${r.projectNumber}/${r.orderNumber} ${r.halfHours}'),
      ['P050/ [4, 0, 0, 0, 0, 0, 2]', 'P100/7 [1, 0, 0, 0, 0, 0, 0]'],
    );
    expect(w.rows[1].projectNames, ['Werk Nord', 'Werk Süd']);
    expect(w.fingerprint, 'P050||4,0,0,0,0,0,2;P100|7|1,0,0,0,0,0,0');
  });

  test('§2.2 projects without a number are skipped; §2.5 rows rounding to '
      'nothing are dropped; §3 rounding differences', () {
    final l = ledger(
      LedgerData(
        sessions: [work('2026-11-10', '08:00', '12:00')],
        durations: [
          dur('x', '2026-11-10', 60),
          dur('a', '2026-11-10', 14),
          dur('c', '2026-11-10', 100),
        ],
      ),
    );
    final w = buildWeekBooking(l, projects, monday: monday);
    expect(w.rows.map((r) => r.projectNumber), ['P050']);
    expect(w.skipped.map((s) => (s.name, s.minutes)), [('Ohne Nummer', 60)]);
    expect(
      w.roundingDifferences.map(
        (r) => (r.date, r.exactMinutes, r.roundedMinutes),
      ),
      [(d('2026-11-10'), 114, 90)],
    );
    expect((w.exactMinutes, w.roundedMinutes), (114, 90));
    expect(w.unassignedByDay, {d('2026-11-10'): 240 - 174});
  });

  test('§3 a running project timer in the week is reported', () {
    final l = ledger(
      LedgerData(
        sessions: [
          WorkSession(
            id: 's',
            start: at('2026-11-11', '08:00'),
            location: WorkLocation.office,
          ),
        ],
        entries: [
          ProjectEntry(
            id: 'e',
            projectId: 'c',
            start: at('2026-11-11', '08:00'),
          ),
        ],
      ),
      now: '2026-11-11',
    );
    final w = buildWeekBooking(l, projects, monday: monday);
    expect(w.runningTimer, isTrue);
    expect(w.rows.single.halfHours[2], 24);
    expect(
      buildWeekBooking(l, projects, monday: d('2026-11-02')).runningTimer,
      isFalse,
    );
  });

  test('§2 ISO week and year, also across the turn of the year; §7 key', () {
    WeekBooking week(String m) =>
        buildWeekBooking(ledger(LedgerData()), projects, monday: d(m));
    expect(
      (week('2026-11-09').isoWeek, week('2026-11-09').isoYear),
      (46, 2026),
    );
    expect(week('2026-11-09').weekKey, '2026-W46');
    expect(
      (week('2020-12-28').isoWeek, week('2020-12-28').isoYear),
      (53, 2020),
    );
    expect((week('2024-12-30').isoWeek, week('2024-12-30').isoYear), (1, 2025));
    expect(week('2024-12-30').weekKey, '2025-W01');
    expect(week('2026-11-09').rows, isEmpty);
  });
}
