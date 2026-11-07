// concept §5 (reports); calculations.md §3, §8, §10, §11.5, §14
import 'package:test/test.dart';
import 'package:timetrack_core/timetrack_core.dart';

final berlin = HomeTimeZone();
LocalDate d(String iso) => LocalDate.parse(iso);
DateTime at(String date, String hm) {
  final p = hm.split(':');
  return berlin.instantAt(d(date), int.parse(p[0]), int.parse(p[1]));
}

var _n = 0;
WorkSession work(
  String date,
  String from,
  String to, [
  WorkLocation l = WorkLocation.office,
]) => WorkSession(
  id: 's${_n++}',
  start: at(date, from),
  end: at(date, to),
  location: l,
);
ProjectEntry entry(String project, String date, String from, String to) =>
    ProjectEntry(
      id: 'e${_n++}',
      projectId: project,
      start: at(date, from),
      end: at(date, to),
    );

Ledger ledger(LedgerData data) => Ledger(
  data: data,
  zone: berlin,
  holidays: HolidayCalendar(FederalState.nw),
  settings: LedgerSettings(balanceStart: d('2026-10-01'), startingBalance: 60),
  nowMinute: epochMinute(at('2026-11-04', '20:00')),
);

final schedule = WorkSchedule(
  id: 'w',
  validFrom: d('2026-01-01'),
  weekdayMinutes: [480, 480, 480, 480, 480, 0, 0],
);

void main() {
  test(
    'timesheet: rows up to today, start/end/breaks, totals and balances',
    () {
      final l = ledger(
        LedgerData(
          schedules: [schedule],
          sessions: [
            work('2026-11-02', '08:00', '12:00', WorkLocation.home),
            work('2026-11-02', '12:30', '17:00', WorkLocation.home),
            work('2026-11-03', '08:00', '16:30'),
          ],
          breaks: [
            WorkBreak(
              id: 'b',
              start: at('2026-11-03', '12:00'),
              end: at('2026-11-03', '12:30'),
            ),
          ],
          absences: [
            Absence(id: 'v', date: d('2026-11-04'), kind: AbsenceKind.vacation),
          ],
        ),
      );
      final t = buildTimesheet(l, 2026, 11);
      expect(t.rows.map((r) => r.day.date), [
        d('2026-11-01'),
        d('2026-11-02'),
        d('2026-11-03'),
        d('2026-11-04'),
      ]);
      final mon = t.rows[1];
      expect(
        (mon.firstStart, mon.lastEnd, mon.breakMinutes),
        (
          epochMinute(at('2026-11-02', '08:00')),
          epochMinute(at('2026-11-02', '17:00')),
          30,
        ),
      );
      expect(mon.locations, [WorkLocation.home]);
      expect(t.rows.first.holiday, 'Allerheiligen');
      expect((t.worked, t.target, t.delta), (510 + 480, 3 * 480, 30));
      // October had a target of 22 workdays × 8 h without work: −176 h, plus the 1 h start.
      expect(t.balanceBefore, 60 - 22 * 480);
      expect(t.balanceAfter, t.balanceBefore + t.delta);
      expect((t.homeOfficeDays, t.workedDays, t.vacationDays), (1, 2, 1.0));
    },
  );

  test(
    'order report: minutes per day and order number, merged across projects',
    () {
      final projects = {
        'a': const Project(
          id: 'a',
          name: 'Werk Süd',
          projectNumber: 'P-1',
          orderNumber: 'A-1',
        ),
        'b': const Project(
          id: 'b',
          name: 'Werk Süd Nachtrag',
          projectNumber: 'P-1b',
          orderNumber: 'A-1',
        ),
        'c': const Project(id: 'c', name: 'Intern'),
      };
      final l = ledger(
        LedgerData(
          schedules: [schedule],
          sessions: [work('2026-11-03', '08:00', '17:00')],
          entries: [
            entry('a', '2026-11-03', '08:00', '10:00'),
            entry('b', '2026-11-03', '10:00', '11:00'),
            entry('c', '2026-11-03', '11:00', '12:00'),
          ],
        ),
      );
      final r = buildOrderReport(
        l,
        projects,
        from: d('2026-11-02'),
        to: d('2026-11-03'),
      );
      expect(r.map((b) => (b.date, b.orderNumber, b.minutes)), [
        (d('2026-11-03'), '', 60),
        (d('2026-11-03'), 'A-1', 180),
      ]);
    },
  );

  test('CSV: Excel flavour with ; and BOM, quoting when needed', () {
    final csv = toCsv([
      ['Datum', 'Notiz'],
      ['2026-11-03', 'Kunde; "Bosch"'],
    ]);
    expect(csv, '﻿Datum;Notiz\r\n2026-11-03;"Kunde; ""Bosch"""\r\n');
    expect(
      toCsv([
        ['a', 'b,c'],
      ], excel: false),
      'a,"b,c"\r\n',
    );
  });
}
