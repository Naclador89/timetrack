import '../data/mapping.dart';
import '../data/settings.dart';
import '../rules/forecast.dart';
import '../rules/ledger.dart';
import '../sync/change.dart';
import '../time/local_date.dart';
import '../time/span.dart';
import 'time_tracker.dart';

/// Why a time is suggested as the end of a forgotten session
/// (spec: reminders.md §1).
enum EndSuggestionKind {
  /// The last start or end of a break or project entry in the session.
  lastActivity,

  /// When the session's day reached its target (calculations §18).
  targetReached,

  /// The median end of the last finished sessions.
  usualEnd,
}

/// A suggested end of a forgotten session.
typedef EndSuggestion = ({EndSuggestionKind kind, DateTime at});

/// A session that is still open although it probably shouldn't be.
final class ForgottenSession {
  /// Creates the result; use [forgottenClockOut].
  const ForgottenSession({
    required this.id,
    required this.start,
    required this.suggestions,
  });

  /// The session's row id.
  final String id;

  /// When it started.
  final DateTime start;

  /// Suggested ends, sorted by time.
  final List<EndSuggestion> suggestions;
}

/// The open session if it started before today (home time zone) or has
/// been open longer than the limit, with suggested ends; `null` otherwise
/// (spec: reminders.md §1). [rows] are all synced rows.
ForgottenSession? forgottenClockOut(Iterable<StoredRow> rows, DateTime now) {
  final all = rows.toList();
  final session = TrackerState.fromRows(all).session;
  if (session == null) return null;
  final settings = AppSettings.fromRows(all);
  final ledger = appLedger(all, now);
  final zone = ledger.zone;
  final start = DateTime.parse(session.fields['start_utc']! as String);
  final day = zone.dateOf(start);
  final open = now.difference(start).inMinutes;
  if (!day.isBefore(zone.dateOf(now)) &&
      open <= settings.openSessionLimitMinutes) {
    return null;
  }

  final candidates = <EndSuggestion>[];
  // Last activity: breaks and project entries inside the session.
  DateTime? last;
  for (final r in all) {
    if (r.isDeleted || (r.table != 'breaks' && r.table != 'project_entries')) {
      continue;
    }
    for (final field in const ['start_utc', 'end_utc']) {
      final v = r.fields[field];
      if (v is! String) continue;
      final t = DateTime.parse(v);
      if (t.isAfter(start) && (last == null || t.isAfter(last))) last = t;
    }
  }
  if (last != null) {
    candidates.add((kind: EndSuggestionKind.lastActivity, at: last));
  }
  // Target reached: the forecast at the session start.
  final atStart = appLedger(all, start);
  final target = dayForecast(atStart.day(day), now: start).targetAt;
  if (target != null) {
    candidates.add((kind: EndSuggestionKind.targetReached, at: target));
  }
  // Usual end: the median local end of the last 20 finished sessions.
  final ends =
      ledger.data.sessions
          .where((s) => s.id != session.id && s.end != null)
          .map((s) => s.end!)
          .toList()
        ..sort();
  final recent = ends.length > 20 ? ends.sublist(ends.length - 20) : ends;
  if (recent.isNotEmpty) {
    final minutes = recent.map((e) {
      final local = zone.toLocal(e);
      return local.hour * 60 + local.minute;
    }).toList()..sort();
    final m = minutes[minutes.length ~/ 2];
    candidates.add((
      kind: EndSuggestionKind.usualEnd,
      at: zone.instantAt(day, m ~/ 60, m % 60),
    ));
  }

  final seen = <int>{};
  final suggestions =
      candidates
          .where((c) => c.at.isAfter(start) && !c.at.isAfter(now))
          .where((c) => seen.add(epochMinute(c.at)))
          .toList()
        ..sort((a, b) => a.at.compareTo(b.at));
  return ForgottenSession(
    id: session.id,
    start: start,
    suggestions: suggestions,
  );
}

/// Kinds of reminders (spec: reminders.md §2).
enum ReminderKind {
  /// 5:45 h without a countable break.
  breakDue,

  /// 9:45 h of work today.
  longDay;

  /// The wire name used in keys.
  String get wire => switch (this) {
    breakDue => 'break_due',
    longDay => 'long_day',
  };
}

/// A reminder due at [at]; [key] identifies it so it is shown once.
typedef Reminder = ({ReminderKind kind, DateTime at, String key});

/// The reminders of [today] while working, with their due instants (now or
/// later), as far as [settings] switch them on (spec: reminders.md §2).
List<Reminder> nextReminders(
  Ledger ledger,
  TrackerState state,
  LocalDate today,
  AppSettings settings,
) {
  if (!state.clockedIn || state.onBreak) return const [];
  final now = ledger.nowMinute;
  DateTime due(int remaining) =>
      instantOfEpochMinute(now + (remaining > 0 ? remaining : 0));
  final work = ledger.day(today).work;
  final result = <Reminder>[];
  if (settings.remindBreak && work.working.spans.isNotEmpty) {
    // The current stretch: working spans not separated by a gap ≥ 15 min.
    final spans = work.working.spans;
    var stretchStart = spans.last.start;
    var stretch = 0;
    for (var i = spans.length - 1; i >= 0; i--) {
      stretch += spans[i].length;
      stretchStart = spans[i].start;
      if (i > 0 && spans[i].start - spans[i - 1].end >= 15) break;
    }
    result.add((
      kind: ReminderKind.breakDue,
      at: due(345 - stretch),
      key: '$today/${ReminderKind.breakDue.wire}/$stretchStart',
    ));
  }
  if (settings.remindLongDay) {
    result.add((
      kind: ReminderKind.longDay,
      at: due(585 - work.worked),
      key: '$today/${ReminderKind.longDay.wire}',
    ));
  }
  return result;
}
