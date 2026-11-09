// spec: navigation.md "Layout", "Today tiles", "Motion"
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timetrack/app/theme.dart';
import 'package:timetrack/features/today/dashboard.dart';
import 'package:timetrack/widgets/dashboard_tile.dart';
import 'package:timetrack/widgets/staggered.dart';
import 'package:timetrack_core/timetrack_core.dart';

import 'helpers.dart';

/// 8 h Mon–Fri and 30 vacation days from Monday 2 Nov; 4 h worked that day.
Future<void> _week(SyncedRepository repo) async {
  await repo.write('work_schedules', 'w', {
    'valid_from': '2026-11-02',
    for (final d in ['mon', 'tue', 'wed', 'thu', 'fri']) 'minutes_$d': 480,
    'vacation_days': 30,
  });
  await saveSetting(repo, SettingKeys.balanceStartDate, '2026-11-02');
  await repo.write('work_sessions', 's', {
    'start_utc': '2026-11-02T07:00:00Z',
    'end_utc': '2026-11-02T11:00:00Z',
    'location': 'office',
  });
}

Finder _tile(String title) => find.widgetWithText(DashboardTile, title);

void main() {
  testWidgets('Today tiles: account, week and vacation with their figures', (
    tester,
  ) async {
    await pumpApp(tester, seed: _week);
    expect(_tile('Time account'), findsOneWidget);
    expect(
      find.descendant(of: _tile('This week'), matching: find.text('4:00')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: _tile('This week'), matching: find.text('of 40:00')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: _tile('Vacation'), matching: find.text('30')),
      findsOneWidget,
    );
    // No home-office rule, no quota tile.
    expect(_tile('Home office'), findsNothing);
  });

  testWidgets('a tile grows into its detail screen; back returns to Today', (
    tester,
  ) async {
    await pumpApp(tester, seed: _week);
    await tester.tap(_tile('This week'));
    await tester.pumpAndSettle();
    expect(find.byType(WeekDetailScreen), findsOneWidget);
    expect(find.text('Monday, November 2'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(WeekDetailScreen), findsNothing);

    await tester.tap(_tile('Time account'));
    await tester.pumpAndSettle();
    expect(find.byType(BalanceDetailScreen), findsOneWidget);
    expect(find.text('November 2026'), findsOneWidget);
    // Android back closes the detail first (navigation.md: one page up).
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(BalanceDetailScreen), findsNothing);
    expect(find.byType(DashboardGrid), findsOneWidget);
    expect(find.text('Press back again to leave'), findsNothing);
  });

  testWidgets('narrow windows get a bottom bar, wide ones an extended rail', (
    tester,
  ) async {
    await pumpApp(tester);
    NavigationRail rail() => tester.widget(find.byType(NavigationRail));
    expect(rail().extended, isTrue, reason: '1200 px');

    tester.view.physicalSize = const Size(900, 1600);
    await tester.pumpAndSettle();
    expect(rail().extended, isFalse);

    tester.view.physicalSize = const Size(400, 800);
    await tester.pumpAndSettle();
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('cards stagger in, but not with reduced motion', (tester) async {
    Widget cards({required bool still}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: still),
        child: Builder(
          builder: (context) => Column(
            children: [const Text('a'), const Text('b')].staggered(context),
          ),
        ),
      ),
    );
    await tester.pumpWidget(cards(still: false));
    expect(find.byType(Animate), findsNWidgets(2));
    await tester.pumpAndSettle();
    await tester.pumpWidget(cards(still: true));
    expect(find.byType(Animate), findsNothing);
    expect(find.text('b'), findsOneWidget);
  });

  test('semantic colours follow the scheme', () {
    for (final b in Brightness.values) {
      final scheme = buildTheme(fallbackScheme(b)).colorScheme;
      expect(scheme.deltaColor(1), scheme.positive);
      expect(scheme.deltaColor(-1), scheme.error);
      expect(scheme.inkOn(scheme.primary), isNot(scheme.primary));
    }
  });
}
