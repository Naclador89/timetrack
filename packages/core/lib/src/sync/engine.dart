import 'dart:convert';

import 'batch.dart';
import 'change.dart';
import 'crypto.dart';
import 'remote.dart';
import 'repository.dart';
import 'store.dart';

/// Thrown when the remote folder uses a newer sync format than this app
/// understands (spec: sync-format.md §2, §9). The user must update the app.
final class SyncFormatException implements Exception {
  /// Creates the exception.
  SyncFormatException(this.format);

  /// The format version found in `format.json`.
  final Object? format;

  @override
  String toString() => 'SyncFormatException: remote format $format is newer';
}

/// Connects to the sync folder with the sync passphrase. The first device
/// creates `format.json` with new encryption parameters; every further device
/// checks the passphrase against it (spec: sync-format.md §2, §10).
///
/// [memoryKiB] and [iterations] are only lowered in tests.
Future<SyncCipher> connectSyncFolder(
  RemoteFolder remote,
  String passphrase, {
  int memoryKiB = 65536,
  int iterations = 3,
  DateTime? now,
}) async {
  final existing = await remote.read('format.json');
  if (existing != null) return _unlock(existing, passphrase);
  await remote.makeDirectory(''); // the sync folder itself, on first use
  final (params, cipher) = await createEncryption(
    passphrase,
    memoryKiB: memoryKiB,
    iterations: iterations,
  );
  final json = jsonEncode({
    'format': syncFormatVersion,
    'created': (now ?? DateTime.now()).toUtc().toIso8601String(),
    'encryption': params.toJson(),
  });
  if (await remote.createFile('format.json', utf8.encode(json))) return cipher;
  // Another device created it first: use theirs.
  return _unlock((await remote.read('format.json'))!, passphrase);
}

Future<SyncCipher> _unlock(List<int> formatJson, String passphrase) {
  final json = jsonDecode(utf8.decode(formatJson)) as Map<String, Object?>;
  _checkFormat(json);
  return unlockEncryption(
    passphrase,
    EncryptionParams.fromJson((json['encryption']! as Map).cast()),
  );
}

void _checkFormat(Map<String, Object?> json) {
  final format = json['format'];
  if (format is! int || format > syncFormatVersion) {
    throw SyncFormatException(format);
  }
}

/// What one sync cycle did.
final class SyncReport {
  /// Creates a report.
  const SyncReport({
    required this.uploadedChanges,
    required this.downloadedFiles,
    required this.appliedChanges,
    required this.resolvedRows,
  });

  /// Changes uploaded in this cycle's batch (0 if nothing was pending).
  final int uploadedChanges;

  /// Remote batch files downloaded and applied.
  final int downloadedFiles;

  /// Changes contained in those files.
  final int appliedChanges;

  /// Rows corrected by the resolve rules (§7.1).
  final int resolvedRows;
}

/// Tables with "at most one open row" rules (spec: sync-format.md §7.1).
const _singleOpen = ['work_sessions', 'project_entries'];

/// Runs sync cycles for one device (spec: sync-format.md §7).
final class SyncEngine {
  /// Creates an engine. [repository] must use the same [store]; it records
  /// the resolve corrections as normal local writes.
  SyncEngine({
    required this.repository,
    required this.remote,
    required this.cipher,
    this.deviceName = '',
    this.platform = '',
  });

  /// Local writes and the clock.
  final SyncedRepository repository;

  /// The remote sync folder.
  final RemoteFolder remote;

  /// Encrypts and decrypts batch files.
  final SyncCipher cipher;

  /// Human-readable device name for `device.json`, e.g. `Pixel 8`.
  final String deviceName;

  /// Platform for `device.json`: `android`, `linux` or `windows`.
  final String platform;

  bool _prepared = false;
  Future<SyncReport>? _running;

  SyncStore get _store => repository.store;
  String get _deviceId => repository.clock.deviceId;
  String get _ownFolder => 'devices/$_deviceId';

  /// Runs one sync cycle. Concurrent calls share the running cycle.
  /// Errors (network, crypto, format) end the cycle; state stays consistent
  /// and the next cycle continues where this one stopped.
  Future<SyncReport> sync() =>
      _running ??= _cycle().whenComplete(() => _running = null);

