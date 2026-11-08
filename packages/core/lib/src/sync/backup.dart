import 'dart:convert';

import 'batch.dart';
import 'change.dart';
import 'hlc.dart';
import 'repository.dart';

/// A JSON backup could not be read (spec: backup.md §1).
final class BackupFormatException implements Exception {
  /// Creates the exception.
  BackupFormatException(this.message);

  /// What is wrong.
  final String message;

  @override
  String toString() => 'BackupFormatException: $message';
}

/// All synced rows at one moment (spec: backup.md §1).
final class Backup {
  /// Creates a backup.
  Backup({required this.exported, required this.rows});

  /// When it was written (UTC).
  final DateTime exported;

  /// Every synced row, tombstones and field clocks included.
  final List<StoredRow> rows;
}

/// The backup file for [rows] (spec: backup.md §1).
String encodeBackup(List<StoredRow> rows, DateTime now) =>
    const JsonEncoder.withIndent(' ').convert({
      'app': 'TimeTrack',
      'format': syncFormatVersion,
      'exported': now.toUtc().toIso8601String(),
      'rows': [
        for (final r in rows)
          {
            'tbl': r.table,
            'id': r.id,
            'fields': r.fields,
            'fieldClock': r.fieldClock,
          },
      ],
    });

/// Reads a backup file; throws [BackupFormatException] if it isn't one this
/// version understands.
Backup decodeBackup(String text) {
  final Object? json;
  try {
    json = jsonDecode(text);
  } on FormatException catch (e) {
    throw BackupFormatException('Not JSON: ${e.message}');
  }
  if (json is! Map || json['app'] != 'TimeTrack') {
    throw BackupFormatException('Not a TimeTrack backup');
  }
  final format = json['format'];
  if (format is! int || format > syncFormatVersion) {
    throw BackupFormatException('Unsupported format $format');
  }
  try {
    final backup = Backup(
      exported: DateTime.parse(json['exported'] as String).toUtc(),
      rows: [
        for (final r in json['rows'] as List)
          StoredRow(
            table: (r as Map)['tbl'] as String,
            id: r['id'] as String,
            fields: (r['fields'] as Map).cast<String, Object?>(),
            fieldClock: (r['fieldClock'] as Map).cast<String, String>(),
          ),
      ],
    );
    // Every clock must parse, or a restore would fail halfway.
    for (final r in backup.rows) {
      r.fieldClock.values.forEach(Hlc.parse);
    }
    return backup;
  } on Object catch (e) {
    throw BackupFormatException('Malformed backup: $e');
  }
}

/// How a backup is loaded (spec: backup.md §2); the user picks it each time.
enum RestoreMode {
  /// Like a sync: per field the newer value wins, so nothing recorded after
  /// the backup is lost.
  merge,

  /// The data becomes exactly the backup, on every device: newer rows are
  /// deleted, newer edits overwritten.
  replace,
}

/// What a restore changes, counted in rows.
final class RestoreSummary {
  /// Creates a summary.
  const RestoreSummary({
    required this.added,
    required this.changed,
    required this.deleted,
  });

  /// Rows that come back (missing or deleted locally).
  final int added;

  /// Existing rows with at least one field changed.
  final int changed;

  /// Rows that end up deleted.
  final int deleted;

  /// Whether the restore would change nothing.
  bool get isEmpty => added == 0 && changed == 0 && deleted == 0;
}

/// Loads [backup] in [mode] through [repo], so every change reaches the
/// outbox and the other devices (spec: backup.md §2). With [dryRun] nothing
/// is written; the summary is the preview shown before the user confirms.
Future<RestoreSummary> restoreBackup(
  SyncedRepository repo,
  Backup backup,
  RestoreMode mode, {
  bool dryRun = false,
}) async {
  final summary = await repo.store.transaction((tx) async {
    final tables = {...syncedTables, for (final r in backup.rows) r.table};
    final local = <(String, String), StoredRow>{
      for (final t in tables)
        for (final r in await tx.rows(t)) (r.table, r.id): r,
    };
    final edits = switch (mode) {
      RestoreMode.merge => _mergeEdits(backup, local),
      RestoreMode.replace => _replaceEdits(backup, local),
    };
    var added = 0, changed = 0, deleted = 0;
    for (final MapEntry(key: key, value: changes) in edits.entries) {
      final before = local[key];
      var row = before;
      for (final (set, hlc) in changes) {
        final change = Change(
          table: key.$1,
          id: key.$2,
          hlc: dryRun
              // Any fresh timestamp is newer than every stored one.
              ? (hlc ?? Hlc(9999999999999, 0, repo.clock.deviceId))
              : (hlc ?? repo.clock.tick()),
          set: set,
        );
        if (hlc != null && !dryRun) repo.clock.receive(hlc);
        row = applyChange(row, change);
        if (!dryRun) await tx.appendOutbox(change);
      }
      if (!dryRun) await tx.putRow(row!);
      if (row!.isDeleted) {
        if (before != null && !before.isDeleted) deleted++;
      } else if (before == null || before.isDeleted) {
        added++;
      } else {
        changed++;
      }
    }
    if (!dryRun && edits.isNotEmpty) await tx.setLastHlc(repo.clock.last);
    return RestoreSummary(added: added, changed: changed, deleted: deleted);
  });
  if (!dryRun && !summary.isEmpty) repo.onLocalWrite?.call();
  return summary;
}

/// Field writes per row; a `null` HLC means "a fresh local timestamp".
typedef _Edits = Map<(String, String), List<(Map<String, Object?>, Hlc?)>>;

/// Backup fields whose clock is newer than the local one, with that clock,
/// exactly as if the backup's device had synced them (§2.1).
_Edits _mergeEdits(Backup backup, Map<(String, String), StoredRow> local) {
  final edits = <(String, String), List<(Map<String, Object?>, Hlc?)>>{};
  for (final b in backup.rows) {
    final l = local[(b.table, b.id)];
    final byClock = <String, Map<String, Object?>>{};
    for (final MapEntry(:key, :value) in b.fieldClock.entries) {
      final mine = l?.fieldClock[key];
      if (mine != null && value.compareTo(mine) <= 0) continue;
      (byClock[value] ??= {})[key] = b.fields[key];
    }
    if (byClock.isEmpty) continue;
    edits[(b.table, b.id)] = [
      for (final hlc in byClock.keys.toList()..sort())
        (byClock[hlc]!, Hlc.parse(hlc)),
    ];
  }
  return edits;
}

/// Fresh writes that make every row equal the backup and delete rows the
/// backup doesn't have (§2.2).
_Edits _replaceEdits(Backup backup, Map<(String, String), StoredRow> local) {
  final edits = <(String, String), List<(Map<String, Object?>, Hlc?)>>{};
  final inBackup = <(String, String)>{};
  for (final b in backup.rows) {
    final key = (b.table, b.id);
    inBackup.add(key);
    final l = local[key];
    final set = <String, Object?>{
      for (final k in {...b.fields.keys, ...?l?.fields.keys})
        if (!_same(b.fields[k], l?.fields[k])) k: b.fields[k],
    };
    if (set.isNotEmpty) edits[key] = [(set, null)];
  }
  for (final MapEntry(:key, value: l) in local.entries) {
    if (inBackup.contains(key) || l.isDeleted) continue;
    edits[key] = [
      (const {'deleted': true}, null),
    ];
  }
  return edits;
}

bool _same(Object? a, Object? b) =>
    a == b || (a != null && b != null && jsonEncode(a) == jsonEncode(b));
