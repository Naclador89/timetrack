// spec: work-pc.md
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:timetrack/app/providers.dart';
import 'package:timetrack/app/router.dart';
import 'package:timetrack/main.dart';
import 'package:timetrack/sync/sync_controller.dart';
import 'package:timetrack/work_pc/work_pc.dart';
import 'package:timetrack_core/timetrack_core.dart';

import 'helpers.dart';

/// Monday 9 Nov 2026, 08:00 in Berlin.
final fixedNow = DateTime.utc(2026, 11, 9, 7);

class FakeWorkPc implements WorkPcPlatform {
  var enabled = false;
  var shown = 0;

  @override
  Future<bool> isEnabled() async => enabled;

  @override
  Future<void> setEnabled(bool on) async => enabled = on;

  @override
  Future<void> showWindow() async => shown++;
}

Future<void> pump(
  WidgetTester tester,
  InMemorySyncStore store,
  SyncedRepository repo,
  FakeWorkPc workPc, {
  bool autostarted = true,
}) async {
  tester.view.physicalSize = const Size(1200, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      // A fresh scope per start, like a new process.
      key: UniqueKey(),
      overrides: [
        storeProvider.overrideWithValue(store),
        repositoryProvider.overrideWithValue(repo),
        clockProvider.overrideWithValue(() => fixedNow),
        nowProvider.overrideWith((ref) => Stream.value(fixedNow)),
        syncConfigStoreProvider.overrideWithValue(MemorySyncConfigStore()),
        networkChangesProvider.overrideWithValue(const Stream.empty()),
        workPcPlatformProvider.overrideWithValue(workPc),
        autostartedProvider.overrideWithValue(autostarted),
      ],
      child: TimeTrackApp(router: buildRouter()),
    ),
  );
  await settle(tester);
}

/// Pumps until the prompt's store reads and writes are through.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

void main() {
  late InMemorySyncStore store;
  late SyncedRepository repo;
  late FakeWorkPc workPc;
  late WidgetTester t;
  Future<TrackerState> state() async =>
      (await t.runAsync(() => TimeTracker(repo, now: () => fixedNow).state()))!;

  setUp(() async {
    store = InMemorySyncStore();
    repo = await SyncedRepository.open(
      store,
      'aaaaaaaaaaaaaaaa',
      now: () => fixedNow.millisecondsSinceEpoch,
    );
    workPc = FakeWorkPc();
  });

  testWidgets('§2 nothing tracked yet: asks; Start clocks in at the office', (
    tester,
  ) async {
    t = tester;
    await pump(tester, store, repo, workPc);
    expect(find.text('Start tracking for today?'), findsOneWidget);
    expect(workPc.shown, 1, reason: 'window brought to the front');
    await tester.tap(find.text('Start'));
    await settle(tester);
    final s = await state();
    expect(s.clockedIn, isTrue);
    expect(s.location, WorkLocation.office);
  });

  testWidgets('§2 home office can be picked in the question', (tester) async {
    t = tester;
    await pump(tester, store, repo, workPc);
    await tester.tap(find.text('Home office'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start'));
    await settle(tester);
    expect((await state()).location, WorkLocation.home);
  });

  testWidgets('§2 already clocked in: no question, window stays minimized', (
    tester,
  ) async {
    // Before the first pump the fake clock doesn't run: write for real.
    await tester.runAsync(
      () => repo.write('work_sessions', 's1', {
        'start_utc': '2026-11-09T06:30:00Z',
        'end_utc': null,
        'location': 'office',
      }),
    );
    t = tester;
    await pump(tester, store, repo, workPc);
    expect(find.text('Start tracking for today?'), findsNothing);
    expect(workPc.shown, 0);
  });

  testWidgets('§2 "Not today" is not asked again on the next sign-in', (
    tester,
  ) async {
    t = tester;
    await pump(tester, store, repo, workPc);
    await tester.tap(find.text('Not today'));
    await settle(tester);
    expect((await state()).clockedIn, isFalse);

    t = tester;
    await pump(tester, store, repo, workPc);
    expect(find.text('Start tracking for today?'), findsNothing);
  });

  testWidgets('§2 started by hand (not at sign-in): no question', (
    tester,
  ) async {
    await pump(tester, store, repo, workPc, autostarted: false);
    expect(find.text('Start tracking for today?'), findsNothing);
  });

  testWidgets('§1 the setting switches the autostart', (tester) async {
    await pump(tester, store, repo, workPc, autostarted: false);
    final context = tester.element(find.byType(Scaffold).first);
    GoRouterHelper(context).push('/settings');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Work PC'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Work PC'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Work PC'));
    await tester.pumpAndSettle();
    expect(workPc.enabled, isTrue);
    await tester.tap(find.text('Work PC'));
    await tester.pumpAndSettle();
    expect(workPc.enabled, isFalse);
  });
}
