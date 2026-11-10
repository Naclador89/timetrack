import '../time/local_date.dart';
import 'arbzg.dart';
import 'ledger.dart';

/// Kinds of pattern hints in the month report (spec: calculations.md §23).
enum PatternKind {
  /// Days with too little break (§4 findings), from 2 days.
  missingBreak,

  /// Days over 10 hours of work (§3 finding).
  longDays,

  /// Less than 11 h rest before the day (§5 finding).
  shortRest,

  /// Work on Sundays or public holidays.
  sundayWork,

  /// Work ending after 20:00, from 3 days.
  lateFinish,

  /// The positive one: at least 10 workdays and every break kept.
  allBreaksKept,
}

/// One pattern of a month with the days it was seen on.
typedef MonthPattern = ({PatternKind kind, List<LocalDate> days});

/// The pattern hints of the month starting [month], up to today
/// (spec: calculations.md §23). Only existing day results and their
/// Working Hours Act findings count; nothing is a new rule.
List<MonthPattern> monthPatterns(Ledger ledger, LocalDate month) {
  final first = month.startOfMonth;
  final next = first.addDays(31).startOfMonth;
  final today = ledger.today;
  final found = {for (final k in PatternKind.values) k: <LocalDate>[]};
  var workdays = 0;
  for (var d = first; d.isBefore(next) && !d.isAfter(today); d = d.addDays(1)) {
    final day = ledger.day(d);
    final spans = day.work.working.spans;
    if (spans.isEmpty) continue;
    workdays++;
    final kinds = {for (final w in day.warnings) w.kind};
    if (kinds.contains(ArbzgWarningKind.breakMissing) ||
        kinds.contains(ArbzgWarningKind.workOver6hWithoutBreak)) {
      found[PatternKind.missingBreak]!.add(d);
    }
    if (kinds.contains(ArbzgWarningKind.over10h)) {
      found[PatternKind.longDays]!.add(d);
    }
    if (kinds.contains(ArbzgWarningKind.restUnder11h)) {
      found[PatternKind.shortRest]!.add(d);
    }
    if (kinds.contains(ArbzgWarningKind.sundayOrHolidayWork)) {
      found[PatternKind.sundayWork]!.add(d);
    }
    // Today's open session isn't a finish yet.
    final finished = d != today || spans.last.end < ledger.nowMinute;
    if (finished &&
        spans.last.end - ledger.zone.daySpan(d).start > _lateFinish) {
      found[PatternKind.lateFinish]!.add(d);
    }
  }
  if (workdays >= 10 && found[PatternKind.missingBreak]!.isEmpty) {
    found[PatternKind.allBreaksKept]!.add(first);
  }
  return [
    for (final MapEntry(key: kind, value: days) in found.entries)
      if (days.length >= _minDays[kind]!) (kind: kind, days: days),
  ];
}

/// 20:00 in minutes after midnight.
const _lateFinish = 20 * 60;

/// From how many days a pattern is worth a hint.
const _minDays = {
  PatternKind.missingBreak: 2,
  PatternKind.longDays: 1,
  PatternKind.shortRest: 1,
  PatternKind.sundayWork: 1,
  PatternKind.lateFinish: 3,
  PatternKind.allBreaksKept: 1,
};