  Future<SyncReport> _cycle() async {
    await _prepare();
    final uploaded = await _push();
    final (files, changes) = await _pull();
    final resolved = await _resolve();
    return SyncReport(
      uploadedChanges: uploaded,
      downloadedFiles: files,
      appliedChanges: changes,
      resolvedRows: resolved,
    );
  }

  /// Step 1: check the format, make sure the own folders and device.json exist.
  Future<void> _prepare() async {
    final format = await remote.read('format.json');
    if (format == null) {
      throw StateError('Sync folder not set up; call connectSyncFolder first');
    }
    _checkFormat(jsonDecode(utf8.decode(format)) as Map<String, Object?>);
    if (_prepared) return;
    for (final dir in ['devices', _ownFolder, '$_ownFolder/ops']) {
      await remote.makeDirectory(dir);
    }
    await remote.createFile(
      '$_ownFolder/device.json',
      utf8.encode(
        jsonEncode({
          'deviceId': _deviceId,
          'name': deviceName,
          'platform': platform,
          'created': DateTime.now().toUtc().toIso8601String(),
        }),
      ),
    );
    _prepared = true;
  }

  /// Step 2: freeze the outbox into a pending batch, upload it once.
  Future<int> _push() async {
    final batch = await _store.transaction((tx) async {
      final pending = await tx.pendingBatch();
      if (pending != null) return pending;
      final outbox = await tx.outbox();
      if (outbox.isEmpty) return null;
      final frozen = PendingBatch(batchFileName(outbox), outbox);
      await tx.setPendingBatch(frozen);
      await tx.clearOutbox();
      return frozen;
    });
    if (batch == null) return 0;
    final path = '$_ownFolder/ops/${batch.name}';
    final sealed = await cipher.seal(
      encodeBatch(_deviceId, batch.changes),
      path,
    );
    // false = an earlier attempt already uploaded it (412); same content.
    await remote.createFile(path, sealed);
    await _store.transaction((tx) => tx.setPendingBatch(null));
    return batch.changes.length;
  }

  /// Steps 3–4: apply every new file of every other device.
  Future<(int, int)> _pull() async {
    var files = 0, changes = 0;
    final devices = await remote.list('devices');
    for (final device in devices) {
      if (!device.isDirectory || device.name == _deviceId) continue;
      final known = await _store.transaction(
        (tx) => tx.folderEtag(device.path),
      );
      if (known == device.etag) continue;
      var complete = true;
      final ops =
          (await remote.list('${device.path}/ops'))
              .where((e) => !e.isDirectory)
              .toList()
            ..sort((a, b) => a.name.compareTo(b.name));
      for (final file in ops) {
        final seen = await _store.transaction((tx) => tx.seenEtag(file.path));
        if (seen == file.etag) continue;
        final sealed = await remote.read(file.path);
        if (sealed == null) {
          complete =
              false; // deleted meanwhile (compaction); list again next time
          continue;
        }
        final batch = decodeBatch(
          await cipher.open(sealed, file.path),
          expectedDeviceId: device.name,
        );
        await _apply(batch, file);
        files++;
        changes += batch.length;
      }
      if (complete) {
        await _store.transaction(
          (tx) => tx.setFolderEtag(device.path, device.etag),
        );
      }
    }
    return (files, changes);
  }

  Future<void> _apply(List<Change> batch, RemoteEntry file) =>
      _store.transaction((tx) async {
        final clock = repository.clock;
        for (final change in batch) {
          clock.receive(change.hlc);
          await tx.putRow(
            applyChange(await tx.row(change.table, change.id), change),
          );
        }
        await tx.markSeen(file.path, file.etag);
        await tx.setLastHlc(clock.last);
      });

  /// Step 5 (§7.1): at most one open session and one running project entry.
  Future<int> _resolve() async {
    var corrected = 0;
    for (final table in _singleOpen) {
      final open =
          (await _store.transaction((tx) => tx.rows(table)))
              .where(
                (r) =>
                    !r.isDeleted &&
                    r.fields['end_utc'] == null &&
                    r.fields['start_utc'] is String,
              )
              .toList()
            ..sort((a, b) {
              final byStart = (a.fields['start_utc']! as String).compareTo(
                b.fields['start_utc']! as String,
              );
              return byStart != 0 ? byStart : a.id.compareTo(b.id);
            });
      for (var i = 0; i < open.length - 1; i++) {
        await repository.write(table, open[i].id, {
          'end_utc': open[i + 1].fields['start_utc'],
        });
        corrected++;
      }
    }
    return corrected;
  }
}
