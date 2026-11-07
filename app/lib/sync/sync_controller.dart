import 'dart:async';
import 'dart:convert';
import 'dart:io' show HttpClient, Platform;

import 'package:cryptography/cryptography.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:timetrack_core/timetrack_core.dart';

import '../app/providers.dart';

/// Everything needed to sync, kept in the platform's secure storage
/// (sync-format.md §10): never in the database, never in logs.
final class SyncConfig {
  /// Creates a config.
  const SyncConfig({
    required this.root,
    required this.loginName,
    required this.appPassword,
    required this.keyBytes,
    this.proxy = '',
  });

  /// Reads the JSON form.
  factory SyncConfig.fromJson(Map<String, Object?> json) => SyncConfig(
    root: Uri.parse(json['root']! as String),
    loginName: json['loginName']! as String,
    appPassword: json['appPassword']! as String,
    keyBytes: base64Decode(json['key']! as String),
    proxy: json['proxy'] as String? ?? '',
  );

  /// WebDAV URL of the sync folder.
  final Uri root;

  /// Nextcloud login name.
  final String loginName;

  /// Nextcloud app password of this device.
  final String appPassword;

  /// The derived encryption key (32 bytes).
  final List<int> keyBytes;

  /// HTTP proxy `host:port` for this device only (e.g. a company PC); empty
  /// means the `HTTPS_PROXY`/`HTTP_PROXY` environment variables, else direct.
  final String proxy;

  /// The JSON form.
  Map<String, Object?> toJson() => {
    'root': '$root',
    'loginName': loginName,
    'appPassword': appPassword,
    'key': base64Encode(keyBytes),
    'proxy': proxy,
  };
}

/// Where the [SyncConfig] is kept.
abstract interface class SyncConfigStore {
  /// The saved config, or `null`.
  Future<SyncConfig?> load();

  /// Saves the config.
  Future<void> save(SyncConfig config);

  /// Forgets the config (disconnect).
  Future<void> clear();
}

/// [SyncConfigStore] in Keychain/Keystore/libsecret/Credential Manager.
final class SecureSyncConfigStore implements SyncConfigStore {
  static const _key = 'sync_config';
  final _storage = const FlutterSecureStorage();

  @override
  Future<SyncConfig?> load() async {
    final raw = await _storage.read(key: _key);
    return raw == null
        ? null
        : SyncConfig.fromJson(jsonDecode(raw) as Map<String, Object?>);
  }

  @override
  Future<void> save(SyncConfig config) =>
      _storage.write(key: _key, value: jsonEncode(config.toJson()));

  @override
  Future<void> clear() => _storage.delete(key: _key);
}

/// The config store; overridden with an in-memory one in tests.
final syncConfigStoreProvider = Provider<SyncConfigStore>(
  (ref) => SecureSyncConfigStore(),
);

/// An HTTP client that uses [proxy] (`host:port`), or else the proxy
/// environment variables. Dart doesn't read the Windows system proxy by
/// itself, hence the explicit setting for the company PC.
http.Client proxiedClient(String proxy) {
  final io = HttpClient();
  final manual = proxy.trim();
  io.findProxy = manual.isEmpty
      ? HttpClient.findProxyFromEnvironment
      : (_) => 'PROXY $manual; DIRECT';
  return IOClient(io);
}

/// HTTP client factory for WebDAV and Login Flow, by proxy setting;
/// overridden with a fake server in tests.
final httpClientFactoryProvider = Provider<http.Client Function(String proxy)>(
  (ref) => proxiedClient,
);

/// Emits after every committed local write (wired to
/// `SyncedRepository.onLocalWrite` in `main()`).
final localWritesProvider = Provider<Stream<void>>(
  (ref) => const Stream.empty(),
);

/// What the sync is doing.
enum SyncPhase {
  /// No Nextcloud connected.
  notConfigured,

  /// Connected, waiting for the next trigger.
  idle,

