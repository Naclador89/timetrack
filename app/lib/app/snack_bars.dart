import 'package:flutter/material.dart';

/// Hides the current snack bar when a dialog, sheet or menu opens.
///
/// Snack bars live in the shell's scaffold, below the tab's navigator, so an
/// "Undo" left over from before would sit on top of a bottom sheet opened in
/// that tab and cover its buttons.
class SnackBarDismisser extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is! PopupRoute) return;
    final context = route.navigator?.context;
    if (context == null) return;
    ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
  }
}
