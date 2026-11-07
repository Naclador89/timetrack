import 'package:test/test.dart';
import 'package:timetrack_core/timetrack_core.dart';

void main() {
  group('LocalDate', () {
    test('rejects dates that do not exist', () {
      expect(() => LocalDate(2026, 2, 29), throwsArgumentError);
      expect(LocalDate(2028, 2, 29).toString(), '2028-02-29');
    });

    test('parses and formats ISO 8601 (spec: sync-format.md §4)', () {
      expect(LocalDate.parse('2026-11-07'), LocalDate(2026, 11, 7));
      expect(LocalDate(987, 1, 2).toString(), '0987-01-02');
      expect(() => LocalDate.parse('2026-11-7'), throwsFormatException);
    });

    test('uses ISO weekdays', () {
      expect(LocalDate(2026, 11, 7).weekday, DateTime.saturday);
      expect(LocalDate(2026, 11, 9).weekday, DateTime.monday);
      expect(LocalDate(2026, 11, 8).isWeekend, isTrue);
    });

    test('date arithmetic ignores DST (2026-03-29 has 23 h in Berlin)', () {
      expect(LocalDate(2026, 3, 28).addDays(2), LocalDate(2026, 3, 30));
      expect(LocalDate(2026, 12, 31).addDays(1), LocalDate(2027, 1, 1));
      expect(LocalDate(2026, 3, 1).daysUntil(LocalDate(2026, 4, 1)), 31);
      expect(LocalDate(2026, 4, 1).daysUntil(LocalDate(2026, 3, 1)), -31);
    });

    test('week starts on Monday, month on the 1st', () {
      expect(LocalDate(2026, 11, 8).startOfWeek, LocalDate(2026, 11, 2));
      expect(LocalDate(2026, 11, 2).startOfWeek, LocalDate(2026, 11, 2));
      expect(LocalDate(2027, 1, 1).startOfWeek, LocalDate(2026, 12, 28));
      expect(LocalDate(2026, 11, 30).startOfMonth, LocalDate(2026, 11, 1));
    });

    test('compares and works as map key', () {
      final a = LocalDate(2026, 11, 7);
      expect(a.isBefore(LocalDate(2026, 11, 8)), isTrue);
      expect(a.isAfter(LocalDate(2025, 12, 31)), isTrue);
      expect({a: 1}[LocalDate(2026, 11, 7)], 1);
    });
  });

  group('HomeTimeZone local time', () {
    final zone = HomeTimeZone();
    test('toLocal and instantAt are inverse, also in summer time', () {
      final winter = zone.instantAt(LocalDate(2026, 11, 4), 8, 30);
      expect(winter, DateTime.utc(2026, 11, 4, 7, 30));
      final summer = zone.instantAt(LocalDate(2026, 7, 1), 8, 30);
      expect(summer, DateTime.utc(2026, 7, 1, 6, 30));
      final local = zone.toLocal(summer);
      expect((local.hour, local.minute), (8, 30));
    });
  });

  test('§14 formatMinutes', () {
    expect(formatMinutes(465), '7:45');
    expect(formatMinutes(-90), '\u22121:30');
    expect(formatMinutes(5), '0:05');
  });
}
