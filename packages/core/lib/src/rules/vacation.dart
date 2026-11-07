import '../model/planning.dart';
import '../time/local_date.dart';
import 'target.dart';

/// The vacation account of one calendar year, in days
/// (spec: calculations.md §10).
final class VacationAccount {
  /// Creates an account. Use [vacationAccount] instead of calling this directly.
  const VacationAccount({
    required this.year,
    required this.entitlement,
    required this.carryOver,
    required this.taken,
    required this.planned,
  });

  /// The calendar year.
  final int year;

  /// Vacation days for the year.
  final double entitlement;

  /// Days carried over from the previous year.
  final double carryOver;

  /// Vacation days taken up to and including today.
  final double taken;

  /// Vacation days entered for days after today.
  final double planned;

  /// Days left after everything taken and planned.
  double get remaining => entitlement + carryOver - taken - planned;
}

/// Computes the vacation account of [year] as of [today]
/// (spec: calculations.md §10).
///
/// Only vacation on workdays counts, so a vacation entry on a weekend or a
/// public holiday doesn't use up a day. [entitlementOverride] is the setting
/// `vacation.entitlement.<year>`; [carryOver] is `vacation.carry_over.<year>`.
VacationAccount vacationAccount({
  required int year,
  required TargetCalendar targets,
  required List<WorkSchedule> schedules,
  required List<Absence> absences,
  required LocalDate today,
  double? entitlementOverride,
  double carryOver = 0,
}) {
  var taken = 0.0, planned = 0.0;
  for (final a in absences) {
    if (a.kind != AbsenceKind.vacation || a.date.year != year) continue;
    if (!targets.isWorkday(a.date)) continue;
    if (a.date.isAfter(today)) {
      planned += a.fraction;
    } else {
      taken += a.fraction;
    }
  }
  return VacationAccount(
    year: year,
    entitlement:
        entitlementOverride ?? _scheduleForYear(year, targets, schedules),
    carryOver: carryOver,
    taken: taken,
    planned: planned,
  );
}

/// The schedule valid on 1 January, or else the first one starting during [year].
double _scheduleForYear(
  int year,
  TargetCalendar targets,
  List<WorkSchedule> schedules,
) {
  final onJan1 = targets.scheduleOn(LocalDate(year, 1, 1));
  if (onJan1 != null) return onJan1.annualVacationDays;
  final inYear = schedules.where((s) => s.validFrom.year == year).toList()
    ..sort((a, b) => a.validFrom.compareTo(b.validFrom));
  return inYear.isEmpty ? 0 : inYear.first.annualVacationDays;
}
