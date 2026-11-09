// spec: work-pc.md §4
import 'package:test/test.dart';
import 'package:timetrack_core/timetrack_core.dart';

void main() {
  final start = LocalDate(2026, 1, 1);

  test('§4 after a change of month the previous month is due', () {
    expect(
      monthReportDue(today: LocalDate(2026, 11, 2), balanceStart: start),
      LocalDate(2026, 10, 1),
    );
    expect(
      monthReportDue(today: LocalDate(2027, 1, 4), balanceStart: start),
      LocalDate(2026, 12, 1),
      reason: 'across the year',
    );
  });

  test('§4 a reported month is not due again', () {
    final today = LocalDate(2026, 11, 20);
    expect(
      monthReportDue(today: today, balanceStart: start, done: '2026-10'),
      isNull,
    );
    expect(
      monthReportDue(today: today, balanceStart: start, done: '2026-09'),
      LocalDate(2026, 10, 1),
    );
  });

  test('§4 nothing is due for a month before the balance start', () {
    expect(
      monthReportDue(
        today: LocalDate(2026, 11, 2),
        balanceStart: LocalDate(2026, 11, 1),
      ),
      isNull,
    );
    expect(
      monthReportDue(
        today: LocalDate(2026, 11, 2),
        balanceStart: LocalDate(2026, 10, 31),
      ),
      LocalDate(2026, 10, 1),
    );
  });

  test('monthKey pads the month', () {
    expect(monthKey(LocalDate(2026, 3, 15)), '2026-03');
  });
}
