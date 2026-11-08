import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether Windows started the app at sign-in (`--autostart`, set by the
/// Run key the work PC setting writes; spec: work-pc.md §1).
final autostartedProvider = Provider<bool>((ref) => false);

/// The work PC glue of this platform, or `null` where there is none (only
/// Windows has the setting).
final workPcPlatformProvider = Provider<WorkPcPlatform?>(
  (ref) => Platform.isWindows ? WindowsWorkPc() : null,
);

/// Whether the work PC setting is on.
final workPcEnabledProvider = FutureProvider<bool>(
  (ref) async => await ref.watch(workPcPlatformProvider)?.isEnabled() ?? false,
);

/// Autostart at sign-in and bringing the window to the front.
abstract interface class WorkPcPlatform {
  /// Whether the app starts at sign-in.
  Future<bool> isEnabled();

  /// Turns the start at sign-in on or off.
  Future<void> setEnabled(bool on);

  /// Restores the (minimized) window and brings it to the front.
  Future<void> showWindow();
}

/// The Run key under HKCU: per user, no admin rights, and Windows lists it
/// under Task Manager → Startup apps, where it can be switched off as well.
final class WindowsWorkPc implements WorkPcPlatform {
  static const _runKey = r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run';
  static const _value = 'TimeTrack';
  static const _window = MethodChannel('timetrack/window');

  /// What the Run key starts: this exe, so it follows the update in place.
  String get command => '"${Platform.resolvedExecutable}" --autostart';

  @override
  Future<bool> isEnabled() async {
    final r = await Process.run('reg', ['query', _runKey, '/v', _value]);
    if (r.exitCode != 0) return false;
    // "    TimeTrack    REG_SZ    "C:\...\timetrack.exe" --autostart"
    final line = '${r.stdout}'
        .split('\n')
        .firstWhere((l) => l.contains('REG_SZ'), orElse: () => '');
    final stored = line.split('REG_SZ').last.trim();
    // A moved folder shows as off; switching it on again repairs it.
    return stored.toLowerCase() == command.toLowerCase();
  }

  @override
  Future<void> setEnabled(bool on) async {
    final r = await Process.run(
      'reg',
      on
          ? ['add', _runKey, '/v', _value, '/t', 'REG_SZ', '/d', command, '/f']
          : ['delete', _runKey, '/v', _value, '/f'],
    );
    // Deleting a missing value fails, which is fine: it's off.
    if (on && r.exitCode != 0) {
      throw ProcessException('reg', const [], '${r.stderr}', r.exitCode);
    }
  }

  @override
  Future<void> showWindow() => _window.invokeMethod<void>('show');
}
