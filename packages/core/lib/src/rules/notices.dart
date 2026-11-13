import '../sync/change.dart';
import 'arbzg.dart';
import 'review.dart';

/// Groups of Review items the user can switch on and off as cards
/// (calculations.md §12). [openTrip] is not a Review item; the app checks it
/// itself.
enum NoticeCategory {
  /// Worked time without a project.
  unassigned,

  /// Missing break (ArbZG §4).
  breaks,

  /// More than 10 hours (ArbZG §3).
  longDay,

  /// Less than 11 hours rest (ArbZG §5).
  rest,

  /// Work on a Sunday or holiday (ArbZG §9).
  sundayWork,

  /// A session open for very long (forgotten clock-out).
  openSession,

  /// Overlapping sessions or project entries.
  overlaps,

  /// Project time outside working time or above it.
  projectTime,

  /// Home-office quota.
  homeOfficeQuota,

  /// A trip still open while clocked out.
  openTrip,

  /// A project's budget almost or fully used (§3.1).
  projectBudget,

  /// The overtime balance entered a worse zone (§20.1).
  balanceZone,

  /// A week above the weekly limits (§22).
  weekLimit;

  /// The name in the settings key (`notices.show.<wireName>`).
  String get wireName => switch (this) {
    longDay => 'long_day',
    sundayWork => 'sunday_work',
    openSession => 'open_session',
    projectTime => 'project_time',
    homeOfficeQuota => 'home_office_quota',
    openTrip => 'open_trip',
    projectBudget => 'project_budget',
    balanceZone => 'balance_zone',
    weekLimit => 'week_limit',
    _ => name,
  };

  /// The category of [item].
  static NoticeCategory of(ReviewItem item) => switch (item.kind) {
    ReviewKind.unassigned => unassigned,
    ReviewKind.openSessionTooLong => openSession,
    ReviewKind.overlappingSessions ||
    ReviewKind.overlappingProjectEntries => overlaps,
    ReviewKind.projectOutsideSession ||
    ReviewKind.projectOverWork => projectTime,
    ReviewKind.homeOfficeQuota => homeOfficeQuota,
    ReviewKind.projectBudgetNear ||
    ReviewKind.projectBudgetOver => projectBudget,
    ReviewKind.balanceZone => balanceZone,
    ReviewKind.weekOverMax || ReviewKind.weekAverageOver => weekLimit,
    ReviewKind.arbzg => switch (item.arbzg!) {
      ArbzgWarningKind.breakMissing ||
      ArbzgWarningKind.workOver6hWithoutBreak => breaks,
      ArbzgWarningKind.over10h => longDay,
      ArbzgWarningKind.restUnder11h => rest,
      ArbzgWarningKind.sundayOrHolidayWork => sundayWork,
    },
  };
}

/// A stable id of [item]: the row id in `dismissed_notices`
/// (data-model §14), so a dismissal syncs and stays.
String noticeKey(ReviewItem item) =>
    ['${item.date}', item.kind.name, ?item.arbzg?.name, ?item.refId].join('/');

/// The keys of dismissed notices in [rows] (`dismissed_notices`),
/// accepted ones included.
Set<String> dismissedNoticeKeys(Iterable<StoredRow> rows) => {
  for (final r in rows)
    if (r.table == 'dismissed_notices' && !r.isDeleted) r.id,
};

/// The keys of accepted notices in [rows]: dismissed with `accepted`
/// (data-model §14), so they are reported nowhere any more.
Set<String> acceptedNoticeKeys(Iterable<StoredRow> rows) => {
  for (final r in rows)
    if (r.table == 'dismissed_notices' &&
        !r.isDeleted &&
        r.fields['accepted'] == true)
      r.id,
};

/// Splits [items] into the cards to show and the rest (calculations §12):
/// a category switched off ([shows] false) or a dismissed key hides an
/// item; an [accepted] key drops it from both lists. "More than 6 h without
/// a break" is dropped when the same day has the missing-break item (one
/// fix for both, so accepting that one covers both too).
({List<ReviewItem> shown, List<ReviewItem> hidden}) splitNotices(
  List<ReviewItem> items, {
  required bool Function(NoticeCategory) shows,
  required Set<String> dismissed,
  Set<String> accepted = const {},
}) {
  final missingBreak = {
    for (final i in items)
      if (i.arbzg == ArbzgWarningKind.breakMissing) i.date,
  };
  final shown = <ReviewItem>[], hidden = <ReviewItem>[];
  for (final i in items) {
    if (i.arbzg == ArbzgWarningKind.workOver6hWithoutBreak &&
        missingBreak.contains(i.date)) {
      continue;
    }
    if (accepted.contains(noticeKey(i))) continue;
    final visible =
        shows(NoticeCategory.of(i)) && !dismissed.contains(noticeKey(i));
    (visible ? shown : hidden).add(i);
  }
  return (shown: shown, hidden: hidden);
}
