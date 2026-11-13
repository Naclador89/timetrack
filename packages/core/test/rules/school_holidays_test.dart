// spec: calculations.md §10.5
import 'package:test/test.dart';
import 'package:timetrack_core/timetrack_core.dart';

LocalDate d(String iso) => LocalDate.parse(iso);

void main() {
  test('§10.5 the periods touching a year, by start', () {
    final by = schoolHolidays(FederalState.by, 2026);
    expect(
      by.first,
      SchoolHoliday(d('2025-12-22'), d('2026-01-05'), 'Weihnachtsferien'),
    );
    expect(
      by,
      contains(SchoolHoliday(d('2026-08-03'), d('2026-09-14'), 'Sommerferien')),
    );
    expect(by.last.start, d('2026-12-24'));
    expect(by.last.end.year, 2027);
    for (final (a, b) in [
      for (var i = 1; i < by.length; i++) (by[i - 1], by[i]),
    ]) {
      expect(a.start.isAfter(b.start), isFalse);
    }
    expect(by.last.contains(d('2026-12-31')), isTrue);
    expect(by.last.contains(d('2026-12-23')), isFalse);
  });

  test('§10.5 every state has dates through 2030; later years are empty', () {
    for (final state in FederalState.values) {
      for (var year = 2025; year <= 2030; year++) {
        final periods = schoolHolidays(state, year);
        expect(
          periods.where(
            (p) => p.name == 'Sommerferien' && p.start.year == year,
          ),
          hasLength(1),
          reason: '${state.code} $year',
        );
        expect(periods.every((p) => !p.end.isBefore(p.start)), isTrue);
      }
    }
    expect(schoolHolidays(FederalState.nw, 2040), isEmpty);
  });

  test('§10.5 MV: the general schools\' dates; SH: no island exceptions', () {
    final mv = schoolHolidays(FederalState.mv, 2026);
    expect(
      mv.where((p) => p.name == 'Winterferien').single,
      SchoolHoliday(d('2026-02-09'), d('2026-02-20'), 'Winterferien'),
    );
    final sh = schoolHolidays(FederalState.sh, 2026);
    expect(
      sh.where((p) => p.name == 'Sommerferien').single.end,
      d('2026-08-15'),
    );
  });
}
