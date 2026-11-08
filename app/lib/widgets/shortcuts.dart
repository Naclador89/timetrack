import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/actions.dart';
import '../app/format.dart';
import '../app/providers.dart';
import '../sync/sync_controller.dart';
import 'command_palette.dart';
import 'quick_entry_sheet.dart';

/// The keyboard shortcuts on desktops (docs/specs/navigation.md): the
/// app-wide ones here, ←/→, T and M on the page that registered [PageKeys].
class AppShortcuts extends ConsumerWidget {
  /// Wraps the tab [shell]'s [child].
  const AppShortcuts({super.key, required this.shell, required this.child});

  /// The tabs, for Ctrl+1…4.
  final StatefulNavigationShell shell;

  /// The app content.
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void tab(int i) => shell.goBranch(i);
    final page = PageKeys._visible;
    final keys = <ShortcutActivator, VoidCallback>{
      const SingleActivator(LogicalKeyboardKey.keyK, control: true): () =>
          showCommandPalette(context),
      const SingleActivator(LogicalKeyboardKey.keyK, meta: true): () =>
          showCommandPalette(context),
      const SingleActivator(LogicalKeyboardKey.keyE, control: true): () =>
          toggleClock(context, ref),
      const SingleActivator(LogicalKeyboardKey.keyP, control: true): () =>
          toggleBreak(context, ref),
      const SingleActivator(LogicalKeyboardKey.keyB, control: true): () =>
          bookTime(context, ref),
      const SingleActivator(LogicalKeyboardKey.keyJ, control: true): () =>
          showQuickEntrySheet(context, ref.read(todayProvider)),
      const SingleActivator(LogicalKeyboardKey.digit1, control: true): () =>
          tab(0),
      const SingleActivator(LogicalKeyboardKey.digit2, control: true): () =>
          tab(1),
      const SingleActivator(LogicalKeyboardKey.digit3, control: true): () =>
          tab(2),
      const SingleActivator(LogicalKeyboardKey.digit4, control: true): () =>
          tab(3),
      const SingleActivator(LogicalKeyboardKey.comma, control: true): () =>
          GoRouter.of(context).push('/settings'),
      const SingleActivator(LogicalKeyboardKey.f5): () {
        if (ref.read(syncControllerProvider).phase != SyncPhase.notConfigured) {
          ref.read(syncControllerProvider.notifier).syncNow();
        }
      },
      const SingleActivator(LogicalKeyboardKey.f1): () =>
          showShortcutHelp(context),
    };
    // Plain keys: only while not typing, so "t" still reaches a text field.
    final plain = <ShortcutActivator, VoidCallback>{
      const CharacterActivator('?'): () => showShortcutHelp(context),
      const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
          page()?.widget.onPrevious(),
      const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
          page()?.widget.onNext(),
      const SingleActivator(LogicalKeyboardKey.keyT): () =>
          page()?.widget.onToday(),
      const SingleActivator(LogicalKeyboardKey.keyM): () =>
          page()?.widget.onToggleView?.call(),
    };
    return Shortcuts(
      shortcuts: {
        for (final MapEntry(:key, :value) in keys.entries)
          key: _KeyIntent(value, plain: false),
        for (final MapEntry(:key, :value) in plain.entries)
          key: _KeyIntent(value, plain: true),
      },
      child: Actions(
        actions: {_KeyIntent: _KeyAction()},
        child: Focus(autofocus: true, child: child),
      ),
    );
  }
}

class _KeyIntent extends Intent {
  const _KeyIntent(this.run, {required this.plain});

  final VoidCallback run;
  final bool plain;
}

class _KeyAction extends Action<_KeyIntent> {
  // A disabled action leaves the key to the text field.
  @override
  bool isEnabled(_KeyIntent intent) => !intent.plain || !_typing();

  @override
  void invoke(_KeyIntent intent) => intent.run();

  static bool _typing() {
    final context = FocusManager.instance.primaryFocus?.context;
    return context != null &&
        (context.widget is EditableText ||
            context.findAncestorStateOfType<EditableTextState>() != null);
  }
}

/// What ←/→, T and M do on a page (calendar week/month, day). The page that
/// is visible (not covered, not in a hidden tab) and registered last wins.
class PageKeys extends StatefulWidget {
  /// Wraps [child].
  const PageKeys({
    super.key,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
    this.onToggleView,
    required this.child,
  });

  /// ←: the previous week, month or day.
  final VoidCallback onPrevious;

  /// →: the next one.
  final VoidCallback onNext;

  /// T: back to today.
  final VoidCallback onToday;

  /// M: week ↔ month.
  final VoidCallback? onToggleView;

  /// The page.
  final Widget child;

  static final _pages = <_PageKeysState>[];

  static _PageKeysState? _visible() => _pages.reversed
      .where((p) => p._shown?.value.enabled ?? false)
      .firstOrNull;

  @override
  State<PageKeys> createState() => _PageKeysState();
}

class _PageKeysState extends State<PageKeys> {
  ValueListenable<TickerModeData>? _shown;

  @override
  void initState() {
    super.initState();
    PageKeys._pages.add(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Hidden tabs and covered routes have their tickers switched off.
    _shown = TickerMode.getValuesNotifier(context);
  }

  @override
  void dispose() {
    PageKeys._pages.remove(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Lists the keyboard shortcuts.
Future<void> showShortcutHelp(BuildContext context) => showDialog<void>(
  context: context,
  builder: (context) {
    final l = context.l10n;
    final rows = [
      ('Ctrl+K', l.commandPalette),
      ('Ctrl+E', l.keysClock),
      ('Ctrl+P', l.keysBreak),
      ('Ctrl+B', l.bookProjectTime),
      ('Ctrl+J', l.quickEntry),
      ('Ctrl+1…4', l.keysTabs),
      ('Ctrl+,', l.navSettings),
      ('F5', l.syncNow),
      ('← →', l.keysPrevNext),
      ('T', l.goToToday),
      ('M', l.keysWeekMonth),
      ('F1 / ?', l.keysHelp),
    ];
    final mono = Theme.of(context).textTheme.labelLarge;
    return AlertDialog(
      title: Text(l.keyboardShortcuts),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Table(
            columnWidths: const {0: IntrinsicColumnWidth()},
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              for (final (keys, what) in rows)
                TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(0, 6, 16, 6),
                      child: Text(keys, style: mono),
                    ),
                    Text(what),
                  ],
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).closeButtonLabel),
        ),
      ],
    );
  },
);
