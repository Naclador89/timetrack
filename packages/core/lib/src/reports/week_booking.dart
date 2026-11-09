import '../model/project.dart';
import '../rules/ledger.dart';
import '../time/local_date.dart';

/// One row of the weekly booking form: a project number and order number
/// with half hours Monday–Sunday (spec: booking-transfer.md §2).
final class WeekBookingRow {
  /// Creates a row. Use [buildWeekBooking] instead of calling this directly.
  const WeekBookingRow({
    required this.projectNumber,
    required this.orderNumber,
    required this.projectNames,
    required this.halfHours,
  });

  /// Project number (Projekt on the page).
  final String projectNumber;

  /// Order number (Auftrag); empty if the projects have none.
  final String orderNumber;

  /// Names of the projects behind this row, sorted.
  final List<String> projectNames;

  /// Rounded time Monday–Sunday in half hours (7 values).
  final List<int> halfHours;

  /// Rounded week total in half hours.
  int get totalHalfHours => halfHours.fold(0, (a, h) => a + h);
}

/// A project with time in the week that isn't transferred because it has no
/// project number (spec: booking-transfer.md §2.2).
final class SkippedProject {
  /// Creates the entry.
  const SkippedProject({required this.name, required this.minutes});

  /// Project name (`?` for an unknown project id).
  final String name;

  /// Project time in the week.
  final int minutes;
}

/// A day whose transferred time differs from the exact project time
/// (spec: booking-transfer.md §3).
final class RoundingDifference {
  /// Creates the entry.
  const RoundingDifference({
    required this.date,
    required this.exactMinutes,
    required this.roundedMinutes,
  });

  /// The day.
  final LocalDate date;

  /// Exact project time of the projects with a project number.
  final int exactMinutes;

  /// Transferred time (half hours × 30).
  final int roundedMinutes;
}

/// One week of project time, ready to fill into the weekly booking form
/// (spec: booking-transfer.md).
final class WeekBooking {
  /// Creates the week. Use [buildWeekBooking] instead of calling this.
  const WeekBooking({
    required this.monday,
    required this.rows,
    required this.skipped,
    required this.runningTimer,
    required this.unassignedByDay,
    required this.roundingDifferences,
    required this.exactMinutes,
  });

  /// The Monday of the week.
  final LocalDate monday;

  /// The rows, sorted by project number, then order number.
  final List<WeekBookingRow> rows;

  /// Projects not transferred because they have no project number.
  final List<SkippedProject> skipped;

  /// Whether a project timer that started in this week is still running.
  final bool runningTimer;

  /// Worked time without a project per day (only days with some).
  final Map<LocalDate, int> unassignedByDay;

  /// Days whose rounded time differs from the exact time.
  final List<RoundingDifference> roundingDifferences;

  /// Exact project time of the week for projects with a project number.
  final int exactMinutes;

  /// Rounded week total in minutes.
  int get roundedMinutes => rows.fold(0, (a, r) => a + r.totalHalfHours * 30);

  /// ISO 8601 week number (1–53), the page's `KW`.
  int get isoWeek {
    final thursday = monday.addDays(3);
    return LocalDate(thursday.year, 1, 1).daysUntil(thursday) ~/ 7 + 1;
  }

  /// ISO 8601 week-numbering year (the year of the week's Thursday), the
  /// page's `JAHR`.
  int get isoYear => monday.addDays(3).year;

  /// Key of the week, e.g. `2026-W46` (spec: booking-transfer.md §7).
  String get weekKey => '$isoYear-W${isoWeek.toString().padLeft(2, '0')}';

  /// Text of the transferred values; changes exactly when they change
  /// (spec: booking-transfer.md §7).
  String get fingerprint => [
    for (final r in rows)
      '${r.projectNumber}|${r.orderNumber}|${r.halfHours.join(',')}',
  ].join(';');
}

/// Rounds [minutes] to half hours, nearest, halves up
/// (spec: booking-transfer.md §2.4).
int roundToHalfHours(int minutes) => (minutes + 15) ~/ 30;

/// Builds the week starting at [monday] for the booking form
/// (spec: booking-transfer.md §2, §3).
WeekBooking buildWeekBooking(
  Ledger ledger,
  Map<String, Project> projects, {
  required LocalDate monday,
}) {
  assert(monday.weekday == DateTime.monday, 'monday must be a Monday');
  final minutes = <(String, String), List<int>>{};
  final names = <(String, String), Set<String>>{};
  final skipped = <String, (String, int)>{};
  final unassigned = <LocalDate, int>{};
  final exactByDay = List.filled(7, 0);
  for (var i = 0; i < 7; i++) {
    final date = monday.addDays(i);
    final day = ledger.day(date);
    if (day.unassigned > 0) unassigned[date] = day.unassigned;
    for (final MapEntry(key: id, value: m) in day.bookedByProject.entries) {
      if (m <= 0) continue;
      final p = projects[id];
      if (p == null || p.projectNumber.trim().isEmpty) {
        final (name, before) = skipped[id] ?? (p?.name ?? '?', 0);
        skipped[id] = (name, before + m);
        continue;
      }
      final key = (p.projectNumber.trim(), p.orderNumber.trim());
      (minutes[key] ??= List.filled(7, 0))[i] += m;
      (names[key] ??= {}).add(p.name);
      exactByDay[i] += m;
    }
  }
  final keys = minutes.keys.toList()
    ..sort((a, b) {
      final c = a.$1.compareTo(b.$1);
      return c != 0 ? c : a.$2.compareTo(b.$2);
    });
  final rows = [
    for (final key in keys)
      WeekBookingRow(
        projectNumber: key.$1,
        orderNumber: key.$2,
        projectNames: names[key]!.toList()..sort(),
        halfHours: [for (final m in minutes[key]!) roundToHalfHours(m)],
      ),
  ].where((r) => r.totalHalfHours > 0).toList();
  final differences = <RoundingDifference>[];
  for (var i = 0; i < 7; i++) {
    final rounded = rows.fold(0, (a, r) => a + r.halfHours[i] * 30);
    if (rounded != exactByDay[i]) {
      differences.add(
        RoundingDifference(
          date: monday.addDays(i),
          exactMinutes: exactByDay[i],
          roundedMinutes: rounded,
        ),
      );
    }
  }
  final sunday = monday.addDays(6);
  final running = ledger.data.entries.any((e) {
    if (e.end != null) return false;
    final start = ledger.zone.dateOf(e.start);
    return !start.isBefore(monday) && !start.isAfter(sunday);
  });
  return WeekBooking(
    monday: monday,
    rows: rows,
    skipped: [
      for (final (name, m) in skipped.values)
        SkippedProject(name: name, minutes: m),
    ]..sort((a, b) => a.name.compareTo(b.name)),
    runningTimer: running,
    unassignedByDay: unassigned,
    roundingDifferences: differences,
    exactMinutes: exactByDay.fold(0, (a, m) => a + m),
  );
}
