import 'dart:io';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timetrack_core/timetrack_core.dart';

import 'providers.dart';

/// Light, dark or the system's choice, and whether Android's wallpaper
/// colours replace the app colours. A device setting, not synced: the
/// phone may be dark while the work PC is light.
final class Appearance {
  /// Creates the appearance; the defaults follow the system.
  const Appearance({this.mode = ThemeMode.system, this.wallpaperColors = true});

  /// `local_values` keys.
  static const modeKey = 'theme_mode', wallpaperKey = 'wallpaper_colors';

  /// Light, dark or system.
  final ThemeMode mode;

  /// Material You colours on Android 12+.
  final bool wallpaperColors;

  /// Reads the stored appearance (before the first frame, so nothing
  /// flashes in the wrong theme).
  static Future<Appearance> load(SyncStore store) => store.transaction(
    (tx) async => Appearance(
      mode:
          ThemeMode.values.asNameMap()[await tx.localValue(modeKey)] ??
          ThemeMode.system,
      wallpaperColors: await tx.localValue(wallpaperKey) != 'false',
    ),
  );
}

/// The appearance read at start; `main()` overrides it.
final initialAppearanceProvider = Provider<Appearance>(
  (ref) => const Appearance(),
);

/// The current appearance; changes are stored on this device.
final appearanceProvider = NotifierProvider<AppearanceController, Appearance>(
  AppearanceController.new,
);

/// Holds and stores the [Appearance].
class AppearanceController extends Notifier<Appearance> {
  @override
  Appearance build() => ref.read(initialAppearanceProvider);

  /// Switches light, dark or system.
  Future<void> setMode(ThemeMode mode) async {
    state = Appearance(mode: mode, wallpaperColors: state.wallpaperColors);
    await ref
        .read(storeProvider)
        .transaction((tx) => tx.setLocalValue(Appearance.modeKey, mode.name));
  }

  /// Switches the wallpaper colours on or off.
  Future<void> setWallpaperColors(bool on) async {
    state = Appearance(mode: state.mode, wallpaperColors: on);
    await ref
        .read(storeProvider)
        .transaction((tx) => tx.setLocalValue(Appearance.wallpaperKey, '$on'));
  }
}

/// Whether this device has wallpaper colours (Android 12+), so the switch
/// is worth showing.
final wallpaperColorsAvailableProvider = FutureProvider<bool>((ref) async {
  if (!Platform.isAndroid) return false;
  try {
    return await DynamicColorPlugin.getCorePalette() != null;
  } on Object {
    return false;
  }
});
