import '../time/local_date.dart';
import 'ledger.dart';
import 'review.dart';

/// Weekly limits of worked time in minutes, 0 = off (spec: calculations.md
/// §22). The defaults follow § 3 ArbZG.
final class WeekLimits {
  /// Creates limits.
  const WeekLimits({
    this.maxMinutes = 3600,
    this.averageMinutes = 2880,
    this.averageWeeks = 24,
  });

  /// Most worked time in one week (`limits.week_max_min`).
  final int maxMinutes;

  /// Most average worked time per week (`limits.week_avg_min`).
  final int averageMinutes;

  /// Weeks of the rolling average (`limits.avg_weeks`).
  final int averageWeeks;
}

/// Worked time `W` of the week starting [monday] (§22).
int weekWorked(Ledger ledger, LocalDate monday) {
  var sum = 0;
  for (var i = 0; i < 7; i++) {
    sum += ledger.day(monday.addDays(i)).work.worked;
  }
  return sum;
}

/// The rolling average of the weeks up to the one starting [monday] (§22),
/// or `null` before the balance start's week.
int? weekAverage(Ledger ledger, LocalDate monday, WeekLimits limits) {
  final first = ledger.settings.balanceStart.startOfWeek;
  if (monday.isBefore(first) || limits.averageWeeks <= 0) return null;
  var sum = 0, weeks = 0;
  for (
    var m = monday;
    weeks < limits.averageWeeks && !m.isBefore(first);
    m = m.addDays(-7)
  ) {
    sum += weekWorked(ledger, m);
    weeks++;
  }
  return sum ~/ weeks;
}

/// The weekly limit notices of the finished weeks whose Sunday lies in
/// [from]–[to] (§22).
List<ReviewItem> weekLimitItems(
  Ledger ledger,
  WeekLimits limits, {
  required LocalDate from,
  required LocalDate to,
}) {
  final items = <ReviewItem>[];
  final today = ledger.today;
  for (
    var monday = from.startOfWeek;
    !monday.addDays(6).isAfter(to);
    monday = monday.addDays(7)
  ) {
    final sunday = monday.addDays(6);
    if (sunday.isBefore(from) || !sunday.isBefore(today)) continue;
    if (limits.maxMinutes > 0) {
      final worked = weekWorked(ledger, monday);
      if (worked > limits.maxMinutes) {
        items.add(
          ReviewItem(
            date: sunday,
            kind: ReviewKind.weekOverMax,
            minutes: worked,
          ),
        );
      }
    }
    if (limits.averageMinutes > 0) {
      final average = weekAverage(ledger, monday, limits);
      final before = weekAverage(ledger, monday.addDays(-7), limits) ?? 0;
      if (average != null &&
          average > limits.averageMinutes &&
          before <= limits.averageMinutes) {
        items.add(
          ReviewItem(
            date: sunday,
            kind: ReviewKind.weekAverageOver,
            minutes: average,
          ),
        );
      }
    }
  }
  return items;
}
