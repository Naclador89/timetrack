import '../time/span.dart';

/// Where a work session took place (spec: calculations.md §2).
enum WorkLocation {
  /// At the employer's office.
  office,

  /// Working from home (counts towards the home-office quota, §11).
  home,

  /// Working at the destination of a business trip, e.g. at a customer site.
  onSite,

  /// Time in transit on a business trip (train, car, flight; §9).
  travel;

  /// The value used in sync changes and the database (`on_site`, …).
  String get wireName => this == onSite ? 'on_site' : name;

  /// Parses a [wireName].
  static WorkLocation parse(String wireName) => WorkLocation.values.firstWhere(
    (l) => l.wireName == wireName,
    orElse: () =>
        throw ArgumentError.value(wireName, 'wireName', 'Unknown location'),
  );
}

/// A work session (attendance layer): clocked in at [start] until [end].
///
/// Only complete rows become a [WorkSession]; rows still missing required
/// fields after a partial sync are skipped earlier (spec: sync-format.md §6).
final class WorkSession {
  /// Creates a session. [end] is `null` while still clocked in.
  const WorkSession({
    required this.id,
    required this.start,
    this.end,
    required this.location,
  });

  /// Row id (UUIDv7).
  final String id;

  /// Clock-in instant (UTC).
  final DateTime start;

  /// Clock-out instant (UTC), or `null` while clocked in.
  final DateTime? end;

  /// Where the work took place.
  final WorkLocation location;

  /// Whether the session is still running.
  bool get isOpen => end == null;

  /// The session as a span, with an open end evaluated at [nowMinute].
  Span spanAt(int nowMinute) => _spanOf(start, end, nowMinute);
}

/// A break during attendance (spec: calculations.md §2, §4).
///
/// Breaks aren't linked to a session by id: they apply wherever they overlap
/// a session, which keeps sync merges simple (ADR 0002).
final class WorkBreak {
  /// Creates a break. [end] is `null` while the break is running.
  const WorkBreak({required this.id, required this.start, this.end});

  /// Row id (UUIDv7).
  final String id;

  /// Start instant (UTC).
  final DateTime start;

  /// End instant (UTC), or `null` while running.
  final DateTime? end;

  /// The break as a span, with an open end evaluated at [nowMinute].
  Span spanAt(int nowMinute) => _spanOf(start, end, nowMinute);
}

/// Time booked on a project (project layer, spec: calculations.md §3).
final class ProjectEntry {
  /// Creates an entry. [end] is `null` while the project timer runs.
  const ProjectEntry({
    required this.id,
    required this.projectId,
    required this.start,
    this.end,
  });

  /// Row id (UUIDv7).
  final String id;

  /// Id of the project the time is booked on.
  final String projectId;

  /// Start instant (UTC).
  final DateTime start;

  /// End instant (UTC), or `null` while running.
  final DateTime? end;

  /// The entry as a span, with an open end evaluated at [nowMinute].
  Span spanAt(int nowMinute) => _spanOf(start, end, nowMinute);
}

/// Open ends run until now. An end before the start (possible for a moment
/// while a sync is only half applied) is treated as an empty span rather than
/// an error.
Span _spanOf(DateTime start, DateTime? end, int nowMinute) {
  final s = epochMinute(start);
  final e = end == null ? nowMinute : epochMinute(end);
  return Span(s, e > s ? e : s);
}
