import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:timetrack_core/timetrack_core.dart';

import '../features/calendar/absences_screen.dart';
import '../features/calendar/day_screen.dart';
import '../features/calendar/trips_screen.dart';
import '../features/calendar/week_screen.dart';
import '../features/projects/project_screen.dart';
import '../features/projects/projects_screen.dart';
import '../features/reports/reports_screen.dart';
import '../features/settings/home_office_rules_screen.dart';
import '../features/settings/per_diem_rates_screen.dart';
import '../features/settings/schedules_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/settings/settings_sections.dart';
import '../features/settings/setup_wizard.dart';
import '../features/settings/site_allowance_screen.dart';
import '../features/settings/sync_log_screen.dart';
import '../features/settings/sync_screen.dart';
import '../features/today/today_screen.dart';
import '../update/update_banner.dart';
import '../widgets/command_palette.dart';
import '../widgets/shortcuts.dart';
import 'back_navigation.dart';
import 'format.dart';
import 'snack_bars.dart';

/// Routes. Each tab keeps its own navigation stack.
///
/// `--dart-define=INITIAL_ROUTE=/calendar` opens another screen first (for
/// screenshots and manual checks).
GoRouter buildRouter() => GoRouter(
  // Also reaches the tabs' navigators (notifyRootObserver).
  observers: [SnackBarDismisser()],
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
            GoRoute(
              path: '/today',
              builder: (_, _) => const TodayScreen(),
              routes: [
                // The day opened from Today stays in this tab, so back
                // returns to Today (docs/specs/navigation.md).
                GoRoute(
                  path: 'day/:date',
                  builder: (_, s) => DayScreen(
                    date: LocalDate.parse(s.pathParameters['date']!),
                  ),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/calendar',
              builder: (_, state) => WeekScreen(
                month: state.uri.queryParameters['view'] == 'month',
              ),
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
              routes: [
                GoRoute(
                  path: ':id',
                  builder: (_, state) =>
                      ProjectScreen(id: state.pathParameters['id']!),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/reports', builder: (_, _) => const ReportsScreen()),
          ],
        ),
      ],
    ),
    // Settings and the setup wizard open over the tabs (gear icon). Settings
    // shows the update banner too: an update started there must stay visible.
    GoRoute(
      path: '/settings',
      builder: (_, _) => const UpdateBannerHost(child: SettingsScreen()),
      routes: [
        for (final section in SettingsSection.values)
          GoRoute(path: section.path, builder: (_, _) => SettingsPage(section)),
        GoRoute(path: 'schedules', builder: (_, _) => const SchedulesScreen()),
        GoRoute(
          path: 'sync',
          builder: (_, _) => const SyncScreen(),
          routes: [
            GoRoute(path: 'log', builder: (_, _) => const SyncLogScreen()),
          ],
        ),
        GoRoute(
          path: 'home-office',
          builder: (_, _) => const HomeOfficeRulesScreen(),
        ),
        GoRoute(
          path: 'per-diem',
          builder: (_, _) => const PerDiemRatesScreen(),
        ),
        GoRoute(
          path: 'site-allowance',
          builder: (_, _) => const SiteAllowanceScreen(),
        ),
      ],
    ),
    GoRoute(path: '/setup', builder: (_, _) => const SetupWizard()),
  ],
);

/// Bottom navigation on phones, a navigation rail on wider windows; the
/// keyboard shortcuts (Ctrl+K: command palette) work everywhere.
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
      (Icons.assessment_outlined, Icons.assessment, l.navReports),
    ];
    void go(int i) =>
        shell.goBranch(i, initialLocation: i == shell.currentIndex);
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
    if (MediaQuery.sizeOf(context).width >= 720) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: shell.currentIndex,
              onDestinationSelected: go,
              labelType: NavigationRailLabelType.all,
              groupAlignment: -0.9,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: FloatingActionButton.small(
                  heroTag: 'palette',
                  elevation: 0,
                  tooltip: '${context.l10n.commandPalette} (Ctrl+K)',
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
