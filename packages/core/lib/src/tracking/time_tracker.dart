import '../model/attendance.dart';
import '../sync/change.dart';
import '../sync/repository.dart';
import '../time/home_time_zone.dart';

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

/// A stamp the user can date back (spec: calculations.md §19).
enum StampAction {
  /// Clocking in (or switching the location, when clocked in elsewhere).
  clockIn,

  /// Clocking out.
  clockOut,

  /// Starting a break.
  startBreak,

  /// Ending the break.
  endBreak,

  /// Ending the session and starting one at another location.
  changeLocation,
}

/// The instant the user means by [hour]:[minute] (home time, [zone]) when
/// stamping at [now] (spec: calculations.md §19): today; yesterday if that
/// is still in the future and [earliest] lies before today (a session that
/// runs past midnight).
DateTime stampInstant(
  HomeTimeZone zone,
  DateTime now,
  int hour,
  int minute, {
  DateTime? earliest,
}) {
  DateTime utc(DateTime t) => DateTime.fromMillisecondsSinceEpoch(
    t.millisecondsSinceEpoch,
    isUtc: true,
  );
  final today = zone.dateOf(now);
  final at = utc(zone.instantAt(today, hour, minute));
  if (isoMinute(at).compareTo(isoMinute(now)) <= 0 ||
      earliest == null ||
      !zone.dateOf(earliest).isBefore(today)) {
    return at;
  }
  return utc(zone.instantAt(today.addDays(-1), hour, minute));
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

  Future<List<StoredRow>> _rows() => repository.store.transaction(
    (tx) async => [
      for (final t in const [
        'work_sessions',
        'breaks',
        'project_entries',
        'trips',
      ])
        ...await tx.rows(t),
    ],
  );

  /// Reads the current state.
  Future<TrackerState> state() async => TrackerState.fromRows(await _rows());

  /// The earliest instant [action] may be dated back to; `null` if there is
  /// no lower bound (spec: calculations.md §19).
  Future<DateTime?> earliestAt(StampAction action) async {
    final rows = await _rows();
    final s = TrackerState.fromRows(rows);
    String? latest(Iterable<Object?> values) {
      String? best;
      for (final v in values) {
        if (v is String && (best == null || v.compareTo(best) > 0)) best = v;
      }
      return best;
    }

    final sessionStart = s.session?.fields['start_utc'] as String?;
    // Breaks and project entries of the open session that already ended.
    Iterable<Object?> closedInSession() => [
      if (sessionStart != null)
        for (final r in rows)
          if (!r.isDeleted &&
              (r.table == 'breaks' || r.table == 'project_entries') &&
              r.fields['end_utc'] is String &&
              (r.fields['start_utc'] as String? ?? '').compareTo(
                    sessionStart,
                  ) >=
                  0)
            r.fields['end_utc'],
    ];
    final bound = switch (action) {
      StampAction.clockIn when s.clockedIn => sessionStart,
      StampAction.clockIn => latest([
        for (final r in rows)
          if (r.table == 'work_sessions' && !r.isDeleted) r.fields['end_utc'],
      ]),
      StampAction.changeLocation => sessionStart,
      StampAction.endBreak => s.breakRow?.fields['start_utc'] as String?,
      StampAction.clockOut => latest([sessionStart, ...closedInSession()]),
      StampAction.startBreak => latest([
        sessionStart,
        ...closedInSession(),
        s.entry?.fields['start_utc'],
      ]),
    };
    return bound == null ? null : DateTime.parse(bound);
  }

  /// [at] as stored, or now. Throws [ArgumentError] if [at] is in the future
  /// or before [earliest].
  String _when(DateTime? at, [DateTime? earliest]) {
    if (at == null) return _stamp;
    final stamp = isoMinute(at);
    if (stamp.compareTo(_stamp) > 0) {
      throw ArgumentError.value(at, 'at', 'is in the future');
    }
    if (earliest != null && stamp.compareTo(isoMinute(earliest)) < 0) {
      throw ArgumentError.value(at, 'at', 'is before $earliest');
    }
    return stamp;
  }

  Future<String> _checked(DateTime? at, StampAction action) async =>
      _when(at, at == null ? null : await earliestAt(action));

  /// Clocks in at [location]. Does nothing if already clocked in at that
  /// location; switches the location (new session) if clocked in elsewhere.
  /// [at] dates it back (calculations.md §19).
  Future<void> clockIn({
    WorkLocation location = WorkLocation.office,
    DateTime? at,
  }) async {
    final s = await state();
    if (s.clockedIn) {
      if (s.location != location) await changeLocation(location, at: at);
      return;
    }
    await _openSession(location, await _checked(at, StampAction.clockIn));
  }

  /// Clocks out: ends the running break and project entry, then the session.
  ///
  /// [at] clocks out afterwards, e.g. for a forgotten clock-out: a running
  /// break or project entry that only started after it is deleted
  /// (reminders.md §1). It must not be before the session start.
  Future<void> clockOut({DateTime? at}) async {
    final s = await state();
    final start = s.session?.fields['start_utc'] as String?;
    final end = _when(at, start == null ? null : DateTime.parse(start));
    for (final (table, row) in [
      ('breaks', s.breakRow),
      ('project_entries', s.entry),
    ]) {
      if (row == null) continue;
      (row.fields['start_utc']! as String).compareTo(end) > 0
          ? await repository.delete(table, row.id)
          : await _end(table, row, end);
    }
    if (s.session != null) await _end('work_sessions', s.session!, end);
  }

  /// Starts a break (clocked in only). Stops the running project entry.
  /// [at] dates it back (calculations.md §19).
  Future<void> startBreak({DateTime? at}) async {
    final s = await state();
    if (!s.clockedIn || s.onBreak) return;
    final start = await _checked(at, StampAction.startBreak);
    if (s.entry != null) await _end('project_entries', s.entry!, start);
    await repository.write('breaks', repository.newId(), {
      'start_utc': start,
      'end_utc': null,
    });
  }

  /// Ends the running break and, if [resumeAfterBreak], restarts the project
  /// that ran until the break started. [at] dates it back (§19).
  Future<void> endBreak({DateTime? at}) async {
    final s = await state();
    final b = s.breakRow;
    if (b == null) return;
    final end = await _checked(at, StampAction.endBreak);
    await _end('breaks', b, end);
    if (!resumeAfterBreak || s.entry != null) return;
    final previous = await _entryEndedAt(b.fields['start_utc']! as String);
    if (previous != null) {
      await _startEntry(previous.fields['project_id']! as String, end);
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
    await _startEntry(projectId, _stamp);
  }

  /// Stops the running project entry (attendance continues).
  Future<void> stopProject() async {
    final s = await state();
    if (s.entry != null) await _end('project_entries', s.entry!, _stamp);
  }

  /// Changes the location while clocked in: the current session ends now and
  /// a new one starts with [location] (location is per session, ADR 0002).
  /// [at] dates the change back (calculations.md §19).
  Future<void> changeLocation(WorkLocation location, {DateTime? at}) async {
    final s = await state();
    if (s.session == null || s.location == location) return;
    final when = await _checked(at, StampAction.changeLocation);
    await _end('work_sessions', s.session!, when);
    await _openSession(location, when);
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

  /// Ends the open trip now, or at [at] (e.g. the dated-back clock-out).
  Future<void> endTrip({DateTime? at}) async {
    final s = await state();
    if (s.trip == null) return;
    final depart = DateTime.parse(s.trip!.fields['depart_utc']! as String);
    await repository.write('trips', s.trip!.id, {
      'return_utc': _when(at, depart),
    });
  }

  Future<void> _openSession(WorkLocation location, [String? at]) =>
      repository.write('work_sessions', repository.newId(), {
        'start_utc': at ?? _stamp,
        'end_utc': null,
        'location': location.wireName,
        'source': 'app',
      });

  Future<void> _startEntry(String projectId, String at) =>
      repository.write('project_entries', repository.newId(), {
        'project_id': projectId,
        'start_utc': at,
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
