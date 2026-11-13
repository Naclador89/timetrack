import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:timetrack/app/router.dart';
import 'package:timetrack/widgets/balance_zone.dart';
import 'package:timetrack_core/timetrack_core.dart';

import 'helpers.dart';

Future<void> _schedule(SyncedRepository repo, String from) =>
    repo.write('work_schedules', 'w', {
      'valid_from': from,
      for (final d in ['mon', 'tue', 'wed', 'thu', 'fri']) 'minutes_$d': 480,
      'vacation_days': 30,
    });

void main() {
  // spec: calculations.md §20.1
  testWidgets('§20.1 the balance on Today gets the zone dot', (tester) async {
    await pumpApp(
      tester,
      seed: (repo) async {
        await _schedule(repo, '2026-11-02');
        await saveSetting(repo, SettingKeys.balanceStartDate, '2026-11-02');
        await saveSetting(repo, SettingKeys.startingBalance, 330 * 60);
        await saveSetting(repo, SettingKeys.balanceYellowPlus, 300 * 60);
        await saveSetting(repo, SettingKeys.balanceRedPlus, 350 * 60);
      },
    );
    // Nothing worked Mon to Wed: 330 h − 24 h, still yellow.
    expect(find.byType(BalanceZoneDot), findsOneWidget);
    expect(find.byTooltip('Yellow zone'), findsOneWidget);
  });

  testWidgets('§20.1 entering yellow on a finished day is a notice', (
    tester,
  ) async {
    await pumpApp(
      tester,
      seed: (repo) async {
        await _schedule(repo, '2026-11-02');
        await saveSetting(repo, SettingKeys.balanceStartDate, '2026-11-02');
        await saveSetting(repo, SettingKeys.startingBalance, 303 * 60);
        await saveSetting(repo, SettingKeys.balanceYellowPlus, 300 * 60);
        // Mon unworked (295 h), Tue 14 h at work (+6 h → 301 h).
        await repo.write('work_sessions', 's', {
          'start_utc': '2026-11-03T05:00:00Z',
          'end_utc': '2026-11-03T19:00:00Z',
          'location': 'office',
        });
      },
    );
    // Today shows yesterday's notices; today's balance is green again.
    expect(find.textContaining('yellow zone (+301:00)'), findsOneWidget);
    expect(find.byTooltip('Green zone'), findsOneWidget);
  });

  // spec: calculations.md §10.2
  testWidgets('§10.2 Today shows vacation left from last year', (tester) async {
    await pumpApp(
      tester,
      clock: () => DateTime.utc(2027, 1, 13, 8),
      seed: (repo) async {
        await _schedule(repo, '2026-01-01');
        await saveSetting(repo, SettingKeys.vacationCarryOver(2027), 4);
        await repo.write('absences', 'a', {
          'date': '2027-02-01',
          'kind': 'vacation',
          'fraction': 1,
        });
      },
    );
    expect(find.text('Vacation left from 2026'), findsOneWidget);
    expect(
      find.text('3 days still to take or plan by 3/31/2027.'),
      findsOneWidget,
    );
  });

  testWidgets('§10.2 the carry-over is entered, last year\'s rest suggested', (
    tester,
  ) async {
    final router = buildRouter();
    final (store, _) = await pumpApp(
      tester,
      router: router,
      seed: (repo) async {
        await _schedule(repo, '2026-01-01');
        await repo.write('absences', 'a', {
          'date': '2026-12-21',
          'kind': 'vacation',
          'fraction': 1,
        });
      },
    );
    router.go('/planner?show=absences');
    await settle(tester);
    await tester.tap(find.byTooltip('2027'));
    await settle(tester);
    await tester.tap(find.byTooltip('Vacation days carried over'));
    await tester.pumpAndSettle();
    expect(find.text('Vacation carried into 2027'), findsOneWidget);
    // 30 days in 2026, one planned.
    expect(
      find.descendant(of: find.byType(AlertDialog), matching: find.text('29')),
      findsOneWidget,
    );
    await tester.tap(find.text('Save'));
    await settle(tester);
    expect(
      store
          .rowsOf('settings')[SettingKeys.vacationCarryOver(2027)]!
          .fields['value'],
      29,
    );
  });

  testWidgets('§20 the limits are entered in hours', (tester) async {
    final (store, _) = await pumpApp(tester);
    final context = tester.element(find.byType(Scaffold).first);
    GoRouterHelper(context).push('/settings/account');
    await tester.pumpAndSettle();
    final tile = find.text('Time account zones');
    await tester.scrollUntilVisible(
      tile,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(tile);
    await tester.pumpAndSettle();
    await tester.tap(tile);
    await tester.pumpAndSettle();
    final fields = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(fields.at(0), '300');
    await tester.enterText(fields.at(5), '200');
    await tester.tap(find.text('Save'));
    await settle(tester);
    final rows = await tester.runAsync(
      () => store.watchRows(syncedTables).first,
    );
    final s = AppSettings.fromRows(rows!);
    expect(s.balanceLimits.yellowPlus, 18000);
    expect(s.balanceLimits.maxMinus, 12000);
    expect(s.balanceLimits.redPlus, isNull);
    expect(find.text('Yellow above +300 · Limit −200'), findsOneWidget);
  });
}
