import '../model/planning.dart';
import '../time/local_date.dart';
import 'target.dart';

/// Absences of one kind and share of the day in a row, joined only by free
/// days (spec: calculations.md §10.4), e.g. a vacation from Monday to the
/// Friday after next.
final class AbsenceBlock {
  /// Creates a block of [absences] (at least one, by date).
  const AbsenceBlock({required this.absences, required this.days});

  /// The absences, oldest first.
  final List<Absence> absences;

  /// The days it counts, each date once: the fractions, at most what is
  /// left to work that day ([TargetCalendar.usedDays]); for a kind that
  /// reduces the target itself (`extra_holiday`, `short_time`), the
  /// fractions on scheduled days that aren't holidays.
  final double days;

  /// What kind of absence it is.
  AbsenceKind get kind => absences.first.kind;

  /// Whether these are half days.
  bool get half => absences.first.fraction < 1;

  /// First day.
  LocalDate get start => absences.first.date;

  /// Last day.
  LocalDate get end => absences.last.date;
}

/// [absences] as blocks, oldest first (spec: calculations.md §10.4): the
/// next absence joins a block when it has the same kind and share of the
/// day and every date in between is free (target 0) in [targets].
List<AbsenceBlock> absenceBlocks(
  Iterable<Absence> absences,
  TargetCalendar targets,
) {
  final sorted = [...absences]..sort((a, b) => a.date.compareTo(b.date));
  final blocks = <List<Absence>>[];
  for (final a in sorted) {
    final last = blocks.isEmpty ? null : blocks.last.last;
    if (last != null &&
        last.kind == a.kind &&
        (last.fraction < 1) == (a.fraction < 1) &&
        _freeBetween(last.date, a.date, targets)) {
      blocks.last.add(a);
    } else {
      blocks.add([a]);
    }
  }
  return [
    for (final b in blocks) AbsenceBlock(absences: b, days: _days(b, targets)),
  ];
}

/// The days a block uses: rows of one date count once, as in the vacation
/// account (§10). Kinds that reduce the target count on scheduled days only.
double _days(List<Absence> block, TargetCalendar targets) {
  final byDate = <LocalDate, double>{};
  for (final a in block) {
    byDate[a.date] = (byDate[a.date] ?? 0) + a.fraction;
  }
  var days = 0.0;
  for (final MapEntry(key: date, value: sum) in byDate.entries) {
    final fraction = sum.clamp(0.0, 1.0);
    if (!block.first.kind.reducesTarget) {
      days += targets.usedDays(date, fraction);
    } else if (targets.scheduledMinutes(date) > 0 &&
        !targets.holidays.isHoliday(date)) {
      days += fraction;
    }
  }
  return days;
}

bool _freeBetween(LocalDate a, LocalDate b, TargetCalendar targets) {
  for (var d = a.addDays(1); d.isBefore(b); d = d.addDays(1)) {
    if (targets.isWorkday(d)) return false;
  }
  return true;
}
