// spec: calculations.md §6.1, §10, §10.1, §10.4, §10.5; navigation.md "Planer"
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
    router.go('/planner?show=absences');
    await settle(tester);
    expect(find.text('Trips & absences'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('No more bridge days in 2026'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    // November 2026: none left this year (NRW).
    expect(find.text('No more bridge days in 2026'), findsOneWidget);
    await tester.ensureVisible(find.text('2027'));
    await tester.pumpAndSettle();
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
    expect(
      find.descendant(of: bridge, matching: find.text('Book')),
      findsNothing,
      reason: 'no longer suggested',
    );
    // The planner lists it as an upcoming vacation.
    expect(find.text('Fri, 5/7\n1 day'), findsOneWidget);
  });

  testWidgets('planner: a tap on a day adds an absence from there', (
    tester,
  ) async {
    final router = buildRouter();
    await pumpApp(tester, router: router, seed: fullTime);
    router.go('/planner?show=absences');
    await settle(tester);
    final november20 = find.text('20').at(10);
    await tester.ensureVisible(november20);
    await tester.pumpAndSettle();
    await tester.tap(november20);
    await settle(tester);
    expect(find.widgetWithText(AlertDialog, 'Add absence'), findsOneWidget);
  });

  testWidgets('§10 §6.1 a vacation range in one control marks every date; '
      'only workdays count, Heiligabend and Silvester half', (tester) async {
    final router = buildRouter();
    final (store, _) = await pumpApp(tester, router: router, seed: fullTime);
    router.go('/planner?show=absences');
    await settle(tester);
    await tester.tap(find.text('Add absence'));
    await settle(tester);
    await tester.tap(find.byIcon(Icons.date_range));
    await settle(tester);
    final picker = find.byType(AlertDialog).last;
    expect(
      find.descendant(of: picker, matching: find.text('Tap the first day')),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Next month'));
    await settle(tester);
    await tester.tap(find.descendant(of: picker, matching: find.text('24')));
    await settle(tester);
    await tester.tap(find.descendant(of: picker, matching: find.text('31')));
    await settle(tester);
    // Closed after the second tap, without OK.
    expect(find.text('Tap the last day'), findsNothing);
    expect(find.text('Thu, 12/24 – Thu, 12/31'), findsOneWidget);
    // 24 ½ + 28, 29, 30 + 31 ½; 25/26 are holidays, 27 a Sunday.
    expect(find.text('Vacation days: 4'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await settle(tester);
    final dates = [
      for (final r in store.rowsOf('absences').values) r.fields['date'],
    ]..sort();
    expect(dates, [for (var d = 24; d <= 31; d++) '2026-12-$d']);
    expect(find.text('Thu, 12/24 – Thu, 12/31\n4 days'), findsOneWidget);
  });

  testWidgets('§10.5 the planner shows the state\'s school holidays', (
    tester,
  ) async {
    final router = buildRouter();
    final (store, _) = await pumpApp(tester, router: router, seed: fullTime);
    router.go('/planner?show=absences');
    await settle(tester);
    expect(find.text('School holidays'), findsWidgets, reason: 'legend');
    final christmas = find.ancestor(
      of: find.text('Weihnachtsferien').last,
      matching: find.byType(ListTile),
    );
    await tester.scrollUntilVisible(
      christmas,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Nordrhein-Westfalen'), findsOneWidget);
    expect(find.text('Source: OpenHolidays API (ODbL)'), findsOneWidget);
    // Past holidays offer nothing; the coming ones a vacation.
    final summer = find.ancestor(
      of: find.text('Sommerferien'),
      matching: find.byType(ListTile),
    );
    expect(
      find.descendant(of: summer, matching: find.byTooltip('Enter vacation')),
      findsNothing,
    );
    final plan = find.descendant(
      of: christmas,
      matching: find.byTooltip('Enter vacation'),
    );
    await tester.ensureVisible(plan);
    await tester.pumpAndSettle();
    await tester.tap(plan);
    await settle(tester);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Wed, 12/23 – 1/6/2027'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Save'));
    await settle(tester);
    final dates = [
      for (final r in store.rowsOf('absences').values) r.fields['date'],
    ]..sort();
    expect(
      (dates.first, dates.last, dates.length),
      ('2026-12-23', '2027-01-06', 15),
    );
  });

  testWidgets('§10.4 planner tab: trips and absence blocks in one list', (
    tester,
  ) async {
    await pumpApp(
      tester,
      seed: (repo) async {
        await fullTime(repo);
        for (var d = 16; d <= 20; d++) {
          await repo.write('absences', 'v$d', {
            'date': '2026-11-$d',
            'kind': 'vacation',
            'fraction': 1,
          });
        }
        await repo.write('trips', 't', {
          'depart_utc': '2026-11-02T05:00:00Z',
          'return_utc': '2026-11-03T17:00:00Z',
          'destination': 'Paris',
          'country': 'FR',
          'order_kind': 'sa',
          'order_number': '815',
        });
      },
    );
    await tester.tap(find.text('Planner').last);
    await settle(tester);
    expect(find.text('Trips & absences'), findsOneWidget);
    // A week of vacation is one entry, coming up.
    expect(find.text('Mon, 11/16 – Fri, 11/20\n5 days'), findsOneWidget);
    expect(find.text('in 12 days'), findsOneWidget);
    // The trip is past and still to claim.
    expect(find.textContaining('SA 815'), findsOneWidget);
    expect(find.text('1 trip still to claim'), findsOneWidget);

    await tester.tap(find.text('Absences'));
    await settle(tester);
    expect(find.textContaining('SA 815'), findsNothing);
    expect(find.text('Add absence'), findsOneWidget, reason: 'the button');

    // With both shown, "New" asks which.
    await tester.tap(find.text('All'));
    await settle(tester);
    await tester.tap(find.text('New'));
    await tester.pumpAndSettle();
    expect(find.text('New trip'), findsOneWidget);
    expect(find.text('Add absence'), findsOneWidget);
  });
}
