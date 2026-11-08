import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:timetrack_core/timetrack_core.dart';

/// Download or install failed (spec: updates.md §5).
final class UpdateException implements Exception {
  /// Creates the exception.
  const UpdateException(this.message);

  /// What went wrong (English, for the log and the error details).
  final String message;

  @override
  String toString() => message;
}

/// Android doesn't let TimeTrack install apps yet; the settings page for it
/// was opened (spec: updates.md §5).
final class InstallPermissionNeeded implements Exception {
  /// Creates the exception.
  const InstallPermissionNeeded();
}

/// Downloads the [platform] build of [release] into [folder] and checks it
/// against the release's `SHA256SUMS`; a mismatch deletes the file and throws.
Future<File> downloadVerified(
  http.Client client,
  Release release,
  UpdatePlatform platform,
  Directory folder, {
  void Function(double progress)? onProgress,
}) async {
  final asset = release.asset(platform.assetName);
  final sumsAsset = release.asset(checksumsAssetName);
  if (asset == null || sumsAsset == null) {
    throw const UpdateException('Release has no build for this platform');
  }
  final sums = await client.get(sumsAsset.url);
  if (sums.statusCode != 200) {
    throw UpdateException('Checksums: HTTP ${sums.statusCode}');
  }
  final expected = parseSha256Sums(sums.body)[asset.name];
  if (expected == null) {
    throw UpdateException('No checksum for ${asset.name}');
  }
  final response = await client.send(http.Request('GET', asset.url));
  if (response.statusCode != 200) {
    throw UpdateException('Download: HTTP ${response.statusCode}');
  }
  await folder.create(recursive: true);
  final file = File('${folder.path}${Platform.pathSeparator}${asset.name}');
  final total = response.contentLength ?? asset.size;
  final sink = file.openWrite();
  var received = 0;
  try {
    await for (final chunk in response.stream) {
      sink.add(chunk);
      received += chunk.length;
      if (total > 0) onProgress?.call((received / total).clamp(0, 1));
    }
  } finally {
    await sink.close();
  }
  if (await sha256Hex(file.openRead()) != expected) {
    await file.delete();
    throw UpdateException('Checksum mismatch for ${asset.name}');
  }
  return file;
}

/// Puts a verified download in place, per platform (spec: updates.md §5).
abstract class UpdateInstaller {
  /// The installer for the running platform.
  factory UpdateInstaller.forPlatform() {
    if (Platform.isAndroid) return AndroidUpdateInstaller();
    if (Platform.isLinux) return LinuxUpdateInstaller();
    if (Platform.isWindows) return WindowsUpdateInstaller();
    return const _NoInstaller();
  }

  UpdateInstaller._();

  /// Where downloads go.
  Future<Directory> downloadFolder() async => Directory(
    '${(await getTemporaryDirectory()).path}${Platform.pathSeparator}'
    'timetrack-update',
  );

  /// Whether the app can replace itself here; otherwise only the release
  /// page is opened.
  Future<bool> canSelfInstall();

  /// Installs [file]; `true` if a restart finishes it ([restart]).
  Future<bool> install(File file);

  /// Starts the new version and quits (desktop).
  Future<void> restart() async {}

  /// Removes what an earlier update left behind (called at start).
  Future<void> cleanUp() async {}
}

final class _NoInstaller implements UpdateInstaller {
  const _NoInstaller();

  @override
  Future<Directory> downloadFolder() async => Directory.systemTemp;

  @override
  Future<bool> canSelfInstall() async => false;

  @override
  Future<bool> install(File file) async => false;

  @override
  Future<void> restart() async {}

  @override
  Future<void> cleanUp() async {}
}

/// Hands the APK to Android's installer (Kotlin `UpdateInstaller.kt`).
final class AndroidUpdateInstaller extends UpdateInstaller {
  /// Creates the installer.
  AndroidUpdateInstaller() : super._();

  static const _channel = MethodChannel('timetrack/update');

  @override
  Future<bool> canSelfInstall() async => true;

  @override
  Future<bool> install(File file) async {
    if (!(await _channel.invokeMethod<bool>('canInstall') ?? false)) {
      await _channel.invokeMethod<void>('openInstallSettings');
      throw const InstallPermissionNeeded();
    }
    // Android shows its own confirmation; the app is replaced afterwards.
    await _channel.invokeMethod<void>('install', {'path': file.path});
    return false;
  }

