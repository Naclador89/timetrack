import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:timetrack/app/providers.dart';
import 'package:timetrack/app/back_navigation.dart';
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
  DateTime Function()? clock,
}) async {
  final now = clock ?? () => fixedNow;
  final store = InMemorySyncStore();
  final repo = await SyncedRepository.open(
    store,
    'aaaaaaaaaaaaaaaa',
    now: () => now().millisecondsSinceEpoch,
  );
  tester.view.physicalSize = const Size(1200, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        storeProvider.overrideWithValue(store),
        repositoryProvider.overrideWithValue(repo),
        clockProvider.overrideWithValue(now),
        nowProvider.overrideWith((ref) => Stream.value(now())),
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

    // The day type is one chip; the types open in a sheet.
    await tester.tap(find.text('Day type'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Home office').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clock in'));
    await tester.pumpAndSettle();
    expect(find.text('Clocked in since 08:30'), findsOneWidget);

    await tester.tap(find.text('Werk Süd'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.stop_circle_outlined), findsOneWidget);

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
    for (final tab in ['Calendar', 'Projects', 'Reports']) {
      await tester.tap(find.text(tab).last);
      await tester.pumpAndSettle();
    }
    // Settings open over the tabs from the gear icon.
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Federal state'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'saturday');
    await tester.pumpAndSettle();
    expect(find.text('Federal state'), findsNothing);
    expect(find.textContaining('Saturday'), findsWidgets);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Calendar').last);
    await tester.pumpAndSettle();
    expect(find.text('Week 45'), findsOneWidget);
  });

  testWidgets('day types: business trip offers travel and on site; '
      'work on a vacation day is possible', (tester) async {
    final router = buildRouter();
    final (store, _) = await pumpApp(tester, router: router);
    router.go('/calendar/day/2026-11-04');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Day type'));
    await tester.pumpAndSettle();
    for (final type in ['Office', 'Home office', 'Business trip', 'Vacation']) {
      expect(find.text(type), findsOneWidget);
    }

    await tester.tap(find.text('Business trip'));
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
    expect(find.widgetWithText(ActionChip, 'Business trip'), findsOneWidget);
    expect(find.textContaining('Trip without a project'), findsOneWidget);

    await tester.tap(find.byTooltip('Add').first);
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(ChoiceChip, 'Home office'),
      findsNothing,
      reason: 'a trip day offers travel and on site only',
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
    await tester.tap(find.text('Day type'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vacation'));
    await tester.pumpAndSettle();
    expect(store.rowsOf('absences').values.single.fields['kind'], 'vacation');
    expect(
      find.text('Working time recorded on this day is credited as overtime.'),
      findsOneWidget,
    );
    expect(find.text('Working times'), findsOneWidget);
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
    await tester.tap(find.byTooltip('Go to today'));
    await tester.pumpAndSettle();
    expect(find.text('Week 45'), findsOneWidget);
  });

  testWidgets('day view: an X deletes an entry, undo brings it back', (
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
    expect(store.rowsOf('work_sessions')['s1']!.isDeleted, isTrue);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(store.rowsOf('work_sessions')['s1']!.isDeleted, isFalse);
    expect(find.text('Working times'), findsOneWidget);
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

  testWidgets('booking sheet: search as you type, 15-minute steps, '
      'optional time, comment', (tester) async {
    final (store, repo) = await pumpApp(tester);
    await repo.write('projects', 'p1', {
      'name': 'Werk Süd',
      'order_number': 'A-778812',
      'client': 'Bosch',
    });
    await repo.write('projects', 'p2', {'name': 'Logistik'});
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add project time'));
    await tester.pumpAndSettle();
    expect(find.text('Book project time'), findsOneWidget);
    // Matches appear below the field while typing: order number, client.
    await tester.enterText(find.byType(TextField).first, '778812');
    await tester.pumpAndSettle();
    expect(find.text('Logistik'), findsNothing);
    await tester.enterText(find.byType(TextField).first, 'bosch');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Werk Süd').last);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Change project'), findsOneWidget);

    // 1:00 by default; + and − move by 0:15; chips set common values.
    await tester.tap(find.byTooltip('+ 0:15'));
    await tester.tap(find.byTooltip('+ 0:15'));
    await tester.pumpAndSettle();
    expect(find.text('1:30 h'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'What was done?'),
      'Angebot geschrieben',
    );
    await tester.tap(find.text('Book'));
    await tester.pumpAndSettle();

    final row = store.rowsOf('project_entries').values.single;
    expect(row.fields, containsPair('duration_min', 90));
    expect(row.fields, containsPair('date', '2026-11-04'));
    expect(row.fields, containsPair('note', 'Angebot geschrieben'));
    expect(row.fields['start_utc'], isNull);

    // With a start time it becomes a span; the last comment is offered.
    await tester.tap(find.text('Add project time'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Werk Süd').last); // recently used
    await tester.pumpAndSettle();
    await tester.tap(find.text('2:00'));
    await tester.tap(find.text('With start time'));
    await tester.pumpAndSettle();
    expect(find.text('End 10:00'), findsOneWidget);
    await tester.tap(find.text('Angebot geschrieben'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Book'));
    await tester.pumpAndSettle();
    final span = store
        .rowsOf('project_entries')
        .values
        .firstWhere((r) => r.fields['start_utc'] != null);
    expect(span.fields['start_utc'], '2026-11-04T07:00:00Z');
    expect(span.fields['end_utc'], '2026-11-04T09:00:00Z');
    expect(span.fields['note'], 'Angebot geschrieben');
  });

  testWidgets('quick entry: one line records times, break and project', (
    tester,
  ) async {
    final (store, repo) = await pumpApp(tester);
    await repo.write('projects', 'p1', {
      'name': 'Werk Süd',
      'project_number': 'P-2026/014',
    });
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Quick entry'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).last,
      '7-12 p15 014: Prüfung',
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Werk Süd'), findsWidgets, reason: 'preview');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    final session = store.rowsOf('work_sessions').values.single;
    expect(session.fields['start_utc'], '2026-11-04T06:00:00Z');
    expect(store.rowsOf('breaks').values.single.fields['start_utc'], isNotNull);
    final entry = store.rowsOf('project_entries').values.single;
    expect(
      (entry.fields['project_id'], entry.fields['note']),
      ('p1', 'Prüfung'),
    );
    expect(find.text('Entered'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(store.rowsOf('work_sessions').values.single.isDeleted, isTrue);
  });

  testWidgets('needs attention: unassigned time is booked with one tap', (
    tester,
  ) async {
    final (store, repo) = await pumpApp(tester);
    await repo.write('projects', 'p1', {'name': 'Werk Süd'});
    await repo.write('work_sessions', 's1', {
      'start_utc': '2026-11-03T07:00:00Z',
      'end_utc': '2026-11-03T12:00:00Z',
      'location': 'office',
    });
    await tester.pumpAndSettle();
    expect(find.textContaining('5:00 without a project'), findsOneWidget);
    await tester.tap(find.text('Assign'));
    await tester.pumpAndSettle();
    expect(find.text('5:00 h'), findsOneWidget, reason: 'the gap, prefilled');
    await tester.tap(find.text('Werk Süd').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Book'));
    await tester.pumpAndSettle();
    final entry = store.rowsOf('project_entries').values.single;
    expect(entry.fields['start_utc'], '2026-11-03T07:00:00Z');
    expect(entry.fields['end_utc'], '2026-11-03T12:00:00Z');
    expect(find.textContaining('without a project'), findsNothing);
  });

  testWidgets('tap a day\'s numbers to see how they are counted', (
    tester,
  ) async {
    final router = buildRouter();
    final (_, repo) = await pumpApp(tester, router: router);
    await repo.write('work_sessions', 's1', {
      'start_utc': '2026-11-07T06:00:00Z',
      'end_utc': '2026-11-07T19:00:00Z',
      'location': 'travel',
    });
    await repo.write('trips', 't1', {
      'depart_utc': '2026-11-07T06:00:00Z',
      'return_utc': '2026-11-07T19:00:00Z',
    });
    router.go('/calendar/day/2026-11-07');
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.help_outline).first);
    await tester.pumpAndSettle();
    expect(find.textContaining('How'), findsWidgets);
    expect(find.textContaining('at most 11:00 count'), findsOneWidget);
  });

  testWidgets('calendar month view and the command palette', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Calendar').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Month'));
    await tester.pumpAndSettle();
    expect(find.text('November 2026'), findsOneWidget);
    expect(find.text('25'), findsOneWidget);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'repor');
    await tester.pumpAndSettle();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('Preview and download'), findsWidgets);
  });

  testWidgets('setup wizard: state, working time, balance, home office', (
    tester,
  ) async {
    final (store, _) = await pumpApp(tester);
    await tester.tap(find.text('Set up'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bayern'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('38:30'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '12:30');
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('40 % per month'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('All set'), findsOneWidget);
    expect(store.rowsOf('settings')['federal_state']!.fields['value'], 'BY');
    expect(store.rowsOf('settings')['starting_balance']!.fields['value'], 750);
    final schedule = store.rowsOf('work_schedules').values.single;
    expect(schedule.fields['minutes_mon'], 462);
    expect(schedule.fields['minutes_sat'], 0);
    expect(
      store.rowsOf('home_office_rules').values.single.fields['max_percent'],
      40,
    );
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Set up'), findsNothing);
  });

  testWidgets('notices: × hides for good, the calendar keeps a marker; '
      'categories and the threshold are settings', (tester) async {
    final router = buildRouter();
    final (store, repo) = await pumpApp(tester, router: router);
    await repo.write('work_sessions', 's1', {
      'start_utc': '2026-11-03T07:00:00Z',
      'end_utc': '2026-11-03T12:00:00Z',
      'location': 'office',
    });
    await tester.pumpAndSettle();
    expect(find.textContaining('5:00 without a project'), findsOneWidget);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.textContaining('without a project'), findsNothing);
    expect(store.rowsOf('dismissed_notices').keys, ['2026-11-03/unassigned']);

    // Still hidden after a restart of the screen; a marker in the week.
    await tester.tap(find.text('Calendar').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('without a project'), findsNothing);
    expect(
      find.byWidgetPredicate(
        (w) => w is Icon && w.semanticLabel == 'Has notices',
      ),
      findsOneWidget,
    );

    // The day lists it small and can bring it back.
    router.go('/calendar/day/2026-11-03');
    await tester.pumpAndSettle();
    await tester.tap(find.text('1 hidden notices'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show again'));
    await tester.pumpAndSettle();
    expect(find.textContaining('5:00 without a project'), findsOneWidget);

    // Threshold above 5 h: no notice, no marker.
    await saveSetting(repo, SettingKeys.noticeUnassignedMin, 360);
    await tester.pumpAndSettle();
    expect(find.textContaining('without a project'), findsNothing);

    // Switched off: no card, but listed as hidden on the day.
    await saveSetting(repo, SettingKeys.noticeUnassignedMin, 30);
    await saveSetting(repo, SettingKeys.noticeShow('unassigned'), false);
    await tester.pumpAndSettle();
    expect(find.textContaining('5:00 without a project'), findsNothing);
    expect(find.text('1 hidden notices'), findsOneWidget);
  });

  testWidgets('booking sheet fits a phone', (tester) async {
    final (_, repo) = await pumpApp(tester);
    tester.view.physicalSize = const Size(412, 860);
    await repo.write('projects', 'p1', {
      'name': 'Werk Süd Umbau Halle 3',
      'project_number': 'P-2026/014',
      'order_number': 'A-778812',
      'client': 'Robert Bosch GmbH',
    });
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Add project time'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add project time'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Werk Süd Umbau Halle 3').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('With start time'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('trip day: steps record outbound, customer and return '
      'times; the account gets the target', (tester) async {
    var time = fixedNow;
    final (store, repo) = await pumpApp(tester, clock: () => time);
    // Moves the clock and lets "now" follow.
    Future<void> at(int hour, int minute) async {
      time = DateTime.utc(2026, 11, 4, hour, minute);
      ProviderScope.containerOf(tester.element(find.byType(TimeTrackApp)))
          .invalidate(nowProvider);
      await tester.pumpAndSettle();
    }

    await repo.write('work_schedules', 'w', {
      'valid_from': '2026-01-01',
      for (final d in ['mon', 'tue', 'wed', 'thu', 'fri']) 'minutes_$d': 480,
    });
    await repo.write('trips', 't1', {
      'depart_utc': '2026-11-04T05:00:00Z',
      'destination': 'Stuttgart',
    });
    await tester.pumpAndSettle();
    expect(find.text('Travel record'), findsOneWidget);
    expect(find.text('Overtime account: 8:00 credited'), findsOneWidget);

    await tester.tap(find.text('Start travelling there'));
    await tester.pumpAndSettle();
    expect(
      store.rowsOf('work_sessions').values.single.fields['location'],
      'travel',
    );
    await at(9, 0);
    await tester.tap(find.text('Arrived at the customer'));
    await tester.pumpAndSettle();
    expect(find.text('Outbound'), findsOneWidget);
    expect(find.text('At the customer'), findsOneWidget);
    await at(15, 0);
    await tester.tap(find.text('Start travelling back'));
    await tester.pumpAndSettle();
    await at(17, 30);
    expect(find.text('Return'), findsOneWidget);
    expect(find.text('10:00 – 16:00'), findsOneWidget, reason: 'exact times');
    await tester.tap(find.text('Back – end travel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('End trip').last); // the dialog
    await tester.pumpAndSettle();
    final locations = [
      for (final r in store.rowsOf('work_sessions').values)
        r.fields['location'],
    ]..sort();
    expect(locations, ['on_site', 'travel', 'travel']);
    expect(store.rowsOf('trips')['t1']!.fields['return_utc'], isNotNull);
  });

  testWidgets('back: page, view, previous tab, then ask before leaving', (
    tester,
  ) async {
    var left = 0;
    TabBackHandler.leaveApp = () async => left++;
    await pumpApp(tester);
    Future<void> back() async {
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
    }

    // From Today, the day opens inside the Today tab: back returns there.
    await tester.tap(find.byTooltip('Quick entry'));
    await tester.pumpAndSettle();
    await back(); // closes the sheet
    expect(find.text('Quick entry'), findsNothing);
    expect(find.text('Not clocked in'), findsOneWidget);

    await tester.tap(find.text('Calendar').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Next week'));
    await tester.pumpAndSettle();
    expect(find.text('Week 46'), findsOneWidget);
    await tester.tap(find.text('Reports').last);
    await tester.pumpAndSettle();

    await back(); // Reports → the calendar, the tab visited before
    expect(find.text('Week 46'), findsOneWidget);
    await back(); // the calendar's own step: back to this week
    expect(find.text('Week 45'), findsOneWidget);
    await tester.tap(find.text('Wed, 11/4').first);
    await tester.pumpAndSettle();
    await back(); // day → week
    expect(find.text('Week 45'), findsOneWidget);
    await back(); // → Today
    expect(find.text('Not clocked in'), findsOneWidget);

    await back(); // asks first
    expect(find.text('Press back again to leave'), findsOneWidget);
    expect(left, 0);
    await back();
    expect(left, 1);
  });
}
