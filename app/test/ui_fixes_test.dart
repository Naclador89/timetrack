import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:timetrack/widgets/interval_dialog.dart';
import 'package:timetrack_core/timetrack_core.dart';

import 'helpers.dart';
import 'week_check_test.dart' show openCalendar, untidyWeek;

Future<void> openMonth(WidgetTester tester) async {
  await openCalendar(tester);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
  await settle(tester);
}

void main() {
  testWidgets('a left-over snack bar goes away when a sheet opens', (
    tester,
  ) async {
    await pumpApp(tester);
    final context = tester.element(find.byType(Scaffold).first);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Deleted'),
        persist: false,
        action: SnackBarAction(label: 'Undo', onPressed: () {}),
      ),
    );
    await settle(tester);
    expect(find.text('Deleted'), findsOneWidget);
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => const Text('Sheet'),
    );
    await settle(tester);
    expect(find.text('Sheet'), findsOneWidget);
    expect(find.text('Deleted'), findsNothing);
  });

  testWidgets('§4.1 a new break starts as the usual break', (tester) async {
    await pumpApp(
      tester,
      seed: (repo) async {
        await saveSetting(repo, SettingKeys.defaultBreakStart, 13 * 60);
        await saveSetting(repo, SettingKeys.defaultBreakMinutes, 45);
      },
    );
    final context = tester.element(find.byType(Scaffold).first);
    showIntervalDialog(
      context,
      date: LocalDate(2026, 11, 4),
      table: 'breaks',
    ).ignore();
    await settle(tester);
    expect(find.text('13:00'), findsOneWidget);
    expect(find.text('13:45'), findsOneWidget);
  });

  testWidgets('month: hours per day, the week column opens the week', (
    tester,
  ) async {
    await pumpApp(tester, seed: untidyWeek);
    await openMonth(tester);
    expect(find.text('November 2026'), findsOneWidget);
    expect(find.text('8:00'), findsWidgets, reason: 'Monday worked');
    expect(find.text('5:00'), findsOneWidget, reason: 'Tuesday worked');
    await tester.tap(find.text('45'));
    await settle(tester);
    expect(find.text('Week 45'), findsOneWidget);
  });

  testWidgets('month: fits a phone without overflow', (tester) async {
    tester.view.physicalSize = const Size(360 * 3, 760 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await pumpApp(tester, seed: untidyWeek);
    await openMonth(tester);
    expect(find.text('November 2026'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('§8 a month before the balance start shows no target', (
    tester,
  ) async {
    await pumpApp(
      tester,
      seed: (repo) async {
        // The schedule from January (vacation account), the balance from
        // November: October counts nothing.
        await repo.write('work_schedules', 'w', {
          'valid_from': '2026-01-01',
          for (final d in ['mon', 'tue', 'wed', 'thu', 'fri'])
            'minutes_$d': 480,
        });
        await saveSetting(repo, SettingKeys.balanceStartDate, '2026-11-01');
        await saveSetting(repo, SettingKeys.startingBalance, 600);
      },
    );
    await openMonth(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await settle(tester);
    expect(find.text('October 2026'), findsOneWidget);
    expect(find.textContaining('Before the balance starts'), findsOneWidget);
    expect(find.textContaining('176'), findsNothing);
    expect(find.textContaining('−8:00'), findsNothing);
  });

  testWidgets('§15 a day type picked by mistake can be removed, with undo', (
    tester,
  ) async {
    await pumpApp(
      tester,
      seed: (repo) => setDayType(
        repo,
        LocalDate(2026, 11, 7),
        DayType.vacation,
        zone: HomeTimeZone(),
      ),
    );
    final context = tester.element(find.byType(Scaffold).first);
    GoRouterHelper(context).go('/calendar/day/2026-11-07');
    await settle(tester);
    await tester.tap(find.widgetWithText(ActionChip, 'Vacation'));
    await settle(tester);
    await tester.tap(find.text('Remove day type'));
    await settle(tester);
    expect(find.text('Day type removed'), findsOneWidget);
    expect(find.widgetWithText(ActionChip, 'Day type'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await settle(tester);
    expect(find.widgetWithText(ActionChip, 'Vacation'), findsOneWidget);
  });
}
