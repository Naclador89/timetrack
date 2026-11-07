import 'dart:convert';

import '../data/settings.dart';
import '../model/attendance.dart';
import '../rules/ledger.dart';
import '../sync/change.dart';
import '../sync/repository.dart';
import '../sync/store.dart';
import '../time/home_time_zone.dart';
import '../time/local_date.dart';
import '../time/span.dart';
import 'time_tracker.dart';

/// A one-tap command from outside the app UI: the Android notification, the
/// Quick Settings tile and the home-screen widget (concept §6 E1), later the
/// watch. They arrive as URIs `timetrack://quick/<name>`.
enum QuickAction {
  /// Clock in if clocked out, else clock out (the tile).
  toggle,

  /// Clock in at the last used location.
  clockIn,

  /// Clock out.
  clockOut,

  /// Start a break if working, end it if on a break.
  toggleBreak;

  /// The URI that triggers this action.
  Uri get uri => Uri(scheme: 'timetrack', host: 'quick', path: '/$name');

  /// The action named by [uri], or `null` for anything else.
  static QuickAction? parse(Uri? uri) {
    if (uri == null || uri.scheme != 'timetrack' || uri.host != 'quick') {
      return null;
    }
    final name = uri.pathSegments.isEmpty ? '' : uri.pathSegments.first;
    for (final a in values) {
      if (a.name == name) return a;
    }
    return null;
  }
}

/// Runs [action] like the matching buttons on the Today screen.
///
/// Returns the id of the project entry the action stopped, if any. The UI
/// always asks for a summary when a project timer ends (docs/status.md);
/// outside the app it can't, so the id is queued with [PendingSummaries] and
/// asked for when the app opens next.
Future<String?> runQuickAction(
  SyncedRepository repository,
  QuickAction action, {
  DateTime Function()? now,
}) async {
  final rows = await repository.store.transaction(
    (tx) async => [
      for (final t in const ['settings', 'work_sessions', 'days'])
        ...await tx.rows(t),
    ],
  );
  final settings = AppSettings.fromRows(rows);
  final tracker = TimeTracker(
    repository,
    now: now,
    autoClockIn: settings.autoClockIn,
    resumeAfterBreak: settings.resumeAfterBreak,
  );
  final before = await tracker.state();
  switch (action) {
    case QuickAction.toggle when before.clockedIn:
    case QuickAction.clockOut:
      await tracker.clockOut();
    case QuickAction.toggle:
    case QuickAction.clockIn:
      await tracker.clockIn(
        location:
            _dayLocation(rows, settings, (now ?? DateTime.now)()) ??
            lastLocation(rows),
      );
    case QuickAction.toggleBreak:
      before.onBreak ? await tracker.endBreak() : await tracker.startBreak();
  }
  final stopped = before.entry;
  if (stopped == null) return null;
  final after = await repository.get('project_entries', stopped.id);
  if (after?.fields['end_utc'] == null) return null;
  await PendingSummaries(repository.store).add(stopped.id);
  return stopped.id;
}

/// The location of today's picked day type (office or home office, §15).
WorkLocation? _dayLocation(
  Iterable<StoredRow> rows,
  AppSettings settings,
  DateTime now,
) {
  final today = HomeTimeZone(settings.homeTimeZone).dateOf(now);
  for (final r in rows) {
    if (r.table != 'days' || r.id != '$today' || r.isDeleted) continue;
    return switch (r.fields['type']) {
      'office' => WorkLocation.office,
      'home' => WorkLocation.home,
      _ => null,
    };
  }
  return null;
}

/// The location of the most recent session (the default for clocking in,
/// like the Today screen), or office.
WorkLocation lastLocation(Iterable<StoredRow> rows) {
  StoredRow? latest;
  for (final r in rows) {
    if (r.table != 'work_sessions' || r.isDeleted) continue;
    final start = r.fields['start_utc'];
    if (start is! String) continue;
    if (latest == null ||
        start.compareTo(latest.fields['start_utc']! as String) > 0) {
      latest = r;
    }
  }
  final wire = latest?.fields['location'];
  try {
    return wire is String ? WorkLocation.parse(wire) : WorkLocation.office;
  } on ArgumentError {
    return WorkLocation.office;
  }
}

/// Project entries stopped outside the app whose summary the app still has
/// to ask for. Device-local (`local_values`), never synced.
final class PendingSummaries {
  /// Creates the queue on [store].
  const PendingSummaries(this.store);

  /// Where the queue is kept.
  final SyncStore store;

  static const _key = 'pending_summaries';

  /// Queues [entryId].
  Future<void> add(String entryId) => store.transaction((tx) async {
    final ids = _decode(await tx.localValue(_key));
    if (!ids.contains(entryId)) ids.add(entryId);
    await tx.setLocalValue(_key, jsonEncode(ids));
  });

  /// Returns the queued ids, oldest first, and empties the queue.
  Future<List<String>> take() => store.transaction((tx) async {
    final ids = _decode(await tx.localValue(_key));
    if (ids.isNotEmpty) await tx.setLocalValue(_key, null);
    return ids;
  });

  static List<String> _decode(String? raw) =>
      raw == null ? [] : (jsonDecode(raw) as List).cast<String>();
}

/// What the notification, tile and widget show (Android quick access).
enum QuickPhase {
  /// Not clocked in.
  off,

  /// Clocked in, no break.
  working,

  /// On a break.
  onBreak,
}

/// A snapshot of the tracker for displays outside the app, which tick on
/// their own (Android `Chronometer`) instead of being updated every minute.
final class QuickStatus {
  /// Creates a status.
  const QuickStatus({
    required this.phase,
    required this.todayMinutes,
    this.runningSince,
    this.breakSince,
    this.projectId,
    this.location,
  });

  /// Derives the status at [nowMinute] (epoch minutes) for [today].
  factory QuickStatus.of(
    TrackerState state,
    Ledger ledger,
    LocalDate today, {
    required int nowMinute,
  }) {
    final worked = ledger.day(today).work.worked;
    final phase = !state.clockedIn
        ? QuickPhase.off
        : state.onBreak
        ? QuickPhase.onBreak
        : QuickPhase.working;
    final breakStart = state.breakRow?.fields['start_utc'];
    return QuickStatus(
      phase: phase,
      todayMinutes: worked,
      // While working, today's total grows one minute per minute, so this
      // stays constant and a stopwatch started then shows the total.
      runningSince: phase == QuickPhase.working ? nowMinute - worked : null,
      breakSince: phase == QuickPhase.onBreak && breakStart is String
          ? epochMinute(DateTime.parse(breakStart))
          : null,
      projectId: state.projectId,
      location: state.location,
    );
  }

  /// The current phase.
  final QuickPhase phase;

  /// Minutes worked today so far.
  final int todayMinutes;

  /// While working: the epoch minute from which a stopwatch shows today's
  /// worked time.
  final int? runningSince;

  /// While on a break: when it started (epoch minute).
  final int? breakSince;

  /// The running project, if any.
  final String? projectId;

  /// Location of the open session.
  final WorkLocation? location;

  @override
  bool operator ==(Object other) =>
      other is QuickStatus &&
      other.phase == phase &&
      other.runningSince == runningSince &&
      other.breakSince == breakSince &&
      other.projectId == projectId &&
      other.location == location &&
      // Only meaningful while the stopwatch isn't running.
      (phase == QuickPhase.working || other.todayMinutes == todayMinutes);

  @override
  int get hashCode =>
      Object.hash(phase, runningSince, breakSince, projectId, location);
}
