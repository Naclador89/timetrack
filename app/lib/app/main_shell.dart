import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../update/update_banner.dart';
import '../widgets/command_palette.dart';
import '../widgets/shortcuts.dart';
import 'actions.dart';
import 'back_navigation.dart';
import 'format.dart';

/// Material 3 window classes (docs/specs/navigation.md, "Layout").
abstract final class WindowClass {
  /// From here on a navigation rail replaces the bottom bar.
  static const medium = 600.0;

  /// From here on the rail shows its labels beside the icons.
  static const expanded = 1200.0;
}

/// The app frame: bottom navigation on phones, a navigation rail on wider
/// windows (extended on wide ones); the keyboard shortcuts (Ctrl+K:
/// command palette) work everywhere.
class MainShell extends StatelessWidget {
  /// Creates the shell.
  const MainShell({super.key, required this.shell});

  /// The tab navigator.
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final items = [
      (Icons.today_outlined, Icons.today, l.navToday),
      (Icons.calendar_month_outlined, Icons.calendar_month, l.navCalendar),
      (Icons.luggage_outlined, Icons.luggage, l.navPlanner),
      (Icons.work_outline, Icons.work, l.navProjects),
      (Icons.assessment_outlined, Icons.assessment, l.navReports),
    ];
    void go(int i) {
      final again = i == shell.currentIndex;
      shell.goBranch(i, initialLocation: again);
      if (again) closeDetached(shell.route.branches[i]);
    }

    return TabBackHandler(
      shell: shell,
      child: AppShortcuts(shell: shell, child: _layout(context, items, go)),
    );
  }

  Widget _layout(
    BuildContext context,
    List<(IconData, IconData, String)> items,
    void Function(int) go,
  ) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= WindowClass.medium) {
      final extended = width >= WindowClass.expanded;
      final palette = '${context.l10n.commandPalette} (Ctrl+K)';
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: shell.currentIndex,
              onDestinationSelected: go,
              extended: extended,
              labelType: extended
                  ? NavigationRailLabelType.none
                  : NavigationRailLabelType.all,
              groupAlignment: -0.9,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: extended
                    ? FloatingActionButton.extended(
                        heroTag: 'palette',
                        elevation: 0,
                        tooltip: palette,
                        onPressed: () => showCommandPalette(context),
                        icon: const Icon(Icons.search),
                        label: Text(context.l10n.commandPalette),
                      )
                    : FloatingActionButton.small(
                        heroTag: 'palette',
                        elevation: 0,
                        tooltip: palette,
                        onPressed: () => showCommandPalette(context),
                        child: const Icon(Icons.search),
                      ),
              ),
              destinations: [
                for (final (icon, selected, label) in items)
                  NavigationRailDestination(
                    icon: Icon(icon),
                    selectedIcon: Icon(selected),
                    label: Text(label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: UpdateBannerHost(child: shell)),
          ],
        ),
      );
    }
    return Scaffold(
      body: UpdateBannerHost(child: shell),
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: go,
        destinations: [
          for (final (icon, selected, label) in items)
            NavigationDestination(
              icon: Icon(icon),
              selectedIcon: Icon(selected),
              label: label,
            ),
        ],
      ),
    );
  }
}

/// The tabs' navigators, all kept alive like an [IndexedStack]; the tab
/// that comes in fades through (Material motion), the others stay put.
class FadeThroughBranches extends StatefulWidget {
  /// Shows [children] at [index].
  const FadeThroughBranches({
    super.key,
    required this.index,
    required this.children,
  });

  /// The visible tab.
  final int index;

  /// One navigator per tab.
  final List<Widget> children;

  @override
  State<FadeThroughBranches> createState() => _FadeThroughBranchesState();
}

class _FadeThroughBranchesState extends State<FadeThroughBranches>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
    value: 1,
  );

  @override
  void didUpdateWidget(FadeThroughBranches old) {
    super.didUpdateWidget(old);
    if (old.index == widget.index) return;
    if (MediaQuery.disableAnimationsOf(context)) return;
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      for (final (i, child) in widget.children.indexed)
        Offstage(
          offstage: i != widget.index,
          child: TickerMode(
            enabled: i == widget.index,
            child: FadeThroughTransition(
              animation: i == widget.index
                  ? _controller
                  : kAlwaysCompleteAnimation,
              secondaryAnimation: kAlwaysDismissedAnimation,
              fillColor: Colors.transparent,
              child: child,
            ),
          ),
        ),
    ],
  );
}
