import 'package:timetrack/sync/sync_controller.dart';

/// Keeps the sync config in memory (no platform channels in tests).
class MemorySyncConfigStore implements SyncConfigStore {
  SyncConfig? config;

  @override
  Future<SyncConfig?> load() async => config;

  @override
  Future<void> save(SyncConfig c) async => config = c;

  @override
  Future<void> clear() async => config = null;
}
