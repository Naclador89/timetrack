import 'package:drift/drift.dart';

part 'database.g.dart';

/// Every synced row of every synced table, stored generically
/// (ADR 0007, spec: sync-format.md §4).
///
/// Fields live in a JSON object, so new fields from newer app versions are
/// kept without a schema migration.
@DataClassName('SyncedRowData')
class SyncedRows extends Table {
  /// Synced table name, e.g. `work_sessions`.
  TextColumn get tbl => text()();

  /// Row id (UUIDv7, or the key for `settings`).
  TextColumn get rowId => text()();

  /// JSON object of field values.
  TextColumn get fields => text()();

  /// JSON object `field → HLC` of the last applied write per field.
  TextColumn get fieldClock => text()();

  @override
  Set<Column> get primaryKey => {tbl, rowId};
}

/// Local changes not yet uploaded (sync-format.md §7, `outbox`).
@DataClassName('OutboxEntry')
class Outbox extends Table {
  /// Insertion order, which is also HLC order for local writes.
  IntColumn get seq => integer().autoIncrement()();

  /// The change as JSON (`Change.toJson`).
  TextColumn get change => text()();
}

/// The frozen batch waiting for upload; at most one row (`slot = 0`).
@DataClassName('PendingBatchRow')
class PendingBatches extends Table {
  /// Always 0.
  IntColumn get slot => integer()();

  /// File name of the batch.
  TextColumn get name => text()();

  /// JSON array of the changes.
  TextColumn get changes => text()();

  @override
  Set<Column> get primaryKey => {slot};
}

/// Remote files already applied, with their ETag (`seen_files`).
@DataClassName('SeenFile')
class SeenFiles extends Table {
  /// Path relative to the sync root.
  TextColumn get path => text()();

  /// ETag when applied.
  TextColumn get etag => text()();

  @override
  Set<Column> get primaryKey => {path};
}

/// Last fully applied ETag per remote device folder (`folder_etags`).
@DataClassName('FolderEtag')
class FolderEtags extends Table {
  /// Folder path relative to the sync root.
  TextColumn get path => text()();

  /// ETag when fully applied.
  TextColumn get etag => text()();

  @override
  Set<Column> get primaryKey => {path};
}

/// Small local-only values: HLC state, device id (never synced).
@DataClassName('LocalValue')
class LocalValues extends Table {
  /// Key, e.g. `hlc`.
  TextColumn get key => text()();

  /// Value.
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

/// The local SQLite database of one device.
///
/// Open it with `driftDatabase(...)` in the app or `NativeDatabase.memory()`
/// in tests. After changing tables, run
/// `dart run build_runner build --delete-conflicting-outputs`.
@DriftDatabase(
  tables: [
    SyncedRows,
    Outbox,
    PendingBatches,
    SeenFiles,
    FolderEtags,
    LocalValues,
  ],
)
class TimeTrackDatabase extends _$TimeTrackDatabase {
  /// Creates the database on [executor].
  TimeTrackDatabase(super.executor);

  @override
  int get schemaVersion => 1;
}
