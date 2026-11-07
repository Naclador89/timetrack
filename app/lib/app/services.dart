import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/common.dart';
import 'package:timetrack_core/timetrack_core.dart';

/// The local database with its store and repository, as opened by the UI
/// (`main()`) and by the Android background handlers (lib/quick/).
final class AppServices {
  AppServices._(this.db, this.store, this.repository);

  /// Opens the app database.
  ///
  /// The UI passes [shareAcrossIsolates] so its own isolates share one
  /// connection. Background handlers run in separate Flutter engines, where
  /// that sharing doesn't work (drift_flutter docs); they open their own
  /// connection, and WAL plus a busy timeout let both write safely.
  static Future<AppServices> open({
    required bool shareAcrossIsolates,
    void Function()? onLocalWrite,
  }) async {
    final db = TimeTrackDatabase(
      driftDatabase(
        name: 'timetrack',
        native: DriftNativeOptions(
          // Per-app data folder (~/.local/share/<app id>, %APPDATA%\<app id>,
          // Android app storage), not the user's Documents folder.
          databaseDirectory: getApplicationSupportDirectory,
          shareAcrossIsolates: shareAcrossIsolates,
          setup: _setupConnection,
        ),
      ),
    );
    final store = DriftSyncStore(db);
    final repository = await SyncedRepository.open(
      store,
      await loadOrCreateDeviceId(db),
      onLocalWrite: onLocalWrite,
    );
    return AppServices._(db, store, repository);
  }

  /// The drift database.
  final TimeTrackDatabase db;

  /// The store on [db].
  final DriftSyncStore store;

  /// The only way to write synced data.
  final SyncedRepository repository;

  /// Closes the database.
  Future<void> close() => db.close();
}

// Top-level: drift sends it to the isolate that opens the connection.
void _setupConnection(CommonDatabase db) {
  db.execute('PRAGMA journal_mode = WAL');
  db.execute('PRAGMA busy_timeout = 5000');
}
