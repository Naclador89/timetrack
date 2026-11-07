import '../time/span.dart';

/// How missing breaks are handled (setting `break_rule_mode`,
/// spec: calculations.md §4).
enum BreakRuleMode {
  /// Only warn; worked time stays as recorded (default).
  warn,

  /// Deduct the missing break from the worked time.
  deduct,
}

/// Gaps shorter than this don't count as a break (§4 ArbZG: breaks of at
/// least 15 minutes).
const int minCountableBreakMinutes = 15;

/// Longest allowed stretch of work without a countable break (6 h).
const int maxContinuousWorkMinutes = 360;

/// Daily maximum before the `over10h` warning (§3 ArbZG).
const int maxDailyWorkMinutes = 600;

/// Minimum rest between two working days (§5 ArbZG, 11 h).
const int minRestMinutes = 660;

/// The break required for [worked] minutes of work: 0 up to 6 h, 30 min up to
/// 9 h, 45 min above (§4 ArbZG).
int requiredBreakMinutes(int worked) => worked <= 360
    ? 0
    : worked <= 540
    ? 30
    : 45;

/// The break check of one day (spec: calculations.md §4).
final class BreakEvaluation {
  /// Creates a result. Use [evaluateBreaks] instead of calling this directly.
  const BreakEvaluation({
    required this.worked,
    required this.countableBreak,
    required this.deduction,
    required this.longestStretch,
  });

  /// Worked minutes `W` before deduction.
  final int worked;

  /// Countable break minutes `C`: gaps of at least 15 minutes.
  final int countableBreak;

  /// Minutes deducted in [BreakRuleMode.deduct] (0 in warn mode).
  final int deduction;

  /// Worked minutes of the longest stretch not interrupted by a countable break.
  final int longestStretch;

  /// Required break `R(W)`.
  int get requiredBreak => requiredBreakMinutes(worked);

  /// Missing break `M = max(0, R(W) − C)`, before any deduction.
  int get missingBreak {
    final missing = requiredBreak - countableBreak;
    return missing > 0 ? missing : 0;
  }

  /// Worked minutes after deduction, `W_eff`. Everything after §4 uses this.
  int get effectiveWorked => worked - deduction;

  /// Whether some stretch exceeds 6 h without a countable break.
  bool get workOver6hWithoutBreak => longestStretch > maxContinuousWorkMinutes;
}

/// Checks the breaks of one day's working intervals `WI(D)`
/// (spec: calculations.md §4).
BreakEvaluation evaluateBreaks(
  SpanSet working, {
  BreakRuleMode mode = BreakRuleMode.warn,
}) {
  final worked = working.length;
  final gaps = working.gaps;
  final countable = gaps
      .where((g) => g.length >= minCountableBreakMinutes)
      .fold(0, (sum, g) => sum + g.length);

  var longest = 0, stretch = 0;
  for (var i = 0; i < working.spans.length; i++) {
    if (i > 0 && gaps[i - 1].length >= minCountableBreakMinutes) stretch = 0;
    stretch += working.spans[i].length;
    if (stretch > longest) longest = stretch;
  }

  return BreakEvaluation(
    worked: worked,
    countableBreak: countable,
    deduction: mode == BreakRuleMode.deduct
        ? _smallestDeduction(worked, countable)
        : 0,
    longestStretch: longest,
  );
}

/// The smallest whole-minute `d ≥ 0` with `C + d ≥ R(W − d)`. Deducting only
/// that much never pushes a day further below a threshold than needed.
int _smallestDeduction(int worked, int countable) {
  for (var d = 0; d <= worked; d++) {
    if (countable + d >= requiredBreakMinutes(worked - d)) return d;
  }
  return worked;
}

/// Kinds of warnings from the Working Hours Act (spec: calculations.md §4, §5).
enum ArbzgWarningKind {
  /// Less break than required (§4).
  breakMissing,

  /// More than 6 h of work without a countable break (§4).
  workOver6hWithoutBreak,

  /// More than 10 h of work in one day (§3).
  over10h,

  /// Less than 11 h rest since the previous working day (§5).
  restUnder11h,

  /// Work on a Sunday or public holiday (§9, informational).
  sundayOrHolidayWork,
}

/// One warning, with the relevant [minutes] (missing break, worked time or
/// rest, depending on [kind]).
final class ArbzgWarning {
  /// Creates a warning.
  const ArbzgWarning(this.kind, this.minutes);

  /// What the warning is about.
  final ArbzgWarningKind kind;

  /// Missing break, worked or rest minutes, depending on [kind].
  final int minutes;

  @override
  bool operator ==(Object other) =>
      other is ArbzgWarning && other.kind == kind && other.minutes == minutes;

  @override
  int get hashCode => Object.hash(kind, minutes);

  @override
  String toString() => 'ArbzgWarning(${kind.name}, $minutes)';
}

/// All Working Hours Act warnings for a day with working intervals [working]
/// (spec: calculations.md §4, §5). They always use the actual recorded times,
/// also on trip days.
///
/// [previousDay] are the working intervals of the day before (for the rest
/// check). [isSundayOrHoliday] marks Sundays and public holidays.
List<ArbzgWarning> arbzgWarnings({
  required SpanSet working,
  required BreakEvaluation breaks,
  SpanSet previousDay = SpanSet.empty,
  bool isSundayOrHoliday = false,
}) {
  if (working.isEmpty) return const [];
  return [
    if (breaks.missingBreak > 0)
      ArbzgWarning(ArbzgWarningKind.breakMissing, breaks.missingBreak),
    if (breaks.workOver6hWithoutBreak)
      ArbzgWarning(
        ArbzgWarningKind.workOver6hWithoutBreak,
        breaks.longestStretch,
      ),
    if (breaks.worked > maxDailyWorkMinutes)
      ArbzgWarning(ArbzgWarningKind.over10h, breaks.worked),
    if (previousDay.spans.isNotEmpty)
      if (working.spans.first.start - previousDay.spans.last.end case final rest
          when rest < minRestMinutes)
        ArbzgWarning(ArbzgWarningKind.restUnder11h, rest),
    if (isSundayOrHoliday)
      ArbzgWarning(ArbzgWarningKind.sundayOrHolidayWork, breaks.worked),
  ];
}
