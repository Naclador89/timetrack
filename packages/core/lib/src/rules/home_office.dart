import '../model/attendance.dart';
import '../model/planning.dart';
import '../time/local_date.dart';
import 'ledger.dart';

/// How a day's home-office value is decided (setting `home_office.day_rule`,
/// spec: calculations.md §11.1).
enum HomeOfficeDayRule {
  /// 1 if more than half of the worked time was at home (default).
  majority,

  /// 1 if any time was worked at home.
  any,

  /// The share of worked time at home, e.g. 0.5.
  proportional,
}

/// The home-office value `H(D)` of an evaluated day (spec: calculations.md §11.1).
///
/// Trip days and days without work are never home-office days.
double homeOfficeValue(DayResult day, HomeOfficeDayRule rule) {
  final worked = day.work.worked;
  if (day.isTripDay || worked == 0) return 0;
  final home = day.work.workedAt(WorkLocation.home);
  return switch (rule) {
    HomeOfficeDayRule.majority => home * 2 > worked ? 1 : 0,
    HomeOfficeDayRule.any => home > 0 ? 1 : 0,
    HomeOfficeDayRule.proportional => home / worked,
  };
}

/// The first and last day of the [period] containing [date].
(LocalDate, LocalDate) periodAround(LocalDate date, QuotaPeriod period) =>
    switch (period) {
      QuotaPeriod.week => (date.startOfWeek, date.startOfWeek.addDays(6)),
      QuotaPeriod.month => (
        date.startOfMonth,
        LocalDate(
          date.year,
          date.month,
          1,
        ).addDays(31).startOfMonth.addDays(-1),
      ),
    };

/// The version of the rule `(period, unit)` that applies to the period
/// starting on [periodStart]: the greatest `validFrom ≤ periodStart`.
HomeOfficeRule? ruleForPeriod(
  List<HomeOfficeRule> versions, {
  required QuotaPeriod period,
  required QuotaUnit unit,
  required LocalDate periodStart,
}) {
  HomeOfficeRule? best;
  for (final r in versions) {
    if (r.period != period || r.unit != unit) continue;
    if (r.validFrom.isAfter(periodStart)) continue;
    if (best == null || r.validFrom.isAfter(best.validFrom)) best = r;
  }
  return best;
}

/// The state of one home-office quota in one period
/// (spec: calculations.md §11.2–§11.4).
final class HomeOfficeQuota {
  /// Creates a result. Use [evaluateQuota] instead of calling this directly.
  const HomeOfficeQuota({
    required this.rule,
    required this.start,
    required this.end,
    required this.used,
    required this.base,
    required this.allowedTotal,
  });

  /// The rule version that applies.
  final HomeOfficeRule rule;

  /// First day of the period.
  final LocalDate start;

  /// Last day of the period.
  final LocalDate end;

  /// Home-office days (unit days) or minutes at home (unit hours) so far.
  final double used;

  /// Basis: days (unit days) or worked minutes (unit hours).
  final double base;

  /// Forecast for unit days: home-office days allowed in the whole period
  /// (§11.3). For unit hours, the allowed minutes of the time worked so far.
  final int allowedTotal;

  /// Share used so far, 0–1 (0 if there is no basis yet).
  double get share => base == 0 ? 0 : used / base;

  /// Home-office days (or minutes) still allowed in this period.
  double get left {
    final l = allowedTotal - used;
    return l > 0 ? l : 0;
  }

  /// §11.4: another home-office day would exceed the quota (unit days only).
  bool get nextDayExceeds =>
      rule.unit == QuotaUnit.days && used + 1 > allowedTotal;
}

/// Evaluates [rule] for the period that contains [ledger]'s today
/// (or [on], if given), using [dayRule] for `H(D)` (spec: calculations.md §11).
HomeOfficeQuota evaluateQuota(
  Ledger ledger,
  HomeOfficeRule rule, {
  HomeOfficeDayRule dayRule = HomeOfficeDayRule.majority,
  LocalDate? on,
}) {
  final today = on ?? ledger.today;
  final (start, end) = periodAround(today, rule.period);
  var used = 0.0, base = 0.0, remaining = 0;
  for (var d = start; !d.isAfter(end); d = d.addDays(1)) {
    final day = ledger.day(d);
    final past = !d.isAfter(today);
    final absent = day.absences
        .where((a) => !a.kind.reducesTarget)
        .fold(0.0, (sum, a) => sum + a.fraction)
        .clamp(0.0, 1.0);
    final workday = day.target > 0;
    if (rule.unit == QuotaUnit.hours) {
      if (past) {
        used += day.work.workedAt(WorkLocation.home);
        base += day.work.worked;
      }
      continue;
    }
    if (past) used += homeOfficeValue(day, dayRule);
    switch (rule.basis) {
      case QuotaBasis.worked:
        if (past && day.work.worked > 0) base += 1;
      case QuotaBasis.scheduled:
        if (workday) base += 1 - absent;
    }
    final stillOpen = d.isAfter(today) || (d == today && day.work.worked == 0);
    if (workday && stillOpen && absent < 1) remaining++;
  }
  final total = switch ((rule.unit, rule.basis)) {
    (QuotaUnit.hours, _) => base,
    (QuotaUnit.days, QuotaBasis.worked) => base + remaining,
    (QuotaUnit.days, QuotaBasis.scheduled) => base,
  };
  return HomeOfficeQuota(
    rule: rule,
    start: start,
    end: end,
    used: used,
    base: base,
    allowedTotal: (rule.maxPercent * total) ~/ 100,
  );
}

/// §11.5: home-office days of [year] up to [ledger]'s today, always by the
/// majority rule (tax law counts days "überwiegend" at home).
int homeOfficeDaysInYear(Ledger ledger, int year) {
  var count = 0;
  final today = ledger.today;
  for (
    var d = LocalDate(year, 1, 1);
    d.year == year && !d.isAfter(today);
    d = d.addDays(1)
  ) {
    count += homeOfficeValue(ledger.day(d), HomeOfficeDayRule.majority).toInt();
  }
  return count;
}
