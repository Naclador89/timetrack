// spec: calculations.md §10.4
import 'package:test/test.dart';
import 'package:timetrack_core/timetrack_core.dart';

LocalDate d(String iso) => LocalDate.parse(iso);

var _ids = 0;
Absence absence(String date, AbsenceKind kind, [double fraction = 1]) =>
    Absence(id: 'a${_ids++}', date: d(date), kind: kind, fraction: fraction);

void main() {
  final schedule = WorkSchedule(
    id: 'full',
    validFrom: d('2026-01-01'),
    weekdayMinutes: [480, 480, 480, 480, 480, 0, 0],
    annualVacationDays: 30,
  );
  TargetCalendar targets(List<Absence> absences) => TargetCalendar(
    schedules: [schedule],
    holidays: HolidayCalendar(FederalState.nw),
    absences: absences,
  );
  List<(LocalDate, LocalDate, double)> blocks(List<Absence> absences) => [
    for (final b in absenceBlocks(absences, targets(absences)))
      (b.start, b.end, b.days),
  ];

  test('§10.4 a vacation over a weekend is one block of its workdays', () {
    const v = AbsenceKind.vacation;
    expect(
      blocks([
        // Thu–Fri, then Mon–Tue: the weekend joins them.
        absence('2026-11-12', v),
        absence('2026-11-13', v),
        absence('2026-11-16', v),
        absence('2026-11-17', v),
      ]),
      [(d('2026-11-12'), d('2026-11-17'), 4.0)],
    );
  });

  test('§10.4 a workday, another kind or a half day ends the block', () {
    const v = AbsenceKind.vacation;
    expect(
      blocks([
        absence('2026-11-02', v),
        // Tuesday worked.
        absence('2026-11-04', v),
        absence('2026-11-05', AbsenceKind.sick),
        absence('2026-11-06', v, 0.5),
      ]),
      [
        (d('2026-11-02'), d('2026-11-02'), 1.0),
        (d('2026-11-04'), d('2026-11-04'), 1.0),
        (d('2026-11-05'), d('2026-11-05'), 1.0),
        (d('2026-11-06'), d('2026-11-06'), 0.5),
      ],
    );
  });

  test('§10.4 holidays join a block; extra days off count every date', () {
    expect(
      blocks([
        // Christmas 2026: Thu 24 and Mon 28 Dec around the holidays and the
        // weekend (NRW).
        absence('2026-12-24', AbsenceKind.vacation),
        absence('2026-12-28', AbsenceKind.vacation),
      ]),
      // Heiligabend is a half day (§6.1).
      [(d('2026-12-24'), d('2026-12-28'), 1.5)],
    );
    expect(
      blocks([
        absence('2026-11-09', AbsenceKind.extraHoliday),
        absence('2026-11-10', AbsenceKind.extraHoliday),
      ]),
      [(d('2026-11-09'), d('2026-11-10'), 2.0)],
    );
  });
}
