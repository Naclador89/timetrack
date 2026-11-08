import '../time/local_date.dart';
import '../time/span.dart';
import 'arbzg.dart';
import 'home_office.dart';
import 'ledger.dart';

/// Kinds of entries in the Review list (spec: calculations.md §12).
enum ReviewKind {
  /// A session has been open for longer than the limit (forgotten clock-out?).
  openSessionTooLong,

  /// Sessions overlap (harmless to totals, but probably a mistake or a sync conflict).
  overlappingSessions,

  /// Project entries overlap each other.
  overlappingProjectEntries,

  /// Project time outside working time, e.g. during a break.
  projectOutsideSession,

  /// More project time than worked time on a day (calculations.md §3).
  projectOverWork,

  /// A Working Hours Act warning; see [ReviewItem.arbzg].
  arbzg,

  /// Another home-office day would exceed a quota (§11.4).
  homeOfficeQuota,

  /// Worked time without a project on a finished day (§3, §12; only with
  /// `includeUnassigned`).
  unassigned,
}

/// One entry of the Review list. Computed, never stored.
final class ReviewItem {
  /// Creates an item.
  const ReviewItem({
    required this.date,
    required this.kind,
    this.minutes = 0,
    this.arbzg,
    this.refId,
  });

  /// The day the item belongs to (for quotas: the first day of the period).
  final LocalDate date;

  /// What is unusual.
  final ReviewKind kind;

  /// Relevant minutes: open time, minutes outside work, or the warning's minutes.
  final int minutes;

  /// The Working Hours Act warning for [ReviewKind.arbzg].
  final ArbzgWarningKind? arbzg;

  /// Id of the row concerned (open session id, quota rule id), if any.
  final String? refId;

  @override
  String toString() =>
      'ReviewItem($date, ${kind.name}${arbzg == null ? '' : '/${arbzg!.name}'}, $minutes)';
}

/// The Review list for the days [from]–[to] (spec: calculations.md §12).
///
/// [openSessionLimitMinutes] is the setting for "open session over 12 h";
/// [quotas] are the evaluated home-office quotas to check (§11.4).
List<ReviewItem> reviewItems(
  Ledger ledger, {
  required LocalDate from,
  required LocalDate to,
  int openSessionLimitMinutes = 720,
  List<HomeOfficeQuota> quotas = const [],
  bool includeUnassigned = false,
  int unassignedMinMinutes = 1,
}) {
  final items = <ReviewItem>[];
  final running = ledger.data.sessions.any((s) => s.isOpen);
  for (final s in ledger.data.sessions) {
    if (!s.isOpen) continue;
    final open = ledger.nowMinute - epochMinute(s.start);
    if (open > openSessionLimitMinutes) {
      items.add(
        ReviewItem(
          date: ledger.zone.dateOf(s.start),
          kind: ReviewKind.openSessionTooLong,
          minutes: open,
          refId: s.id,
        ),
      );
    }
  }
  for (var d = from; !d.isAfter(to); d = d.addDays(1)) {
    final day = ledger.day(d);
    final work = day.work;
    if (work.overlappingSessions) {
      items.add(ReviewItem(date: d, kind: ReviewKind.overlappingSessions));
    }
    if (work.overlappingProjectEntries) {
      items.add(
        ReviewItem(date: d, kind: ReviewKind.overlappingProjectEntries),
      );
    }
    if (work.projectOutsideWork > 0) {
      items.add(
        ReviewItem(
          date: d,
          kind: ReviewKind.projectOutsideSession,
          minutes: work.projectOutsideWork,
        ),
      );
    }
    if (work.projectOverWork > 0) {
      items.add(
        ReviewItem(
          date: d,
          kind: ReviewKind.projectOverWork,
          minutes: work.projectOverWork,
        ),
      );
    }
    // Only once the day is done: while clocked in it grows by the minute.
    // Trip days record no project time (§3, §15).
    if (includeUnassigned &&
        !day.isTripDay &&
        day.unassigned > 0 &&
        day.unassigned >= unassignedMinMinutes &&
        !(running && d == ledger.today)) {
      items.add(
        ReviewItem(
          date: d,
          kind: ReviewKind.unassigned,
          minutes: day.unassigned,
        ),
      );
    }
    for (final w in day.warnings) {
      items.add(
        ReviewItem(
          date: d,
          kind: ReviewKind.arbzg,
          arbzg: w.kind,
          minutes: w.minutes,
        ),
      );
    }
  }
  for (final q in quotas) {
    if (q.nextDayExceeds) {
      items.add(
        ReviewItem(
          date: q.start,
          kind: ReviewKind.homeOfficeQuota,
          refId: q.rule.id,
        ),
      );
    }
  }
  // List.sort isn't stable; keep the insertion order within a day.
  final indexed = [for (var i = 0; i < items.length; i++) (i, items[i])]
    ..sort((a, b) {
      final byDate = a.$2.date.compareTo(b.$2.date);
      return byDate != 0 ? byDate : a.$1.compareTo(b.$1);
    });
  return [for (final (_, item) in indexed) item];
}

/// Where to put a missing break of [minutes] on [day] (§4, Review fix): in
/// the middle of the longest working stretch, on a 5-minute grid. `null`
/// without working time.
Span? suggestBreak(DayResult day, int minutes) {
  final spans = day.work.working.spans;
  if (spans.isEmpty) return null;
  final longest = spans.reduce((a, b) => b.length > a.length ? b : a);
  final start = (longest.start + (longest.length - minutes) ~/ 2) ~/ 5 * 5;
  return Span(start, start + minutes);
}
