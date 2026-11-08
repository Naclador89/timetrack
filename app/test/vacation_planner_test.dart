// spec: calculations.md §10.1
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timetrack/app/router.dart';
import 'package:timetrack_core/timetrack_core.dart';

import 'helpers.dart';

Future<void> fullTime(SyncedRepository repo) =>
    repo.write('work_schedules', 'w', {
      'valid_from': '2020-01-01',
      for (final d in ['mon', 'tue', 'wed', 'thu', 'fri']) 'minutes_$d': 480,
    });

void main() {
  testWidgets('planner: next year\'s bridge days, booked with one tap', (
    tester,
  ) async {
    final router = buildRouter();
    final (store, _) = await pumpApp(tester, router: router, seed: fullTime);
    router.go('/calendar/absences');
    await settle(tester);
    expect(find.text('Vacation planner'), findsOneWidget);
    // November 2026: none left this year (NRW).
    expect(find.text('No more bridge days in 2026'), findsOneWidget);
    await tester.tap(find.text('2027'));
    await settle(tester);

    // Ascension 2027 is Thursday 6 May.
    final bridge = find.ancestor(
      of: find.textContaining('Fri, 5/7'),
      matching: find.byType(ListTile),
    );
    expect(bridge, findsOneWidget);
    expect(
      find.descendant(
        of: bridge,
        matching: find.text('1 day off → 4 days free'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.descendant(of: bridge, matching: find.text('Book')));
    await settle(tester);
    expect(find.text('Vacation booked'), findsOneWidget);
    final absences = store.rowsOf('absences').values;
    expect(absences.single.fields['date'], '2027-05-07');
    expect(absences.single.fields['kind'], 'vacation');
    expect(bridge, findsNothing, reason: 'no longer suggested');
  });

  testWidgets('planner: a tap on a day adds an absence from there', (
    tester,
  ) async {
    final router = buildRouter();
    await pumpApp(tester, router: router, seed: fullTime);
    router.go('/calendar/absences');
    await settle(tester);
    final november20 = find.text('20').at(10);
    await tester.ensureVisible(november20);
    await tester.pumpAndSettle();
    await tester.tap(november20);
    await settle(tester);
    expect(find.widgetWithText(AlertDialog, 'Add absence'), findsOneWidget);
  });
}
