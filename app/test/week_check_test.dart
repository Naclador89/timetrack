// spec: calculations.md §12 (checking a week or month)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timetrack_core/timetrack_core.dart';

import 'helpers.dart';

/// Monday 8 h without a break or project, Tuesday 5 h without a project.
Future<void> untidyWeek(SyncedRepository repo) async {
  await repo.write('work_schedules', 'w', {
    'valid_from': '2026-01-01',
    for (final d in ['mon', 'tue', 'wed', 'thu', 'fri']) 'minutes_$d': 480,
  });
  for (final (id, day, end) in [('s1', '02', '15'), ('s2', '03', '12')]) {
    await repo.write('work_sessions', id, {
      'start_utc': '2026-11-${day}T07:00:00Z',
      'end_utc': '2026-11-${day}T$end:00:00Z',
      'location': 'office',
    });
  }
}

Future<void> openCalendar(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await settle(tester);
}

void main() {
  testWidgets('one card for the week, a line per day', (tester) async {
    await pumpApp(tester, seed: untidyWeek);
    await openCalendar(tester);
    expect(find.text('3 notices on 2 days'), findsOneWidget);
    expect(find.text('Check week'), findsOneWidget);
    expect(find.text('Add break'), findsNothing, reason: 'no card per notice');
  });

  testWidgets('checking: fix, hide and skip, one notice at a time', (
    tester,
  ) async {
    final (store, _) = await pumpApp(tester, seed: untidyWeek);
    await openCalendar(tester);
    await tester.tap(find.text('Check week'));
    await settle(tester);
    expect(find.text('1 of 3'), findsOneWidget);
    expect(find.text('8:00 without a project'), findsWidgets);
    await tester.tap(find.text('Skip'));
    await settle(tester);

    // Monday's missing break: the fix adds it.
    expect(find.text('2 of 3'), findsOneWidget);
    await tester.tap(find.text('Add break'));
    await settle(tester);
    await tester.tap(find.text('Save'));
    await settle(tester);
    expect(store.rowsOf('breaks'), hasLength(1));

    expect(find.text('3 of 3'), findsOneWidget);
    await tester.tap(find.text('Hide'));
    await settle(tester);
    expect(find.text('All done'), findsOneWidget);
    expect(find.text('1 skipped'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await settle(tester);
    expect(find.text('1 notice on 1 day'), findsOneWidget);
  });

  testWidgets('a clean week and month say so', (tester) async {
    await pumpApp(tester);
    await openCalendar(tester);
    expect(find.text('Week complete'), findsOneWidget);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit4);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await settle(tester);
    await tester.scrollUntilVisible(
      find.text('Month complete'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Month complete'), findsOneWidget);
  });
}
