import '../model/planning.dart';
import '../time/local_date.dart';
import 'ledger.dart';

/// Working days that, taken as vacation, join two free blocks around a
/// holiday (spec: calculations.md §10.1).
final class BridgeSuggestion {
  /// Creates a suggestion.
  const BridgeSuggestion({
    required this.vacationDays,
    required this.daysUsed,
    required this.freeFrom,
    required this.freeTo,
  });

  /// The working days to take off.
  final List<LocalDate> vacationDays;

  /// The vacation days they use: half on Heiligabend and Silvester (§6.1,
  /// §10).
  final double daysUsed;

  /// First free day of the joined block.
  final LocalDate freeFrom;

  /// Last free day of the joined block.
  final LocalDate freeTo;

  /// Days off in a row once [vacationDays] are taken.
  int get freeDays => freeFrom.daysUntil(freeTo) + 1;
}

/// The bridges of [year] from [today] on, best ratio first
/// (spec: calculations.md §10.1).
List<BridgeSuggestion> bridgeDays(
  Ledger ledger,
  int year, {
  required LocalDate today,
}) {
  const maxGap = 3;
  final fullDay = <LocalDate, AbsenceKind>{
    for (final a in ledger.data.absences)
      if (a.fraction >= 1) a.date: a.kind,
  };
  bool free(LocalDate d) =>
      ledger.targets.targetMinutes(d) == 0 || fullDay.containsKey(d);
  bool holiday(LocalDate d) =>
      ledger.holidays.isHoliday(d) || fullDay[d] == AbsenceKind.extraHoliday;

  // Runs of free and working days, a little past the year's ends so blocks
  // over New Year are whole.
  final runs = <({bool free, LocalDate from, LocalDate to, bool holiday})>[];
  final last = LocalDate(year, 12, 31).addDays(10);
  for (
    var d = LocalDate(year, 1, 1).addDays(-10);
    !d.isAfter(last);
    d = d.addDays(1)
  ) {
    final f = free(d);
    final h = f && holiday(d);
    if (runs.isNotEmpty && runs.last.free == f) {
      final r = runs.removeLast();
      runs.add((free: f, from: r.from, to: d, holiday: r.holiday || h));
    } else {
      runs.add((free: f, from: d, to: d, holiday: h));
    }
  }

  final result = <BridgeSuggestion>[];
  for (var i = 1; i < runs.length - 1; i++) {
    final gap = runs[i], before = runs[i - 1], after = runs[i + 1];
    if (gap.free || gap.from.daysUntil(gap.to) + 1 > maxGap) continue;
    if (!before.holiday && !after.holiday) continue;
    if (gap.from.year != year || gap.to.year != year) continue;
    if (gap.from.isBefore(today)) continue;
    final days = [
      for (var d = gap.from; !d.isAfter(gap.to); d = d.addDays(1)) d,
    ];
    result.add(
      BridgeSuggestion(
        vacationDays: days,
        daysUsed: days.fold(
          0.0,
          (sum, d) => sum + ledger.targets.usedDays(d, 1),
        ),
        freeFrom: before.from,
        freeTo: after.to,
      ),
    );
  }
  double ratio(BridgeSuggestion s) => s.freeDays / s.daysUsed;
  return result..sort((a, b) {
    final r = ratio(b).compareTo(ratio(a));
    return r != 0 ? r : a.vacationDays.first.compareTo(b.vacationDays.first);
  });
}
