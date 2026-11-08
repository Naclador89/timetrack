import 'arbzg.dart';
import 'ledger.dart';

/// When today's target and the 10-hour limit will be reached at the current
/// pace (spec: calculations.md §18).
final class DayForecast {
  /// Creates a forecast; use [dayForecast].
  const DayForecast({this.targetAt, this.breakIncluded = 0, this.limitAt});

  /// When the target is reached, or `null` if it is reached already, the
  /// day has no target or it is a trip day.
  final DateTime? targetAt;

  /// Break minutes still required by ArbZG §4 that [targetAt] includes.
  final int breakIncluded;

  /// When 10 hours of work are reached, or `null` if they already are.
  final DateTime? limitAt;
}

/// The forecast for [day] (today) at [now], assuming work goes on without
/// interruption plus the break §4 still requires. [runningBreak] is the
/// length of a break in progress in minutes; it counts once work resumes
/// (spec: calculations.md §18).
DayForecast dayForecast(
  DayResult day, {
  required DateTime now,
  int runningBreak = 0,
}) {
  final utc = now.toUtc();
  final at = DateTime.utc(utc.year, utc.month, utc.day, utc.hour, utc.minute);
  final b = day.breaks;
  final countable = b.countableBreak + (runningBreak >= 15 ? runningBreak : 0);
  int missing(int worked) {
    final m = requiredBreakMinutes(worked) - countable;
    return m > 0 ? m : 0;
  }

  DateTime? targetAt;
  var breakIncluded = 0;
  final reached = day.credited + b.deduction;
  if (day.target > 0 && !day.isTripDay && reached < day.target) {
    final rest = day.target - reached;
    breakIncluded = missing(b.worked + rest);
    targetAt = at.add(Duration(minutes: rest + breakIncluded));
  }
  const limit = 600;
  final limitAt = b.worked < limit
      ? at.add(Duration(minutes: limit - b.worked + missing(limit)))
      : null;
  return DayForecast(
    targetAt: targetAt,
    breakIncluded: breakIncluded,
    limitAt: limitAt,
  );
}
