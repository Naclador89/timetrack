// spec: calculations.md §1–§3
import 'package:test/test.dart';
import 'package:timetrack_core/timetrack_core.dart';

final berlin = HomeTimeZone();

/// UTC instant for a Berlin local time on [date] (`HH:MM`).
DateTime at(LocalDate date, String hhmm) {
  final p = hhmm.split(':');
  final minute =
      berlin.daySpan(date).start + int.parse(p[0]) * 60 + int.parse(p[1]);
  return instantOfEpochMinute(minute);
}

final day = LocalDate(2026, 11, 4); // a Wednesday, CET (UTC+1)
final late = epochMinute(DateTime.utc(2030));

WorkSession session(
  String from,
  String? to, {
  WorkLocation loc = WorkLocation.office,
  LocalDate? on,
  String id = 's',
}) => WorkSession(
  id: id,
  start: at(on ?? day, from),
  end: to == null ? null : at(on ?? day, to),
  location: loc,
);

WorkBreak pause(String from, String to) =>
    WorkBreak(id: 'b', start: at(day, from), end: at(day, to));

ProjectEntry entry(String project, String from, String to) => ProjectEntry(
  id: '$project$from',
  projectId: project,
  start: at(day, from),
  end: at(day, to),
);

DayWork eval(
  List<WorkSession> sessions, {
  List<WorkBreak> breaks = const [],
  List<ProjectEntry> entries = const [],
  LocalDate? date,
  int? now,
}) => evaluateDay(
  date: date ?? day,
  day: berlin.daySpan(date ?? day),
  nowMinute: now ?? late,
  sessions: sessions,
  breaks: breaks,
  entries: entries,
);

void main() {
  group('§1 days in the home time zone', () {
    test('a normal day has 24 h, DST days 23 h and 25 h', () {
      expect(berlin.daySpan(day).length, 1440);
      expect(berlin.daySpan(LocalDate(2026, 3, 29)).length, 1380);
      expect(berlin.daySpan(LocalDate(2026, 10, 25)).length, 1500);
    });

    test('local date of an instant', () {
      expect(
        berlin.dateOf(DateTime.utc(2026, 11, 4, 23, 30)),
        LocalDate(2026, 11, 5),
      );
      expect(
        berlin.dateOf(DateTime.utc(2026, 7, 1, 21, 59)),
        LocalDate(2026, 7, 1),
      );
      expect(
        berlin.dateOf(DateTime.utc(2026, 7, 1, 22, 0)),
        LocalDate(2026, 7, 2),
      );
    });

    test('a session over midnight is split between both days', () {
      final s = WorkSession(
        id: 'n',
        start: at(day, '22:00'),
        end: at(day.addDays(1), '02:00'),
        location: WorkLocation.office,
      );
      expect(eval([s]).worked, 120);
      expect(eval([s], date: day.addDays(1)).worked, 120);
    });

    test('00:00–06:00 on the spring DST day is only 5 h', () {
      final dst = LocalDate(2026, 3, 29);
      final s = WorkSession(
        id: 'd',
        start: instantOfEpochMinute(berlin.daySpan(dst).start),
        end: DateTime.utc(2026, 3, 29, 4), // 06:00 CEST
        location: WorkLocation.office,
      );
      expect(eval([s], date: dst).worked, 300);
    });
  });

  group('§2 worked time', () {
    test('example: overlapping sessions and a break → 510 min', () {
      final result = eval(
        [
          session('08:00', '12:00', id: 'a'),
          session('11:30', '17:00', id: 'b'),
        ],
        breaks: [pause('12:00', '12:30')],
      );
      expect(result.worked, 510);
      expect(result.overlappingSessions, isTrue);
    });

    test('duplicated sessions (sync conflict) never count twice', () {
      final s = session('08:00', '16:00');
      expect(eval([s, s, s]).worked, 480);
    });

    test('an open session runs until now', () {
      final now = epochMinute(at(day, '10:15'));
      expect(eval([session('08:00', null)], now: now).worked, 135);
    });

    test('breaks outside sessions have no effect', () {
      expect(
        eval(
          [session('08:00', '12:00')],
          breaks: [pause('13:00', '14:00')],
        ).worked,
        240,
      );
    });

    test('an end before the start counts as empty instead of failing', () {
      final broken = WorkSession(
        id: 'x',
        start: at(day, '12:00'),
        end: at(day, '08:00'),
        location: WorkLocation.office,
      );
      expect(eval([broken]).worked, 0);
    });

    test('W_loc: an overlap counts for the session that started later', () {
      final result = eval([
        session('08:00', '12:00', loc: WorkLocation.home, id: 'h'),
        session('11:00', '15:00', loc: WorkLocation.office, id: 'o'),
      ]);
      expect(result.workedAt(WorkLocation.home), 180);
      expect(result.workedAt(WorkLocation.office), 240);
      expect(result.worked, 420);
    });

    test('W_loc: breaks are subtracted per location and totals add up', () {
      final result = eval(
        [
          session('07:00', '09:00', loc: WorkLocation.home, id: 'h'),
          session('09:00', '11:00', loc: WorkLocation.travel, id: 't'),
          session('11:00', '17:00', loc: WorkLocation.onSite, id: 'o'),
        ],
        breaks: [pause('12:00', '12:45')],
      );
      expect(result.byLocation, {
        WorkLocation.home: 120,
        WorkLocation.travel: 120,
        WorkLocation.onSite: 315,
      });
      expect(result.byLocation.values.fold(0, (a, b) => a + b), result.worked);
    });
  });

  group('§3 project time', () {
    test('unassigned = worked − project time', () {
      final result = eval(
        [session('08:00', '16:00')],
        breaks: [pause('12:00', '12:30')],
        entries: [entry('A', '08:00', '10:30'), entry('B', '10:45', '12:00')],
      );
      expect(result.worked, 450);
      expect(result.projectTime, 225);
      expect(result.unassigned, 225);
      expect(result.byProject, {'A': 150, 'B': 75});
    });

    test(
      'project time during a break or outside sessions is flagged, not counted',
      () {
        final result = eval(
          [session('08:00', '12:00')],
          breaks: [pause('10:00', '10:30')],
          entries: [entry('A', '09:00', '13:00')],
        );
        expect(result.projectTime, 150);
        expect(result.projectOutsideWork, 90);
      },
    );

    test(
      'overlapping entries give both projects the overlap and are flagged',
      () {
        final result = eval(
          [session('08:00', '12:00')],
          entries: [entry('A', '08:00', '10:00'), entry('B', '09:00', '11:00')],
        );
        expect(result.byProject, {'A': 120, 'B': 120});
        expect(result.projectTime, 180);
        expect(result.overlappingProjectEntries, isTrue);
      },
    );
  });
}
