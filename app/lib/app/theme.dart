import 'package:flutter/material.dart';
import 'package:timetrack_core/timetrack_core.dart';

/// The app colour, the cyan in the middle of the icon's gradient; used
/// where there are no wallpaper colours (Linux, Windows, Android < 12, or
/// switched off).
const seedColor = Color(0xFF22D3EE);

/// The app theme for [scheme]: Material 3 with softer, flatter surfaces,
/// tabular figures and the same page transition on every platform.
ThemeData buildTheme(ColorScheme scheme) {
  final base = ThemeData(colorScheme: scheme, useMaterial3: true);
  final text = base.textTheme.apply(
    bodyColor: scheme.onSurface,
    displayColor: scheme.onSurface,
  );
  const radius = BorderRadius.all(Radius.circular(20));
  return base.copyWith(
    scaffoldBackgroundColor: scheme.surface,
    textTheme: text.copyWith(
      displayMedium: text.displayMedium?.copyWith(
        fontWeight: FontWeight.w600,
        fontFeatures: const [FontFeature.tabularFigures()],
        letterSpacing: -1,
      ),
      headlineSmall: text.headlineSmall?.copyWith(
        fontWeight: FontWeight.w600,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: const RoundedRectangleBorder(borderRadius: radius),
      margin: const EdgeInsets.symmetric(vertical: 6),
      clipBehavior: Clip.antiAlias,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 2,
      centerTitle: false,
      titleTextStyle: text.titleLarge?.copyWith(fontWeight: FontWeight.w600),
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: const StadiumBorder(),
      side: BorderSide(color: scheme.outlineVariant),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 48),
        shape: const StadiumBorder(),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 48),
        shape: const StadiumBorder(),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    dialogTheme: const DialogThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(28)),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surfaceContainer,
      indicatorColor: scheme.secondaryContainer,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
      },
    ),
  );
}

/// Colours that carry meaning: plus, minus and the day types.
extension SemanticColors on ColorScheme {
  /// A balance or difference: green-ish for plus, error for minus.
  Color deltaColor(int minutes) => minutes < 0
      ? error
      : minutes > 0
      ? (brightness == Brightness.dark
            ? const Color(0xFF7BD88F)
            : const Color(0xFF1B7F3B))
      : onSurfaceVariant;

  /// The tint of a day type (calendar dots, chips).
  Color dayTypeColor(DayType type) => _tone(switch (type) {
    DayType.office => 0,
    DayType.home => 1,
    DayType.businessTrip => 2,
    DayType.vacation => 3,
    DayType.sick || DayType.childSick => 4,
    DayType.flexTime => 5,
    DayType.shortTime => 6,
    DayType.specialLeave => 7,
  });

  /// A stable colour for a project, the same on every screen.
  Color projectColor(String projectId) =>
      _tone(projectId.codeUnits.fold(7, (h, c) => (h * 31 + c) & 0x7fffffff));

  Color _tone(int index) {
    const hues = [205.0, 145.0, 25.0, 50.0, 0.0, 275.0, 320.0, 175.0];
    final hue = hues[index % hues.length] + 13.0 * (index ~/ hues.length % 3);
    final dark = brightness == Brightness.dark;
    return HSLColor.fromAHSL(1, hue % 360, 0.55, dark ? 0.68 : 0.45).toColor();
  }
}
