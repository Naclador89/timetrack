import 'package:uuid/uuid.dart';

import 'change.dart';
import 'hlc.dart';
import 'store.dart';

/// The only way to write synced data (AGENTS.md, spec: sync-format.md §7).
///
/// Each write updates the row, its field clock and the outbox in one
/// transaction, so a change is either fully recorded or not at all.
final class SyncedRepository {
  /// Creates a repository. [onLocalWrite] is called after every committed
  /// write, e.g. to schedule a debounced sync.
  SyncedRepository({
    required this.store,
    required this.clock,
    this.onLocalWrite,
  });

  /// Opens a repository for [deviceId], continuing the clock persisted in [store].
  static Future<SyncedRepository> open(
    SyncStore store,
    String deviceId, {
    int Function()? now,
    void Function()? onLocalWrite,
  }) async {
    final last = await store.transaction((tx) => tx.lastHlc());
    return SyncedRepository(
      store: store,
      clock: HlcClock(deviceId, last: last, now: now),
      onLocalWrite: onLocalWrite,
    );
  }

  /// The local database.
  final SyncStore store;

  /// This device's clock.
  final HlcClock clock;

  /// Called after every committed local write.
  final void Function()? onLocalWrite;

  static const _uuid = Uuid();

  /// A new row id (UUIDv7).
  String newId() => _uuid.v7();

  /// Sets [fields] of row [id] in [table] (creating the row if needed) and
  /// returns the recorded change.
  Future<Change> write(
    String table,
    String id,
    Map<String, Object?> fields,
  ) async {
    final change = await store.transaction((tx) async {
      final change = Change(
        table: table,
        id: id,
        hlc: clock.tick(),
        set: fields,
      );
      await tx.putRow(applyChange(await tx.row(table, id), change));
      await tx.appendOutbox(change);
      await tx.setLastHlc(clock.last);
      return change;
    });
    onLocalWrite?.call();
    return change;
  }

  /// Marks row [id] in [table] as deleted (a tombstone, spec: sync-format.md §5).
  Future<Change> delete(String table, String id) =>
      write(table, id, const {'deleted': true});

  /// Reads a row.
  Future<StoredRow?> get(String table, String id) =>
      store.transaction((tx) => tx.row(table, id));
}
