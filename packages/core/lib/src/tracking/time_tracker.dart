import '../model/attendance.dart';
import '../sync/change.dart';
import '../sync/repository.dart';

/// The current attendance state, derived from the stored rows.
final class TrackerState {
  /// Creates a state.
  const TrackerState({this.session, this.breakRow, this.entry, this.trip});

  /// Derives the state from stored rows of any tables (others are ignored).
  factory TrackerState.fromRows(Iterable<StoredRow> rows) {
    StoredRow? latestOpen(String table, String startField, String endField) {
      StoredRow? best;
      for (final r in rows) {
        if (r.table != table || r.isDeleted) continue;
        final start = r.fields[startField];
        if (start is! String || r.fields[endField] != null) continue;
        if (best == null ||
            start.compareTo(best.fields[startField]! as String) > 0) {
          best = r;
        }
      }
      return best;
    }

    return TrackerState(
      session: latestOpen('work_sessions', 'start_utc', 'end_utc'),
      breakRow: latestOpen('breaks', 'start_utc', 'end_utc'),
      entry: latestOpen('project_entries', 'start_utc', 'end_utc'),
      trip: latestOpen('trips', 'depart_utc', 'return_utc'),
    );
  }

  /// The open work session (still clocked in), if any.
  final StoredRow? session;

  /// The running break, if any.
  final StoredRow? breakRow;

  /// The running project entry, if any.
  final StoredRow? entry;

  /// The open trip, if any.
  final StoredRow? trip;

  /// Whether the user is clocked in.
  bool get clockedIn => session != null;

  /// Whether a break is running.
  bool get onBreak => breakRow != null;

  /// Location of the open session.
  WorkLocation? get location {
    final wire = session?.fields['location'];
    return wire is String ? WorkLocation.parse(wire) : null;
  }

  /// Project id of the running entry.
  String? get projectId => entry?.fields['project_id'] as String?;
}

/// Formats [instant] the way instants are stored: UTC, minute precision
/// (spec: calculations.md §1, data-model.md).
String isoMinute(DateTime instant) {
  final u = instant.toUtc();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${u.year.toString().padLeft(4, '0')}-${two(u.month)}-${two(u.day)}'
      'T${two(u.hour)}:${two(u.minute)}:00Z';
}

/// The commands behind the clock-in, break and project buttons. They keep the
/// two layers consistent (concept §2, "How the two layers interact"):
///
/// - starting a project while clocked out clocks in (if [autoClockIn]);
/// - clocking out stops the running project and break;
/// - a break stops the running project; ending it can resume that project;
/// - only one session, break and project entry run at a time.
///
/// Every write goes through [repository], so it syncs.
final class TimeTracker {
  /// Creates a tracker. [now] is injectable for tests.
  TimeTracker(
    this.repository, {
    DateTime Function()? now,
    this.autoClockIn = true,
    this.resumeAfterBreak = true,
  }) : _now = now ?? DateTime.now;

  /// Where all writes go.
  final SyncedRepository repository;

  /// Setting `auto_clock_in`.
  final bool autoClockIn;

  /// Setting `resume_after_break`.
  final bool resumeAfterBreak;

  final DateTime Function() _now;

  String get _stamp => isoMinute(_now());

  /// Reads the current state.
  Future<TrackerState> state() => repository.store.transaction(
    (tx) async => TrackerState.fromRows([
      for (final t in const [
        'work_sessions',
        'breaks',
        'project_entries',
        'trips',
      ])
        ...await tx.rows(t),
    ]),
  );

  /// Clocks in at [location]. Does nothing if already clocked in at that
  /// location; switches the location (new session) if clocked in elsewhere.
  Future<void> clockIn({WorkLocation location = WorkLocation.office}) async {
    final s = await state();
    if (s.clockedIn) {
      if (s.location != location) await changeLocation(location);
      return;
    }
    await _openSession(location);
  }

