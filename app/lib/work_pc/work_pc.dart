import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';

/// Whether Windows started the app at sign-in (`--autostart`, set by the
/// Run key the autostart setting writes; spec: work-pc.md §1).
final autostartedProvider = Provider<bool>((ref) => false);

/// The work PC glue of this platform, or `null` where there is none (only
/// Windows has the setting).
final workPcPlatformProvider = Provider<WorkPcPlatform?>(
  (ref) => Platform.isWindows ? WindowsWorkPc() : null,
);

/// Whether the app starts at sign-in (the Run key, work-pc.md §1).
final workPcEnabledProvider = FutureProvider<bool>(
  (ref) async => await ref.watch(workPcPlatformProvider)?.isEnabled() ?? false,
);

/// One entry of the tray menu (docs/specs/work-pc.md §3).
typedef TrayItem = ({
  String id,
  String label,
  bool enabled,
  bool checked,
  bool separator,
});

/// What the tray icon shows: its tooltip, grey while clocked out, and the
/// menu.
typedef TrayModel = ({String tooltip, bool idle, List<TrayItem> items});

/// Autostart at sign-in, the window and the tray icon.
abstract interface class WorkPcPlatform {
  /// Whether the app starts at sign-in.
  Future<bool> isEnabled();

  /// Turns the start at sign-in on or off.
  Future<void> setEnabled(bool on);

  /// Restores the (minimized or hidden) window and brings it to the front.
  Future<void> showWindow();

  /// Hides the window; the tray icon stays.
  Future<void> hideWindow();

  /// Shows or updates the tray icon.
  Future<void> setTray(TrayModel tray);

  /// Whether the close button hides the window to the tray.
  Future<void> setCloseToTray(bool on);

  /// Shows a Windows notification through the tray icon.
  Future<void> notify(String title, String body);

  /// Quits for real (tray menu, update), removing the tray icon.
  Future<void> quit();

  /// The ids of the tray menu items the user picks.
  Stream<String> get trayActions;
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

  @override
  Future<void> hideWindow() => _window.invokeMethod<void>('hide');

  @override
  Future<void> setTray(TrayModel tray) =>
      _window.invokeMethod<void>('setTray', {
        'tooltip': tray.tooltip,
        'idle': tray.idle,
        'items': [
          for (final i in tray.items)
            {
              'id': i.id,
              'label': i.label,
              'enabled': i.enabled,
              'checked': i.checked,
              'separator': i.separator,
            },
        ],
      });

  @override
  Future<void> setCloseToTray(bool on) =>
      _window.invokeMethod<void>('setCloseToTray', on);

  @override
  Future<void> notify(String title, String body) =>
      _window.invokeMethod<void>('notify', {'title': title, 'body': body});

  @override
  Future<void> quit() => _window.invokeMethod<void>('quit');

  @override
  late final Stream<String> trayActions = () {
    final actions = StreamController<String>.broadcast();
    _window.setMethodCallHandler((call) async {
      if (call.method == 'trayAction') actions.add(call.arguments as String);
    });
    return actions.stream;
  }();
}

/// Device-local `local_values` key: whether closing hides to the tray.
const closeToTrayKey = 'close_to_tray';

/// `local_values` key: ask after sign-in whether to start tracking
/// (work-pc.md §1).
const startPromptKey = 'start_prompt';

/// Whether an autostart asks to start tracking (default on, so setups from
/// before the autostart switch keep asking).
final startPromptProvider = FutureProvider<bool>((ref) async {
  final raw = await ref
      .watch(storeProvider)
      .transaction((tx) => tx.localValue(startPromptKey));
  return raw != 'false';
});

/// Whether the close button hides the window to the tray (default on).
final closeToTrayProvider = FutureProvider<bool>((ref) async {
  final raw = await ref
      .watch(storeProvider)
      .transaction((tx) => tx.localValue(closeToTrayKey));
  return raw != 'false';
});