  /// A cycle is running.
  syncing,

  /// The last cycle failed; [SyncStatus.error] says why.
  error,
}

/// The sync state shown in the UI.
final class SyncStatus {
  /// Creates a status.
  const SyncStatus(this.phase, {this.lastSuccess, this.error, this.root});

  /// Current phase.
  final SyncPhase phase;

  /// When the last cycle succeeded.
  final DateTime? lastSuccess;

  /// The last error (for the log / status line).
  final Object? error;

  /// The connected sync folder.
  final Uri? root;
}

/// Runs the [SyncEngine] on triggers (sync-format.md §7.2): 5 s after local
/// writes (debounced), every 60 s, and on [onResume].
class SyncController extends Notifier<SyncStatus> {
  SyncEngine? _engine;
  Timer? _debounce;
  Timer? _periodic;
  StreamSubscription<void>? _writes;

  @override
  SyncStatus build() {
    ref.onDispose(_stop);
    _writes = ref
        .read(localWritesProvider)
        .listen((_) => _schedule(const Duration(seconds: 5)));
    Future.microtask(_init);
    return const SyncStatus(SyncPhase.notConfigured);
  }

  Future<void> _init() async {
    final config = await ref.read(syncConfigStoreProvider).load();
    if (config != null) _start(config);
  }

  void _start(SyncConfig config) {
    _engine = SyncEngine(
      repository: ref.read(repositoryProvider),
      remote: WebDavRemoteFolder(
        root: config.root,
        username: config.loginName,
        appPassword: config.appPassword,
        client: ref.read(httpClientFactoryProvider)(config.proxy),
      ),
      cipher: SyncCipher(SecretKey(config.keyBytes)),
      deviceName: _deviceName(),
      platform: Platform.operatingSystem,
    );
    state = SyncStatus(SyncPhase.idle, root: config.root);
    _periodic?.cancel();
    _periodic = Timer.periodic(const Duration(seconds: 60), (_) => syncNow());
    unawaited(syncNow());
  }

  static String _deviceName() {
    try {
      return Platform.isAndroid ? 'Android' : Platform.localHostname;
    } on Object {
      return Platform.operatingSystem;
    }
  }

  /// Runs one cycle now (no-op if not configured or already running).
  Future<void> syncNow() async {
    final engine = _engine;
    if (engine == null || state.phase == SyncPhase.syncing) return;
    final previous = state;
    state = SyncStatus(
      SyncPhase.syncing,
      lastSuccess: previous.lastSuccess,
      root: previous.root,
    );
    try {
      await engine.sync();
      state = SyncStatus(
        SyncPhase.idle,
        lastSuccess: DateTime.now(),
        root: previous.root,
      );
    } on Object catch (e) {
      state = SyncStatus(
        SyncPhase.error,
        lastSuccess: previous.lastSuccess,
        error: e,
        root: previous.root,
      );
    }
  }

  /// Call when the app returns to the foreground.
  void onResume() => _schedule(Duration.zero);

  void _schedule(Duration delay) {
    if (_engine == null) return;
    _debounce?.cancel();
    _debounce = Timer(delay, syncNow);
  }

  /// Saves [config] and starts syncing.
  Future<void> connect(SyncConfig config) async {
    await ref.read(syncConfigStoreProvider).save(config);
    _start(config);
  }

  /// Forgets the connection. Local data and the files on Nextcloud stay.
  Future<void> disconnect() async {
    await ref.read(syncConfigStoreProvider).clear();
    _stop();
    _engine = null;
    state = const SyncStatus(SyncPhase.notConfigured);
  }

  void _stop() {
    _debounce?.cancel();
    _periodic?.cancel();
    unawaited(_writes?.cancel());
  }
}

/// The sync controller and its status.
final syncControllerProvider = NotifierProvider<SyncController, SyncStatus>(
  SyncController.new,
);
