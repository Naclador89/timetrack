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

/// The next vacation after today (spec: calculations.md §10.3).
final class NextVacation {
  /// Creates the result. Use [nextVacation] instead of calling this directly.
  const NextVacation({
    required this.start,
    required this.end,
    required this.days,
  });

  /// The first vacation day of the block.
  final LocalDate start;

  /// The last vacation day of the block.
  final LocalDate end;

  /// Vacation days the block uses (workdays only, halves count 0.5).
  final double days;
}

/// The next vacation block that starts after [today], or `null` if none is
/// entered (spec: calculations.md §10.3).
///
/// Vacation days joined only by free days (weekends, holidays) form one
/// block. The block [today] belongs to is skipped: that vacation is already
/// running.
NextVacation? nextVacation({
  required TargetCalendar targets,
  required List<Absence> absences,
  required LocalDate today,
}) {
  final vacation = <LocalDate, double>{};
  for (final a in absences) {
    if (a.kind != AbsenceKind.vacation || a.date.isBefore(today)) continue;
    if (!targets.isWorkday(a.date)) continue;
    vacation[a.date] = (vacation[a.date] ?? 0) + a.fraction;
  }
  if (vacation.isEmpty) return null;
  // Free days are endless without a schedule, so every walk is bounded.
  const horizon = 366;
  bool joins(LocalDate d) => vacation.containsKey(d) || !targets.isWorkday(d);

  var from = today.addDays(1);
  if (vacation.containsKey(today) ||
      (!targets.isWorkday(today) &&
          _previousWorkdayIsVacation(targets, absences, today))) {
    from = today;
    for (var i = 0; i < horizon && joins(from); i++) {
      from = from.addDays(1);
    }
  }
  final starts = vacation.keys.where((d) => !d.isBefore(from)).toList()..sort();
  if (starts.isEmpty) return null;
  final start = starts.first;
  var end = start, days = 0.0;
  var d = start;
  for (var i = 0; i < horizon && joins(d); i++) {
    if (vacation[d] case final f?) {
      days += f;
      end = d;
    }
    d = d.addDays(1);
  }
  return NextVacation(start: start, end: end, days: days);
}

/// Whether the last workday before [date] (across free days) is a vacation
/// day, so that a free [date] lies inside a running vacation.
bool _previousWorkdayIsVacation(
  TargetCalendar targets,
  List<Absence> absences,
  LocalDate date,
) {
  var d = date.addDays(-1);
  for (var i = 0; i < 31 && !targets.isWorkday(d); i++) {
    d = d.addDays(-1);
  }
  return absences.any((a) => a.kind == AbsenceKind.vacation && a.date == d);
}
