import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:timetrack/app/providers.dart';
import 'package:timetrack/app/router.dart';
import 'package:timetrack/main.dart';
import 'package:timetrack/sync/sync_controller.dart';

import 'helpers.dart';

import 'package:timetrack_core/timetrack_core.dart';

/// Wednesday 4 Nov 2026, 08:30 in Berlin.
final fixedNow = DateTime.utc(2026, 11, 4, 7, 30);

Future<(InMemorySyncStore, SyncedRepository)> pumpApp(
  WidgetTester tester, {
  GoRouter? router,
}) async {
  final store = InMemorySyncStore();
  final repo = await SyncedRepository.open(
    store,
    'aaaaaaaaaaaaaaaa',
    now: () => fixedNow.millisecondsSinceEpoch,
  );
  tester.view.physicalSize = const Size(1200, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        storeProvider.overrideWithValue(store),
        repositoryProvider.overrideWithValue(repo),
        clockProvider.overrideWithValue(() => fixedNow),
        nowProvider.overrideWith((ref) => Stream.value(fixedNow)),
        syncConfigStoreProvider.overrideWithValue(MemorySyncConfigStore()),
      ],
      child: TimeTrackApp(router: router ?? buildRouter()),
    ),
  );
  await tester.pumpAndSettle();
  return (store, repo);
}

