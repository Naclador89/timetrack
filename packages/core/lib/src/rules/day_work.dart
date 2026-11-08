import '../model/attendance.dart';
import '../time/local_date.dart';
import '../time/span.dart';

/// Attendance and project time of one calendar day
/// (spec: calculations.md §2 and §3).
///
/// All totals are in minutes and computed on interval unions, so duplicated or
/// overlapping rows never count twice.
final class DayWork {
  /// Creates a day result. Use [evaluateDay] instead of calling this directly.
  const DayWork({
    required this.date,
    required this.working,
    required this.byLocation,
    required this.projectTime,
    required this.byProject,
    required this.overlappingSessions,
    required this.overlappingProjectEntries,
    required this.projectOutsideWork,
    this.projectSpans = SpanSet.empty,
  });

  /// The evaluated day.
  final LocalDate date;

  /// Working intervals `WI(D)`: sessions minus breaks, clipped to the day.
  final SpanSet working;

  /// Worked minutes `W(D)` per location (`W_loc`). Adds up to [worked].
  final Map<WorkLocation, int> byLocation;

  /// Minutes of project time: time spans inside [working] plus durations (§3).
  final int projectTime;

  /// Minutes per project id (spans inside [working] plus durations). They can
  /// add up to more than [projectTime] if spans overlap ([overlappingProjectEntries]).
  final Map<String, int> byProject;

  /// Whether sessions overlap each other (harmless to totals, §2).
  final bool overlappingSessions;

  /// Whether project entries overlap each other (§3).
  final bool overlappingProjectEntries;

  /// Minutes of project time outside [working], e.g. during a break (§3).
  final int projectOutsideWork;

  /// Timed project entries inside [working] (durations have no position).
  final SpanSet projectSpans;

  /// Working intervals without a timed project entry (§3): the gaps the UI
  /// offers to assign. Durations aren't placed, so they don't fill gaps.
  SpanSet get unassignedSpans => working.subtract(projectSpans);

  /// Worked minutes `W(D)`, before any break deduction (§4).
  int get worked => working.length;

  /// Worked minutes not assigned to any project, `U(D)` (never below 0).
  int get unassigned => worked > projectTime ? worked - projectTime : 0;

  /// Project time beyond the worked time (§3, Review `project_over_work`).
  int get projectOverWork => projectTime > worked ? projectTime - worked : 0;

  /// Worked minutes at [location], or 0.
  int workedAt(WorkLocation location) => byLocation[location] ?? 0;
}

/// Evaluates the calendar day [date] whose local span is [day]
/// (from `HomeTimeZone.daySpan`), with open rows running until [nowMinute].
///
/// Pass every row that could touch the day; anything outside [day] is clipped
/// away. Implements spec: calculations.md §2 and §3.
DayWork evaluateDay({
  required LocalDate date,
  required Span day,
  required int nowMinute,
  required List<WorkSession> sessions,
  List<WorkBreak> breaks = const [],
  List<ProjectEntry> entries = const [],
  List<ProjectDuration> durations = const [],
}) {
  final window = SpanSet([day]);
  final breakSet = SpanSet([for (final b in breaks) b.spanAt(nowMinute)])
      .intersect(window);

  // §2: when sessions with different locations overlap, the overlap belongs
  // to the session that started later, so walk them from the latest start.
  final ordered = [...sessions]
    ..sort((a, b) {
      final byStart = b.start.compareTo(a.start);
      return byStart != 0 ? byStart : b.id.compareTo(a.id);
    });
  var claimed = SpanSet.empty;
  final locationSets = <WorkLocation, SpanSet>{};
  var sessionMinutes = 0;
  for (final session in ordered) {
    final own = SpanSet([session.spanAt(nowMinute)]).intersect(window);
    sessionMinutes += own.length;
    final fresh = own.subtract(claimed);
    claimed = claimed.union(fresh);
    locationSets[session.location] =
        (locationSets[session.location] ?? SpanSet.empty).union(fresh);
  }

  final working = claimed.subtract(breakSet);
  final byLocation = <WorkLocation, int>{
    for (final MapEntry(:key, :value) in locationSets.entries)
      key: value.subtract(breakSet).length,
  }..removeWhere((_, minutes) => minutes == 0);

  final clipped = [
    for (final e in entries)
      (e.projectId, SpanSet([e.spanAt(nowMinute)]).intersect(window)),
  ];
  final allProjects = SpanSet([for (final (_, set) in clipped) ...set.spans]);
  final perProject = <String, SpanSet>{};
  var entryMinutes = 0;
  for (final (projectId, set) in clipped) {
    entryMinutes += set.length;
    perProject[projectId] = (perProject[projectId] ?? SpanSet.empty).union(set);
  }
  final byProject = <String, int>{
    for (final MapEntry(:key, :value) in perProject.entries)
      key: value.intersect(working).length,
  };
  var durationMinutes = 0;
  for (final d in durations) {
    if (d.date != date || d.minutes <= 0) continue;
    byProject[d.projectId] = (byProject[d.projectId] ?? 0) + d.minutes;
    durationMinutes += d.minutes;
  }
  byProject.removeWhere((_, minutes) => minutes == 0);

  return DayWork(
    date: date,
    working: working,
    byLocation: byLocation,
    projectTime: allProjects.intersect(working).length + durationMinutes,
    byProject: byProject,
    overlappingSessions: sessionMinutes > claimed.length,
    overlappingProjectEntries: entryMinutes > allProjects.length,
    projectOutsideWork: allProjects.subtract(working).length,
    projectSpans: allProjects.intersect(working),
  );
}
