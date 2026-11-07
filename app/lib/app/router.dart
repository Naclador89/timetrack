import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:timetrack_core/timetrack_core.dart';

import '../features/calendar/absences_screen.dart';
import '../features/calendar/day_screen.dart';
import '../features/calendar/trips_screen.dart';
import '../features/calendar/week_screen.dart';
import '../features/projects/projects_screen.dart';
import '../features/settings/home_office_rules_screen.dart';
import '../features/settings/schedules_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/settings/sync_screen.dart';
import '../features/today/today_screen.dart';
import 'format.dart';

/// Routes. Each tab keeps its own navigation stack.
///
/// `--dart-define=INITIAL_ROUTE=/calendar` opens another screen first (for
/// screenshots and manual checks).
GoRouter buildRouter() => GoRouter(
  initialLocation: const String.fromEnvironment(
    'INITIAL_ROUTE',
    defaultValue: '/today',
  ),
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => AdaptiveShell(shell: shell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/today', builder: (_, _) => const TodayScreen()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/calendar',
              builder: (_, _) => const WeekScreen(),
              routes: [
                GoRoute(
                  path: 'day/:date',
                  builder: (_, s) => DayScreen(
                    date: LocalDate.parse(s.pathParameters['date']!),
                  ),
                ),
                GoRoute(
                  path: 'absences',
                  builder: (_, _) => const AbsencesScreen(),
                ),
                GoRoute(path: 'trips', builder: (_, _) => const TripsScreen()),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/projects',
              builder: (_, _) => const ProjectsScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/settings',
              builder: (_, _) => const SettingsScreen(),
              routes: [
                GoRoute(
                  path: 'schedules',
                  builder: (_, _) => const SchedulesScreen(),
                ),
                GoRoute(path: 'sync', builder: (_, _) => const SyncScreen()),
                GoRoute(
                  path: 'home-office',
                  builder: (_, _) => const HomeOfficeRulesScreen(),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ],
);

/// Bottom navigation on phones, a navigation rail on wider windows.
class AdaptiveShell extends StatelessWidget {
  /// Creates the shell.
  const AdaptiveShell({super.key, required this.shell});

  /// The tab navigator.
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final items = [
      (Icons.today_outlined, Icons.today, l.navToday),
      (Icons.calendar_month_outlined, Icons.calendar_month, l.navCalendar),
      (Icons.work_outline, Icons.work, l.navProjects),
      (Icons.settings_outlined, Icons.settings, l.navSettings),
    ];
    void go(int i) =>
        shell.goBranch(i, initialLocation: i == shell.currentIndex);
    if (MediaQuery.sizeOf(context).width >= 720) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: shell.currentIndex,
              onDestinationSelected: go,
              labelType: NavigationRailLabelType.all,
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
            Expanded(child: shell),
          ],
        ),
      );
    }
    return Scaffold(
      body: shell,
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