void main() {
  testWidgets('clock in, start a project, take a break, clock out', (
    tester,
  ) async {
    final (store, repo) = await pumpApp(tester);
    await repo.write('projects', 'p1', {
      'name': 'Werk Süd',
      'project_number': 'P-2026/014',
      'favorite': true,
    });
    await tester.pumpAndSettle();

    expect(find.text('Not clocked in'), findsOneWidget);
    expect(
      find.textContaining('federal state'),
      findsOneWidget,
      reason: 'setup hint',
    );

    await tester.tap(find.text('Home office'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clock in'));
    await tester.pumpAndSettle();
    expect(find.text('Clocked in since 08:30'), findsOneWidget);

    await tester.tap(find.text('Werk Süd'));
    await tester.pumpAndSettle();
    expect(find.textContaining('P-2026/014'), findsWidgets);

    await tester.tap(find.text('Break'));
    await tester.pumpAndSettle();
    // Stopping the running project always asks for a summary.
    expect(find.text('What did you do for Werk Süd?'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'Zeichnungen geprüft');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('On break since 08:30'), findsOneWidget);
    expect(find.text('No project running'), findsOneWidget);

    await tester.tap(find.text('Clock out'));
    await tester.pumpAndSettle();
    expect(find.text('Not clocked in'), findsOneWidget);

    final entries = await store.transaction((tx) => tx.rows('project_entries'));
    expect(entries.single.fields['note'], 'Zeichnungen geprüft');
    final sessions = await store.transaction((tx) => tx.rows('work_sessions'));
    expect(sessions.single.fields, containsPair('location', 'home'));
    expect(sessions.single.fields['end_utc'], '2026-11-04T07:30:00Z');
  });

  testWidgets('the project picker finds projects by number', (tester) async {
    final (_, repo) = await pumpApp(tester);
    await repo.write('projects', 'p1', {
      'name': 'Werk Süd',
      'project_number': 'P-2026/014',
    });
    await repo.write('projects', 'p2', {
      'name': 'Logistik',
      'order_number': 'A-778812',
    });
    await tester.pumpAndSettle();

    await tester.tap(find.text('Choose project'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '2026014');
    await tester.pumpAndSettle();
    expect(find.text('Logistik'), findsNothing);
    await tester.tap(find.text('Werk Süd').last);
    await tester.pumpAndSettle();
    expect(
      find.text('Clocked in since 08:30'),
      findsOneWidget,
      reason: 'auto clock-in',
    );
  });

  testWidgets('the other tabs open', (tester) async {
    await pumpApp(tester);
    for (final tab in ['Calendar', 'Projects', 'Reports', 'Settings']) {
      await tester.tap(find.text(tab).last);
      await tester.pumpAndSettle();
    }
    expect(find.text('Federal state'), findsOneWidget);
    await tester.tap(find.text('Calendar').last);
    await tester.pumpAndSettle();
    expect(find.text('Week 45'), findsOneWidget);
  });

  testWidgets('day types: business trip offers travel and on site; '
      'vacation records nothing', (tester) async {
    final router = buildRouter();
    final (store, _) = await pumpApp(tester, router: router);
    router.go('/calendar/day/2026-11-04');
    await tester.pumpAndSettle();
    for (final type in ['Office', 'Home office', 'Business trip', 'Vacation']) {
      expect(find.widgetWithText(ChoiceChip, type), findsOneWidget);
    }

    await tester.tap(find.widgetWithText(ChoiceChip, 'Business trip'));
    await tester.pumpAndSettle();
    expect(find.text('New trip'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Destination'),
      'Stuttgart',
    );
    await tester.tap(find.text('Save').last);
    await tester.pumpAndSettle();
    expect(
      store.rowsOf('trips').values.single.fields['destination'],
      'Stuttgart',
    );
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Business trip'))
          .selected,
      isTrue,
    );
    expect(find.textContaining('Trip without a project'), findsOneWidget);

    await tester.tap(find.byTooltip('Add').first);
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(ChoiceChip, 'Home office'),
      findsOneWidget,
      reason: 'only the day type picker behind the dialog',
    );
    await tester.tap(find.widgetWithText(ChoiceChip, 'Travel').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save').last);
    await tester.pumpAndSettle();
    expect(
      store.rowsOf('work_sessions').values.single.fields['location'],
      'travel',
    );

    router.go('/calendar/day/2026-11-03');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Vacation'));
    await tester.pumpAndSettle();
    expect(store.rowsOf('absences').values.single.fields['kind'], 'vacation');
    expect(
      find.text('No working time is recorded on this day.'),
      findsOneWidget,
    );
    expect(find.text('Working times'), findsNothing);
  });

  testWidgets('week view: hours per project; swipe changes the week', (
    tester,
  ) async {
    final (_, repo) = await pumpApp(tester);
    await repo.write('projects', 'p1', {'name': 'Werk Süd'});
    await repo.write('project_entries', 'e1', {
      'project_id': 'p1',
      'date': '2026-11-03',
      'duration_min': 150,
    });
    await tester.tap(find.text('Calendar').last);
    await tester.pumpAndSettle();
    expect(find.text('Werk Süd 2:30'), findsOneWidget);

    await tester.fling(find.text('Werk Süd 2:30'), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('Week 46'), findsOneWidget);
    await tester.fling(find.byType(ListView).first, const Offset(400, 0), 1000);
    await tester.fling(find.byType(ListView).first, const Offset(400, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('Week 44'), findsOneWidget);
  });

  testWidgets('day view: an X deletes an entry after a confirmation', (
    tester,
  ) async {
    final router = buildRouter();
    final (store, repo) = await pumpApp(tester, router: router);
    await repo.write('work_sessions', 's1', {
      'start_utc': '2026-11-03T07:00:00Z',
      'end_utc': '2026-11-03T15:00:00Z',
      'location': 'office',
    });
    router.go('/calendar/day/2026-11-03');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Delete').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(store.rowsOf('work_sessions')['s1']!.isDeleted, isFalse);
    await tester.tap(find.byTooltip('Delete').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(store.rowsOf('work_sessions')['s1']!.isDeleted, isTrue);
  });

  testWidgets('the timesheet opens as a preview before the download', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.text('Reports').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Preview and download').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('Timesheet'), findsWidgets);
    for (final header in ['Worked', 'Credited', 'Target', 'Balance ±']) {
      expect(find.text(header), findsWidgets);
    }
    expect(find.text('PDF'), findsOneWidget);
    expect(find.text('CSV'), findsOneWidget);
  });

  testWidgets('project time as a duration with a summary', (tester) async {
    final (store, repo) = await pumpApp(tester);
    await repo.write('projects', 'p1', {
      'name': 'Werk Süd',
      'order_number': 'A-778812',
    });
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add project time'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose project').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Werk Süd').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Duration (h:mm)'),
      '1:30',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Summary'),
      'Angebot geschrieben',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final row = (await store.transaction((tx) => tx.rows('project_entries')))
        .single;
    expect(row.fields, containsPair('duration_min', 90));
    expect(row.fields, containsPair('date', '2026-11-04'));
    expect(row.fields, containsPair('note', 'Angebot geschrieben'));
    expect(row.fields['start_utc'], isNull);
    expect(
      find.textContaining('1:30 · Werk Süd'),
      findsOneWidget,
      reason: "shown in today's list",
    );
  });
}
