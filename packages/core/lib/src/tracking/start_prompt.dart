import '../data/settings.dart';
import '../model/attendance.dart';
import '../sync/change.dart';
import '../sync/store.dart';
import '../time/home_time_zone.dart';
import '../time/local_date.dart';
import '../time/span.dart';
import 'quick_actions.dart';

/// The question after signing in on the work PC: "Start tracking for today?"
/// (spec: work-pc.md). Whether to ask, where to clock in, and "not today",
/// which is device-local (`local_values`) and never synced.
final class StartPrompt {
  /// Creates the prompt on [store]. [now] is injectable for tests.
  StartPrompt(this.store, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  /// Where rows and the "not today" date are kept.
  final SyncStore store;

  final DateTime Function() _now;

  /// `local_values` key of the day the user answered "not today".
  static const declinedKey = 'start_prompt_declined';

  /// The location to offer, or `null` if nothing needs asking: clocked in,
  /// worked today already, or "not today" was answered today (§2).
  Future<WorkLocation?> offer() => store.transaction((tx) async {
    final rows = [
      for (final t in const ['settings', 'work_sessions', 'days'])
        ...await tx.rows(t),
    ];
    final settings = AppSettings.fromRows(rows);
    final now = _now();
    final today = HomeTimeZone(settings.homeTimeZone).dateOf(now);
    if (await tx.localValue(declinedKey) == '$today') return null;
    if (trackedToday(rows, settings, now)) return null;
    return defaultClockInLocation(rows, settings, now);
  });

  /// Remembers "not today" for today's date.
  Future<void> decline() => store.transaction((tx) async {
    final rows = await tx.rows('settings');
    final zone = HomeTimeZone(AppSettings.fromRows(rows).homeTimeZone);
    await tx.setLocalValue(declinedKey, '${zone.dateOf(_now())}');
  });
}

/// Whether a work session runs now or overlapped today (home time zone),
/// e.g. one started on the phone or the night before.
bool trackedToday(
  Iterable<StoredRow> rows,
  AppSettings settings,
  DateTime now,
) {
  final zone = HomeTimeZone(settings.homeTimeZone);
  final day = zone.daySpan(zone.dateOf(now));
  for (final r in rows) {
    if (r.table != 'work_sessions' || r.isDeleted) continue;
    final start = DateTime.tryParse('${r.fields['start_utc']}');
    if (start == null) continue;
    final endWire = r.fields['end_utc'];
    if (endWire == null) return true; // clocked in
    final end = DateTime.tryParse('$endWire');
    if (end == null) continue;
    if (epochMinute(start) < day.end && epochMinute(end) > day.start) {
      return true;
    }
  }
  return false;
}

/// Where clocking in goes: today's picked day type (office or home office,
/// §15), else the location of the most recent session.
WorkLocation defaultClockInLocation(
  Iterable<StoredRow> rows,
  AppSettings settings,
  DateTime now,
) => dayTypeLocation(rows, settings, now) ?? lastLocation(rows);

/// The location of today's picked day type, if it names one.
WorkLocation? dayTypeLocation(
  Iterable<StoredRow> rows,
  AppSettings settings,
  DateTime now,
) {
  final LocalDate today = HomeTimeZone(settings.homeTimeZone).dateOf(now);
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
