import 'dart:convert';

import 'engine.dart';
import 'store.dart';

/// Where a sync cycle ran (spec: sync-log.md).
enum SyncTrigger {
  /// In the app (start, resume, timer, after a local write, by hand).
  app,

  /// In an Android background handler or WorkManager job.
  background,
}

/// One sync cycle, or a run of consecutive idle ones (spec: sync-log.md).
final class SyncLogEntry {
  /// Creates an entry.
  const SyncLogEntry({
    required this.start,
    required this.durationMs,
    required this.trigger,
    this.uploadedChanges = 0,
    this.downloadedFiles = 0,
    this.appliedChanges = 0,
    this.resolvedRows = 0,
    this.error,
    this.repeats = 1,
    DateTime? last,
  }) : last = last ?? start;

  /// An entry for a finished cycle.
  factory SyncLogEntry.of({
    required DateTime start,
    required DateTime end,
    required SyncTrigger trigger,
    SyncReport? report,
    Object? error,
  }) => SyncLogEntry(
    start: start.toUtc(),
    durationMs: end.difference(start).inMilliseconds,
    trigger: trigger,
    uploadedChanges: report?.uploadedChanges ?? 0,
    downloadedFiles: report?.downloadedFiles ?? 0,
    appliedChanges: report?.appliedChanges ?? 0,
    resolvedRows: report?.resolvedRows ?? 0,
    error: error == null ? null : sanitizeSyncError(error),
  );

  /// Reads the stored form.
  factory SyncLogEntry.fromJson(Map<String, Object?> j) => SyncLogEntry(
    start: DateTime.parse(j['start']! as String),
    last: DateTime.parse((j['last'] ?? j['start'])! as String),
    durationMs: j['ms']! as int,
    trigger: SyncTrigger.values.byName(j['trigger']! as String),
    uploadedChanges: (j['up'] as int?) ?? 0,
    downloadedFiles: (j['files'] as int?) ?? 0,
    appliedChanges: (j['down'] as int?) ?? 0,
    resolvedRows: (j['resolved'] as int?) ?? 0,
    error: j['error'] as String?,
    repeats: (j['n'] as int?) ?? 1,
  );

  /// When the (first) cycle started, UTC.
  final DateTime start;

  /// When the last of [repeats] idle cycles started, UTC.
  final DateTime last;

  /// How long the (last) cycle took.
  final int durationMs;

  /// Where it ran.
  final SyncTrigger trigger;

  /// Changes uploaded.
  final int uploadedChanges;

  /// Remote files downloaded.
  final int downloadedFiles;

  /// Changes in those files.
  final int appliedChanges;

  /// Rows corrected by the resolve rules.
  final int resolvedRows;

  /// Why the cycle failed, without credentials; `null` on success.
  final String? error;

  /// How many identical idle cycles this entry stands for.
  final int repeats;

  /// Whether the cycle failed.
  bool get failed => error != null;

  /// Succeeded without moving anything.
  bool get idle =>
      !failed &&
      uploadedChanges == 0 &&
      downloadedFiles == 0 &&
      resolvedRows == 0;

  /// The stored form.
  Map<String, Object?> toJson() => {
    'start': start.toIso8601String(),
    if (repeats > 1) 'last': last.toIso8601String(),
    'ms': durationMs,
    'trigger': trigger.name,
    if (uploadedChanges > 0) 'up': uploadedChanges,
    if (downloadedFiles > 0) 'files': downloadedFiles,
    if (appliedChanges > 0) 'down': appliedChanges,
    if (resolvedRows > 0) 'resolved': resolvedRows,
    'error': ?error,
    if (repeats > 1) 'n': repeats,
  };
}

/// The error text for the log: credentials in URLs removed, one line,
/// at most 300 characters (AGENTS.md: never log secrets).
String sanitizeSyncError(Object error) {
  var text = error
      .toString()
      .replaceAll(RegExp(r'//[^/@\s]+@'), '//')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (text.length > 300) text = '${text.substring(0, 299)}…';
  return text;
}

/// The last sync cycles of this device, newest first (spec: sync-log.md).
/// Device-local (`local_values`), never synced.
final class SyncLog {
  /// Creates the log on [store].
  const SyncLog(this.store);

  /// Where the log is kept.
  final SyncStore store;

  static const _key = 'sync_log';

  /// Entries kept; older ones are dropped.
  static const capacity = 100;

  /// Adds [entry]; an idle cycle right after another idle one only bumps
  /// that entry's count, so the 60-second timer doesn't flood the log.
  Future<void> record(SyncLogEntry entry) => store.transaction((tx) async {
    final entries = _decode(await tx.localValue(_key));
    final newest = entries.isEmpty ? null : entries.first;
    if (entry.idle && newest != null && newest.idle) {
      entries[0] = SyncLogEntry(
        start: newest.start,
        last: entry.start,
        durationMs: entry.durationMs,
        trigger: entry.trigger,
        repeats: newest.repeats + 1,
      );
    } else {
      entries.insert(0, entry);
    }
    await tx.setLocalValue(
      _key,
      jsonEncode([for (final e in entries.take(capacity)) e.toJson()]),
    );
  });

  /// All entries, newest first.
  Future<List<SyncLogEntry>> entries() =>
      store.transaction((tx) async => _decode(await tx.localValue(_key)));

  /// Empties the log.
  Future<void> clear() =>
      store.transaction((tx) => tx.setLocalValue(_key, null));

  static List<SyncLogEntry> _decode(String? raw) {
    if (raw == null) return [];
    try {
      return [
        for (final e in jsonDecode(raw) as List)
          SyncLogEntry.fromJson((e as Map).cast<String, Object?>()),
      ];
    } on Object {
      return []; // A damaged log is not worth an error.
    }
  }
}
