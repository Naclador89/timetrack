import 'dart:convert';

import 'package:drift/drift.dart';

import '../sync/change.dart';
import '../sync/hlc.dart';
import '../sync/store.dart';
import 'database.dart';

/// [SyncStore] on the local SQLite database (spec: sync-format.md §7).
final class DriftSyncStore implements SyncStore {
  /// Creates a store on [db].
  DriftSyncStore(this.db);

  /// The database.
  final TimeTrackDatabase db;

  @override
  Future<T> transaction<T>(Future<T> Function(SyncTransaction tx) action) =>
      db.transaction(() => action(_DriftTransaction(db)));

  /// Watches all non-deleted rows of [tables], for reactive UIs: emits again
  /// whenever a local write or a sync changes them.
  Stream<List<StoredRow>> watchRows(Set<String> tables) =>
      (db.select(db.syncedRows)..where((r) => r.tbl.isIn(tables))).watch().map(
        (rows) => [for (final r in rows) _toStored(r)],
      );
}

StoredRow _toStored(SyncedRowData r) => StoredRow(
  table: r.tbl,
  id: r.rowId,
  fields: (jsonDecode(r.fields) as Map).cast<String, Object?>(),
  fieldClock: (jsonDecode(r.fieldClock) as Map).cast<String, String>(),
);

const _hlcKey = 'hlc';

final class _DriftTransaction implements SyncTransaction {
  _DriftTransaction(this.db);

  final TimeTrackDatabase db;

  @override
  Future<StoredRow?> row(String table, String id) async {
    final r =
        await (db.select(db.syncedRows)
              ..where((t) => t.tbl.equals(table) & t.rowId.equals(id)))
            .getSingleOrNull();
    return r == null ? null : _toStored(r);
  }

  @override
  Future<List<StoredRow>> rows(String table) async => [
    for (final r in await (db.select(
      db.syncedRows,
    )..where((t) => t.tbl.equals(table))).get())
      _toStored(r),
  ];

  @override
  Future<void> putRow(StoredRow row) => db
      .into(db.syncedRows)
      .insertOnConflictUpdate(
        SyncedRowsCompanion.insert(
          tbl: row.table,
          rowId: row.id,
          fields: jsonEncode(row.fields),
          fieldClock: jsonEncode(row.fieldClock),
        ),
      );

  @override
  Future<List<Change>> outbox() async => [
    for (final e in await (db.select(
      db.outbox,
    )..orderBy([(t) => OrderingTerm.asc(t.seq)])).get())
      Change.fromJson(jsonDecode(e.change) as Map<String, Object?>),
  ];

  @override
  Future<void> appendOutbox(Change change) => db
      .into(db.outbox)
      .insert(OutboxCompanion.insert(change: jsonEncode(change.toJson())));

  @override
  Future<void> clearOutbox() => db.delete(db.outbox).go();

  @override
  Future<PendingBatch?> pendingBatch() async {
    final r = await db.select(db.pendingBatches).getSingleOrNull();
    if (r == null) return null;
    return PendingBatch(r.name, [
      for (final c in jsonDecode(r.changes) as List)
        Change.fromJson((c as Map).cast<String, Object?>()),
    ]);
  }

  @override
  Future<void> setPendingBatch(PendingBatch? batch) async {
    await db.delete(db.pendingBatches).go();
    if (batch == null) return;
    await db
        .into(db.pendingBatches)
        .insert(
          PendingBatchesCompanion.insert(
            slot: const Value(0),
            name: batch.name,
            changes: jsonEncode([for (final c in batch.changes) c.toJson()]),
          ),
        );
  }

  @override
  Future<String?> seenEtag(String path) async => (await (db.select(
    db.seenFiles,
  )..where((t) => t.path.equals(path))).getSingleOrNull())?.etag;

  @override
  Future<void> markSeen(String path, String etag) => db
      .into(db.seenFiles)
      .insertOnConflictUpdate(
        SeenFilesCompanion.insert(path: path, etag: etag),
      );

  @override
  Future<String?> folderEtag(String path) async => (await (db.select(
    db.folderEtags,
  )..where((t) => t.path.equals(path))).getSingleOrNull())?.etag;

  @override
  Future<void> setFolderEtag(String path, String etag) => db
      .into(db.folderEtags)
      .insertOnConflictUpdate(
        FolderEtagsCompanion.insert(path: path, etag: etag),
      );

  @override
  Future<void> resetSeen() async {
    await db.delete(db.seenFiles).go();
    await db.delete(db.folderEtags).go();
  }

  @override
  Future<Hlc?> lastHlc() async {
    final r = await (db.select(
      db.localValues,
    )..where((t) => t.key.equals(_hlcKey))).getSingleOrNull();
    return r == null ? null : Hlc.parse(r.value);
  }

  @override
  Future<void> setLastHlc(Hlc hlc) => db
      .into(db.localValues)
      .insertOnConflictUpdate(
        LocalValuesCompanion.insert(key: _hlcKey, value: hlc.toString()),
      );
}
