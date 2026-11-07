import 'package:timetrack_core/timetrack_core.dart';

/// A remote folder that can simulate lost connections at chosen moments.
final class FlakyRemote implements RemoteFolder {
  FlakyRemote(this.inner);

  final InMemoryRemoteFolder inner;

  /// The next createFile fails before anything reaches the server.
  bool failBeforeNextCreate = false;

  /// The next createFile succeeds on the server, but the answer is lost.
  bool failAfterNextCreate = false;

  /// The next read fails.
  bool failNextRead = false;

  @override
  Future<bool> createFile(String path, List<int> bytes) async {
    if (failBeforeNextCreate) {
      failBeforeNextCreate = false;
      throw Exception('connection lost before upload');
    }
    final created = await inner.createFile(path, bytes);
    if (failAfterNextCreate) {
      failAfterNextCreate = false;
      throw Exception('connection lost after upload');
    }
    return created;
  }

  @override
  Future<List<int>?> read(String path) async {
    if (failNextRead) {
      failNextRead = false;
      throw Exception('connection lost during download');
    }
    return inner.read(path);
  }

  @override
  Future<RemoteEntry?> stat(String path) => inner.stat(path);

  @override
  Future<List<RemoteEntry>> list(String path) => inner.list(path);

  @override
  Future<void> writeFile(String path, List<int> bytes) =>
      inner.writeFile(path, bytes);

  @override
  Future<void> makeDirectory(String path) => inner.makeDirectory(path);

  @override
  Future<void> delete(String path) => inner.delete(path);
}

/// One simulated device: its own store, repository and engine.
final class SimDevice {
  SimDevice._(this.id, this.store, this.repository, this.engine, this.remote);

  static Future<SimDevice> create(
    String id,
    InMemoryRemoteFolder server, {
    String passphrase = 'correct horse',
    int Function()? now,
  }) async {
    final store = InMemorySyncStore();
    final remote = FlakyRemote(server);
    final cipher = await connectSyncFolder(
      remote,
      passphrase,
      memoryKiB: 64,
      iterations: 1,
    );
    final repository = await SyncedRepository.open(store, id, now: now);
    return SimDevice._(
      id,
      store,
      repository,
      SyncEngine(repository: repository, remote: remote, cipher: cipher),
      remote,
    );
  }

  final String id;
  final InMemorySyncStore store;
  final SyncedRepository repository;
  final SyncEngine engine;
  final FlakyRemote remote;

  /// Syncs and swallows simulated connection errors.
  Future<SyncReport?> trySync() async {
    try {
      return await engine.sync();
    } on Exception {
      return null;
    }
  }
}
