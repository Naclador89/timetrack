import '../model/planning.dart';
import 'credit.dart';
import 'ledger.dart';

/// Why the target of a day is what it is (calculations.md §7).
enum TargetReason {
  /// From the work schedule.
  schedule,

  /// 0 on a public holiday.
  holiday,

  /// Lowered by an extra day off or short-time work.
  reduced,

  /// Halved on Heiligabend or Silvester (§6.1).
  halfDay,

  /// No scheduled work on this weekday.
  dayOff,
}

/// How the credited time of a day came about, step by step, so the UI can
/// answer "why isn't this overtime?" (calculations.md §16). Pure data; the
/// app turns it into text.
final class DayExplanation {
  /// Creates an explanation. Use [explainDay].
  const DayExplanation({
    required this.worked,
    required this.breakDeduction,
    required this.effective,
    required this.rule,
    required this.ruleCredit,
    required this.absenceCredit,
    required this.absenceKinds,
    required this.target,
    required this.targetReason,
    required this.credited,
    required this.sundayHours,
    this.specialHolidayHours = 0,
    this.nightHours = 0,
    this.nightExcluded = false,
  });

  /// Worked time `W(D)` (§2).
  final int worked;

  /// Break deducted by the auto-deduct mode (§4).
  final int breakDeduction;

  /// Effective worked time `W_eff(D)`.
  final int effective;

  /// The §9 rule applied, or `null` if [effective] counts as is.
  final TripDayType? rule;

  /// Credit from worked time after [rule].
  final int ruleCredit;

  /// Credit from absences (§8).
  final int absenceCredit;

  /// The crediting absences of the day.
  final List<AbsenceKind> absenceKinds;

  /// Target `T(D)` (§7).
  final int target;

  /// Why [target] is what it is.
  final TargetReason targetReason;

  /// Credited time `Cr(D)`.
  final int credited;

  /// Sunday hours for HR (§9).
  final int sundayHours;

  /// Sunday hours of a special holiday (§21.1).
  final int specialHolidayHours;

  /// Night hours (§21.2).
  final int nightHours;

  /// Whether [nightHours] are left out of the credited time (§21.2).
  final bool nightExcluded;

  /// `Cr(D) − T(D)`.
  int get delta => credited - target;

  /// Worked time the rule didn't count (Sunday rule, Saturday cap), or
  /// negative when the rule credited more than was worked (trip workday).
  /// Excluded night hours are not part of it (§21.2).
  int get notCounted =>
      effective - (nightExcluded ? nightHours : 0) - ruleCredit;
}

/// Explains [day] (calculations.md §16). [isHoliday] tells a holiday's
/// target of 0 apart from a free weekday.
DayExplanation explainDay(
  DayResult day, {
  required bool isHoliday,
  NightWorkCredit night = NightWorkCredit.count,
}) {
  // The ledger adds absence credit last (§8), so the rest is the rule's.
  final absence = day.absenceCredit;
  return DayExplanation(
    worked: day.work.worked,
    breakDeduction: day.breaks.deduction,
    effective: day.breaks.effectiveWorked,
    rule: day.creditRule,
    ruleCredit: day.credited - absence,
    absenceCredit: absence,
    absenceKinds: [
      for (final a in day.absences)
        if (a.kind.creditsTarget) a.kind,
    ],
    target: day.target,
    // A day without scheduled work is a day off, even when it is
    // Heiligabend or lies in a short-time range (§6.1, §7).
    targetReason: isHoliday
        ? TargetReason.holiday
        : day.scheduled == 0
        ? TargetReason.dayOff
        : day.absences.any((a) => a.kind.reducesTarget)
        ? TargetReason.reduced
        : day.halfDay
        ? TargetReason.halfDay
        : day.target == 0
        ? TargetReason.dayOff
        : TargetReason.schedule,
    credited: day.credited,
    sundayHours: day.sundayHours,
    specialHolidayHours: day.specialHolidayHours,
    nightHours: day.nightHours,
    nightExcluded: night == NightWorkCredit.exclude && day.nightHours > 0,
  );
}
