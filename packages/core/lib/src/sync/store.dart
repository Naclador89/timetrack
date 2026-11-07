import 'dart:async';

import 'change.dart';
import 'hlc.dart';

/// A frozen batch waiting for upload (spec: sync-format.md §7, `pending_batch`).
final class PendingBatch {
  /// Creates a pending batch.
  PendingBatch(this.name, List<Change> changes)
    : changes = List.unmodifiable(changes);

  /// File name, see `batchFileName`.
  final String name;

  /// The changes in the batch.
  final List<Change> changes;
}

/// The local database as the sync needs it (spec: sync-format.md §7).
///
/// Implemented by the drift database in production and by [InMemorySyncStore]
/// in tests.
abstract interface class SyncStore {
  /// Runs [action] atomically: either all of its writes are kept or none.
  /// Transactions don't overlap.
  Future<T> transaction<T>(Future<T> Function(SyncTransaction tx) action);

  /// All rows of [tables] (including deleted ones), emitted now and again
  /// after every committed change to them, so UIs update after local writes
  /// and syncs alike.
  Stream<List<StoredRow>> watchRows(Set<String> tables);
}

/// Reads and writes inside one [SyncStore.transaction].
abstract interface class SyncTransaction {
  /// The row, or `null` if it doesn't exist locally.
  Future<StoredRow?> row(String table, String id);

  /// All rows of [table], including deleted ones.
  Future<List<StoredRow>> rows(String table);

  /// Inserts or replaces a row.
  Future<void> putRow(StoredRow row);

  /// Changes not yet uploaded, in HLC order.
  Future<List<Change>> outbox();

  /// Appends a local change to the outbox.
  Future<void> appendOutbox(Change change);

  /// Empties the outbox.
  Future<void> clearOutbox();

  /// The frozen batch waiting for upload, if any.
  Future<PendingBatch?> pendingBatch();

  /// Sets or clears the pending batch.
  Future<void> setPendingBatch(PendingBatch? batch);

  /// The ETag of a remote file when it was applied, or `null` if never applied.
  Future<String?> seenEtag(String path);

  /// Records that the remote file [path] with [etag] has been applied.
  Future<void> markSeen(String path, String etag);

  /// The last fully applied ETag of a remote device folder.
  Future<String?> folderEtag(String path);

  /// Records the ETag of a fully applied remote device folder.
  Future<void> setFolderEtag(String path, String etag);

  /// Forgets all seen files and folder ETags, forcing a full replay
  /// (spec: sync-format.md §9).
  Future<void> resetSeen();

  /// The persisted HLC state.
  Future<Hlc?> lastHlc();

  /// Persists the HLC state.
  Future<void> setLastHlc(Hlc hlc);
}

/// A [SyncStore] kept in memory, for tests and simulations.
final class InMemorySyncStore implements SyncStore {
  _MemoryState _state = _MemoryState();
  Future<void> _queue = Future.value();
  final _commits = StreamController<void>.broadcast(sync: true);

  @override
  Stream<List<StoredRow>> watchRows(Set<String> tables) async* {
    List<StoredRow> snapshot() => [
      for (final t in tables) ...?_state.rows[t]?.values,
    ];
    yield snapshot();
    await for (final _ in _commits.stream) {
      yield snapshot();
    }
  }

  /// Rows of [table] (read-only snapshot), for assertions in tests.
  Map<String, StoredRow> rowsOf(String table) =>
      Map.unmodifiable(_state.rows[table] ?? const {});

  /// All rows of all tables, keyed `table/id` (read-only snapshot).
  Map<String, StoredRow> get allRows => {
    for (final MapEntry(key: table, value: rows) in _state.rows.entries)
      for (final MapEntry(key: id, value: row) in rows.entries)
        '$table/$id': row,
  };

  @override
  Future<T> transaction<T>(Future<T> Function(SyncTransaction tx) action) {
    final result = _queue.then((_) async {
      final draft = _state.copy();
      final value = await action(_MemoryTransaction(draft));
      _state = draft; // commit only if the action didn't throw
      _commits.add(null);
      return value;
    });
    _queue = result.then((_) {}, onError: (_) {});
    return result;
  }
}

final class _MemoryState {
  Map<String, Map<String, StoredRow>> rows = {};
  List<Change> outbox = [];
  PendingBatch? pending;
  Map<String, String> seen = {};
  Map<String, String> folders = {};
  Hlc? hlc;

  _MemoryState copy() => _MemoryState()
    ..rows = {
      for (final e in rows.entries) e.key: {...e.value},
    }
    ..outbox = [...outbox]
    ..pending = pending
    ..seen = {...seen}
    ..folders = {...folders}
    ..hlc = hlc;
}

final class _MemoryTransaction implements SyncTransaction {
  _MemoryTransaction(this._s);

  final _MemoryState _s;

  @override
  Future<StoredRow?> row(String table, String id) async => _s.rows[table]?[id];

  @override
  Future<List<StoredRow>> rows(String table) async => [
    ...?_s.rows[table]?.values,
  ];

  @override
  Future<void> putRow(StoredRow row) async =>
      (_s.rows[row.table] ??= {})[row.id] = row;

  @override
  Future<List<Change>> outbox() async => [..._s.outbox];

  @override
  Future<void> appendOutbox(Change change) async => _s.outbox.add(change);

  @override
  Future<void> clearOutbox() async => _s.outbox.clear();

  @override
  Future<PendingBatch?> pendingBatch() async => _s.pending;

  @override
  Future<void> setPendingBatch(PendingBatch? batch) async => _s.pending = batch;

  @override
  Future<String?> seenEtag(String path) async => _s.seen[path];

  @override
  Future<void> markSeen(String path, String etag) async => _s.seen[path] = etag;

  @override
  Future<String?> folderEtag(String path) async => _s.folders[path];

  @override
  Future<void> setFolderEtag(String path, String etag) async =>
      _s.folders[path] = etag;

  @override
  Future<void> resetSeen() async {
    _s.seen.clear();
    _s.folders.clear();
  }

  @override
  Future<Hlc?> lastHlc() async => _s.hlc;

  @override
  Future<void> setLastHlc(Hlc hlc) async => _s.hlc = hlc;
}