  /// Clocks out: ends the running break and project entry, then the session.
  Future<void> clockOut() async {
    final s = await state();
    final at = _stamp;
    if (s.breakRow != null) await _end('breaks', s.breakRow!, at);
    if (s.entry != null) await _end('project_entries', s.entry!, at);
    if (s.session != null) await _end('work_sessions', s.session!, at);
  }

  /// Starts a break (clocked in only). Stops the running project entry.
  Future<void> startBreak() async {
    final s = await state();
    if (!s.clockedIn || s.onBreak) return;
    final at = _stamp;
    if (s.entry != null) await _end('project_entries', s.entry!, at);
    await repository.write('breaks', repository.newId(), {
      'start_utc': at,
      'end_utc': null,
    });
  }

  /// Ends the running break and, if [resumeAfterBreak], restarts the project
  /// that ran until the break started.
  Future<void> endBreak() async {
    final s = await state();
    final b = s.breakRow;
    if (b == null) return;
    await _end('breaks', b, _stamp);
    if (!resumeAfterBreak || s.entry != null) return;
    final previous = await _entryEndedAt(b.fields['start_utc']! as String);
    if (previous != null) {
      await _startEntry(previous.fields['project_id']! as String);
    }
  }

  /// Starts [projectId], stopping any other running project. Clocks in first
  /// if needed (and [autoClockIn]), and ends a running break.
  Future<void> startProject(String projectId, {WorkLocation? location}) async {
    var s = await state();
    if (!s.clockedIn) {
      if (!autoClockIn) {
        throw StateError('Not clocked in and auto clock-in is off');
      }
      await _openSession(location ?? WorkLocation.office);
      s = await state();
    }
    final at = _stamp;
    if (s.breakRow != null) await _end('breaks', s.breakRow!, at);
    if (s.projectId == projectId) return;
    if (s.entry != null) await _end('project_entries', s.entry!, at);
    await _startEntry(projectId);
  }

  /// Stops the running project entry (attendance continues).
  Future<void> stopProject() async {
    final s = await state();
    if (s.entry != null) await _end('project_entries', s.entry!, _stamp);
  }

  /// Changes the location while clocked in: the current session ends now and
  /// a new one starts with [location] (location is per session, ADR 0002).
  Future<void> changeLocation(WorkLocation location) async {
    final s = await state();
    if (s.session == null || s.location == location) return;
    await _end('work_sessions', s.session!, _stamp);
    await _openSession(location);
  }

  /// Starts a business trip now (spec: calculations.md §9).
  Future<String> startTrip({
    String destination = '',
    String country = 'DE',
    bool overnight = true,
  }) async {
    final id = repository.newId();
    await repository.write('trips', id, {
      'depart_utc': _stamp,
      'return_utc': null,
      'destination': destination,
      'country': country,
      'overnight': overnight,
    });
    return id;
  }

  /// Ends the open trip now.
  Future<void> endTrip() async {
    final s = await state();
    if (s.trip == null) return;
    await repository.write('trips', s.trip!.id, {'return_utc': _stamp});
  }

  Future<void> _openSession(WorkLocation location) =>
      repository.write('work_sessions', repository.newId(), {
        'start_utc': _stamp,
        'end_utc': null,
        'location': location.wireName,
        'source': 'app',
      });

  Future<void> _startEntry(String projectId) =>
      repository.write('project_entries', repository.newId(), {
        'project_id': projectId,
        'start_utc': _stamp,
        'end_utc': null,
        'source': 'app',
      });

  Future<void> _end(String table, StoredRow row, String at) =>
      repository.write(table, row.id, {'end_utc': at});

  Future<StoredRow?> _entryEndedAt(String instant) =>
      repository.store.transaction((tx) async {
        for (final r in await tx.rows('project_entries')) {
          if (!r.isDeleted && r.fields['end_utc'] == instant) return r;
        }
        return null;
      });
}
