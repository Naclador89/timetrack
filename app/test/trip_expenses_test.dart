// spec: calculations.md §13.0–§13.5
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:timetrack/app/router.dart';
import 'package:timetrack_core/timetrack_core.dart';

import 'helpers.dart';

Future<void> _paris(
  SyncedRepository repo, [
  Map<String, Object?> more = const {},
]) => repo.write('trips', 't', {
  'depart_utc': '2026-11-02T05:00:00Z',
  'return_utc': '2026-11-03T17:00:00Z',
  'destination': 'Paris',
  'country': 'FR',
  'city': 'Paris',
  ...more,
});

void main() {
  testWidgets('§13.5 the expense report adds per-diem, lodging and mileage', (
    tester,
  ) async {
    final router = buildRouter();
    await pumpApp(
      tester,
      router: router,
      seed: (repo) => _paris(repo, {
        'lodging': 'flat',
        'car_km': 100,
        'order_kind': 'mo',
        'order_number': '4711',
      }),
    );
    router.go('/calendar/trips');
    await settle(tester);
    await tester.tap(find.byTooltip('Expense report'));
    await tester.pumpAndSettle();
    // Paris: 2 × 39 € partial, one night 159 €, 100 km × 0.30 €.
    expect(find.textContaining('Frankreich · Paris'), findsNWidgets(2));
    expect(find.textContaining('267.00'), findsOneWidget);
    expect(find.textContaining('159.00'), findsOneWidget);
    // Billed through the trip's order (data-model.md §9).
    expect(find.textContaining('MO 4711'), findsOneWidget);
  });

  testWidgets('§13.5 Today reminds to claim until marked as claimed', (
    tester,
  ) async {
    final (store, _) = await pumpApp(
      tester,
      seed: (repo) async {
        await saveSetting(repo, SettingKeys.claimDeadlineMonths, 3);
        await _paris(repo);
      },
    );
    expect(
      find.text('Claim the expenses of Paris by 2/3/2027'),
      findsOneWidget,
    );
    await tester.tap(find.text('Claimed'));
    await settle(tester);
    expect(find.textContaining('Claim the expenses'), findsNothing);
    expect(store.rowsOf('trips')['t']!.fields['claimed_on'], '2026-11-04');
  });

  testWidgets('§13.0 the trip dialog picks country and city', (tester) async {
    final router = buildRouter();
    final (store, _) = await pumpApp(tester, router: router);
    router.go('/calendar/trips');
    await settle(tester);
    await tester.tap(find.text('New trip'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Deutschland'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'paris');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Frankreich'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Paris'));
    await tester.pumpAndSettle();
    expect(find.text('Frankreich · Paris'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Own car'), '120');
    await tester.tap(find.text('Save'));
    await settle(tester);
    final trip = store.rowsOf('trips').values.single.fields;
    expect(
      (trip['country'], trip['city'], trip['car_km']),
      ('FR', 'Paris', 120),
    );
  });

  testWidgets('data-model.md §9 the trip dialog takes order and notes', (
    tester,
  ) async {
    final router = buildRouter();
    final (store, _) = await pumpApp(tester, router: router);
    router.go('/calendar/trips');
    await settle(tester);
    await tester.tap(find.text('New trip'));
    await tester.pumpAndSettle();
    // Each end of the trip is one heading with a date and a time field.
    expect(find.text('Departure'), findsOneWidget);
    expect(find.text('Return'), findsOneWidget);
    expect(find.text('Date'), findsNWidgets(2));
    expect(find.text('Time'), findsNWidgets(2));
    await tester.tap(find.text('GA'));
    await tester.enterText(
      find.widgetWithText(TextField, 'Order number'),
      ' 4711 ',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Notes'),
      'Bring the spare part\nCall ahead',
    );
    await tester.tap(find.text('Save'));
    await settle(tester);
    final trip = store.rowsOf('trips').values.single.fields;
    expect(
      (trip['order_kind'], trip['order_number'], trip['note']),
      ('ga', '4711', 'Bring the spare part\nCall ahead'),
    );
    expect(find.textContaining('Order GA 4711'), findsOneWidget);
    expect(find.textContaining('Bring the spare part'), findsOneWidget);

    // Picking the kind again clears it.
    await tester.tap(find.byIcon(Icons.luggage_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('GA'));
    await tester.tap(find.text('Save'));
    await settle(tester);
    expect(store.rowsOf('trips').values.single.fields['order_kind'], isNull);
  });

  testWidgets('§13.4 site allowance rates are entered per country', (
    tester,
  ) async {
    final (store, _) = await pumpApp(tester);
    final context = tester.element(find.byType(Scaffold).first);
    GoRouterHelper(context).push('/settings/site-allowance');
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Per site day'),
      '20',
    );
    await tester.tap(find.text('Save'));
    await settle(tester);
    final row = store.rowsOf('site_allowances').values.single.fields;
    expect((row['country'], row['cents']), ('*', 2000));
    expect(find.textContaining('All other countries'), findsOneWidget);
  });
}
