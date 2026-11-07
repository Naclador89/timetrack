import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timetrack/app/providers.dart';
import 'package:timetrack/app/router.dart';
import 'package:timetrack/main.dart';
import 'package:timetrack/sync/sync_controller.dart';

import 'helpers.dart';

import 'package:timetrack_core/timetrack_core.dart';

/// Wednesday 4 Nov 2026, 08:30 in Berlin.
final fixedNow = DateTime.utc(2026, 11, 4, 7, 30);

Future<(InMemorySyncStore, SyncedRepository)> pumpApp(
  WidgetTester tester,
) async {
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
      child: TimeTrackApp(router: buildRouter()),
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
    await tester.tap(find.text('Clock in'));
    await tester.pumpAndSettle();
    expect(find.text('Clocked in since 08:30'), findsOneWidget);

    await tester.tap(find.text('Werk Süd'));
    await tester.pumpAndSettle();
    expect(find.textContaining('P-2026/014'), findsWidgets);

    await tester.tap(find.text('Break'));
    await tester.pumpAndSettle();
    expect(find.text('On break since 08:30'), findsOneWidget);
    expect(find.text('No project running'), findsOneWidget);

    await tester.tap(find.text('Clock out'));
    await tester.pumpAndSettle();
    expect(find.text('Not clocked in'), findsOneWidget);

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
}
