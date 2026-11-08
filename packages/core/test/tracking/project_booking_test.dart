// spec: calculations.md §3
import 'package:test/test.dart';
import 'package:timetrack_core/timetrack_core.dart';

void main() {
  test('§3 booking: durations snap to 15 minutes, at least 0:15', () {
    expect(snapToQuarter(90), 90);
    expect(snapToQuarter(97), 90);
    expect(snapToQuarter(98), 105);
    expect(snapToQuarter(3), 15);
    expect(snapToQuarter(0), 15);
  });

  test('recent notes of a project: newest first, no repeats', () {
    final data = LedgerData(
      entries: [
        ProjectEntry(
          id: 'a',
          projectId: 'p',
          start: DateTime.utc(2026, 11, 2, 8),
          end: DateTime.utc(2026, 11, 2, 9),
          note: 'Zeichnungen',
        ),
        ProjectEntry(
          id: 'b',
          projectId: 'q',
          start: DateTime.utc(2026, 11, 5, 8),
          end: DateTime.utc(2026, 11, 5, 9),
          note: 'anderes Projekt',
        ),
      ],
      durations: [
        ProjectDuration(
          id: 'c',
          projectId: 'p',
          date: LocalDate(2026, 11, 4),
          minutes: 60,
          note: 'Angebot',
        ),
        ProjectDuration(
          id: 'd',
          projectId: 'p',
          date: LocalDate(2026, 11, 3),
          minutes: 30,
          note: 'Zeichnungen',
        ),
      ],
    );
    expect(recentNotes(data, 'p'), ['Angebot', 'Zeichnungen']);
  });
}