  @override
  Future<void> cleanUp() async {
    final folder = await downloadFolder();
    if (await folder.exists()) await folder.delete(recursive: true);
  }
}

/// Whether files can be created in [dir].
Future<bool> _writable(Directory dir) async {
  try {
    final probe = File(
      '${dir.path}${Platform.pathSeparator}.timetrack-write-test',
    );
    await probe.writeAsString('');
    await probe.delete();
    return true;
  } on FileSystemException {
    return false;
  }
}

/// Swaps the unpacked tar.gz in for the running `bundle/` folder.
final class LinuxUpdateInstaller extends UpdateInstaller {
  /// Creates the installer for the app at [executable] (default: the
  /// running one).
  LinuxUpdateInstaller({String? executable})
    : executable = executable ?? Platform.resolvedExecutable,
      super._();

  /// The app's executable, taken before the swap moves it.
  final String executable;

  Directory get _install => File(executable).parent;
  Directory get _new => Directory('${_install.path}.new');
  Directory get _old => Directory('${_install.path}.old');

  @override
  Future<bool> canSelfInstall() async =>
      await _writable(_install) && await _writable(_install.parent);

  @override
  Future<bool> install(File file) async {
    await cleanUp();
    await _new.create();
    final tar = await Process.run('tar', ['-xzf', file.path, '-C', _new.path]);
    if (tar.exitCode != 0) {
      throw UpdateException('tar: ${tar.stderr}'.trim());
    }
    final bundle = Directory('${_new.path}/bundle');
    final name = executable.split('/').last;
    if (!await File('${bundle.path}/$name').exists()) {
      throw const UpdateException('Archive has no bundle/ with the app');
    }
    // A running program may be moved and replaced on Linux.
    await _install.rename(_old.path);
    try {
      await bundle.rename(_install.path);
    } on Object {
      await _old.rename(_install.path);
      rethrow;
    }
    await file.delete();
    return true;
  }

  @override
  Future<void> restart() async {
    await Process.start(executable, const [], mode: ProcessStartMode.detached);
    exit(0);
  }

  @override
  Future<void> cleanUp() async {
    for (final d in [_new, _old]) {
      if (await d.exists()) await d.delete(recursive: true);
    }
  }
}

/// Replaces the portable folder through a PowerShell script that runs after
/// the app quit (its exe and DLLs are locked while it runs).
final class WindowsUpdateInstaller extends UpdateInstaller {
  /// Creates the installer.
  WindowsUpdateInstaller() : super._();

  final String _exe = Platform.resolvedExecutable;
  File? _zip;

  Directory get _install => File(_exe).parent;

  @override
  Future<bool> canSelfInstall() => _writable(_install);

  @override
  Future<bool> install(File file) async {
    _zip = file;
    return true;
  }

  @override
  Future<void> restart() async {
    final zip = _zip;
    if (zip == null) return;
    final script = File('${zip.parent.path}\\update.ps1');
    await script.writeAsString(windowsUpdateScript);
    await Process.start('powershell', [
      '-NoProfile',
      '-ExecutionPolicy',
      'Bypass',
      '-WindowStyle',
      'Hidden',
      '-File',
      script.path,
      '-AppPid',
      '$pid',
      '-Zip',
      zip.path,
      '-Target',
      _install.path,
      '-Exe',
      _exe,
    ], mode: ProcessStartMode.detached);
    exit(0);
  }
}

/// The script behind [WindowsUpdateInstaller] (spec: updates.md §5). The old
/// version starts again if copying fails, so the app never disappears.
const windowsUpdateScript = r'''
param([int]$AppPid, [string]$Zip, [string]$Target, [string]$Exe)
$ErrorActionPreference = 'Stop'
try { Wait-Process -Id $AppPid -Timeout 60 -ErrorAction SilentlyContinue } catch {}
$tmp = Join-Path ([IO.Path]::GetTempPath()) ('timetrack-update-' + [guid]::NewGuid())
try {
  Expand-Archive -LiteralPath $Zip -DestinationPath $tmp -Force
  for ($i = 1; $i -le 3; $i++) {
    try {
      Copy-Item -Path (Join-Path $tmp '*') -Destination $Target -Recurse -Force
      break
    } catch {
      if ($i -eq 3) { throw }
      Start-Sleep -Seconds 2
    }
  }
  Remove-Item -LiteralPath $Zip -Force -ErrorAction SilentlyContinue
} finally {
  Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
  Start-Process -FilePath $Exe
}
''';
