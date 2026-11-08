import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'format.dart';

// What back does (docs/specs/navigation.md), in this order:
// 1. close a sheet, dialog or the keyboard  (the navigators do this)
// 2. one page up within the tab             (the navigators do this)
// 3. reset the tab's view (week/month → now) [BackSteps]
// 4. the previously visited tab             [TabBackHandler]
// 5. on Today: ask once, then send the app to the background.

/// Steps a tab's root screen can take back before the tab is left, e.g.
/// the calendar returns to the current week. Keyed by branch index; a
/// screen registers while it is mounted.
abstract final class BackSteps {
  static final Map<int, bool Function()> _handlers = {};

  /// Registers [handler] for tab [branch]; it returns whether it handled
  /// the back press.
  static void register(int branch, bool Function() handler) =>
      _handlers[branch] = handler;

  /// Removes [handler] if it is still the registered one.
  static void unregister(int branch, bool Function() handler) {
    if (_handlers[branch] == handler) _handlers.remove(branch);
  }

  /// Lets tab [branch] handle a back press.
  static bool handle(int branch) => _handlers[branch]?.call() ?? false;
}

/// The route of [date]'s day view inside the current tab, so back returns
/// to where the user came from (Today or the calendar).
String dayLocation(BuildContext context, Object date) {
  final path = GoRouterState.of(context).uri.path;
  return path.startsWith('/today') ? '/today/day/$date' : '/calendar/day/$date';
}

/// Handles back once nothing can be popped any more: the tab's own step,
/// then the tab history, then (on Today) leaving after a second press.
class TabBackHandler extends StatefulWidget {
  /// Wraps the tab [shell].
  const TabBackHandler({super.key, required this.shell, required this.child});

  /// The tabs.
  final StatefulNavigationShell shell;

  /// The shell's layout.
  final Widget child;

  /// Sends the app to the background (Android); overridable in tests.
  @visibleForTesting
  static Future<void> Function() leaveApp = () async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final moved = await const MethodChannel('timetrack/system')
          .invokeMethod<bool>('moveToBack');
      if (moved == true) return;
    }
    await SystemNavigator.pop();
  };

  @override
  State<TabBackHandler> createState() => _TabBackHandlerState();
}

class _TabBackHandlerState extends State<TabBackHandler> {
  /// Tabs visited before the current one, most recent last.
  final List<int> _history = [];
  bool _goingBack = false;
  DateTime? _askedToLeave;

  @override
  void didUpdateWidget(TabBackHandler old) {
    super.didUpdateWidget(old);
    final from = old.shell.currentIndex, to = widget.shell.currentIndex;
    if (from == to) return;
    _history.remove(to);
    if (!_goingBack) {
      _history
        ..remove(from)
        ..add(from);
    }
    _goingBack = false;
  }

  void _onBack() {
    final shell = widget.shell;
    if (BackSteps.handle(shell.currentIndex)) return;
    if (_history.isNotEmpty || shell.currentIndex != 0) {
      _goingBack = true;
      shell.goBranch(_history.isEmpty ? 0 : _history.removeLast());
      return;
    }
    final now = DateTime.now();
    final asked = _askedToLeave;
    if (asked != null && now.difference(asked) < const Duration(seconds: 2)) {
      _askedToLeave = null;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      TabBackHandler.leaveApp();
      return;
    }
    _askedToLeave = now;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(context.l10n.backAgainToLeave),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _onBack();
    },
    child: widget.child,
  );
}
