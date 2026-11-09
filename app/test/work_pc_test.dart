// spec: work-pc.md
import 'dart:async';

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
  var hidden = 0;
  var quitted = false;
  bool? closeToTray;
  TrayModel? tray;
  final notifications = <(String, String)>[];
  final actions = StreamController<String>.broadcast();

  @override
  Future<bool> isEnabled() async => enabled;

  @override
  Future<void> setEnabled(bool on) async => enabled = on;

  @override
  Future<void> showWindow() async => shown++;

  @override
  Future<void> hideWindow() async => hidden++;

  @override
  Future<void> setTray(TrayModel tray) async => this.tray = tray;

  @override
  Future<void> setCloseToTray(bool on) async => closeToTray = on;

  @override
  Future<void> notify(String title, String body) async =>
      notifications.add((title, body));

  @override
  Future<void> quit() async => quitted = true;

  @override
  Stream<String> get trayActions => actions.stream;

  /// The labels of the tray menu, without separators.
  List<String> get menu => [
    for (final i in tray!.items)
      if (!i.separator) i.label,
  ];
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
    await tester.tap(find.text('OK')); // the time, now (calculations §19)
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
    await tester.tap(find.text('OK')); // the time, now (calculations §19)
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
    expect(workPc.hidden, 1, reason: 'into the tray (§3)');
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

  Future<void> openSetting(WidgetTester tester, String title) async {
    final context = tester.element(find.byType(Scaffold).first);
    GoRouterHelper(context).push('/settings');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text(title),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text(title));
    await tester.pumpAndSettle();
  }

  testWidgets('§1 "Start with Windows" switches the Run key', (tester) async {
    await pump(tester, store, repo, workPc, autostarted: false);
    await openSetting(tester, 'Start with Windows');
    await tester.tap(find.text('Start with Windows'));
    await tester.pumpAndSettle();
    expect(workPc.enabled, isTrue);
    await tester.tap(find.text('Start with Windows'));
    await tester.pumpAndSettle();
    expect(workPc.enabled, isFalse);
  });

  testWidgets('§1 "Work PC" turns the autostart on with it', (tester) async {
    await pump(tester, store, repo, workPc, autostarted: false);
    await openSetting(tester, 'Work PC');
    await tester.tap(find.text('Work PC'));
    await tester.pumpAndSettle();
    expect(workPc.enabled, isTrue);
    final asks = await tester.runAsync(
      () => store.transaction((tx) => tx.localValue(startPromptKey)),
    );
    expect(asks, 'true');
  });

  testWidgets('§2 autostart without "Work PC": no question, into the tray', (
    tester,
  ) async {
    await tester.runAsync(
      () =>
          store.transaction((tx) => tx.setLocalValue(startPromptKey, 'false')),
    );
    t = tester;
    await pump(tester, store, repo, workPc);
    expect(find.text('Start tracking for today?'), findsNothing);
    expect(workPc.hidden, 1);
  });

  group('§3 tray icon', () {
    testWidgets('the menu follows the state and clocks in', (tester) async {
      t = tester;
      await pump(tester, store, repo, workPc, autostarted: false);
      expect(workPc.closeToTray, isTrue, reason: 'default on');
      expect(workPc.tray!.idle, isTrue);
      expect(workPc.menu, [
        'Not clocked in · 0:00',
        'Clock in',
        'Switch project…',
        'Book project time…',
        'Open TimeTrack',
        'Quit',
      ]);
      workPc.actions.add('clock');
      await settle(tester);
      expect(workPc.shown, 1, reason: 'the time is asked in the window');
      await tester.tap(find.text('OK'));
      await settle(tester);
      expect((await state()).clockedIn, isTrue);
      expect(workPc.tray!.idle, isFalse);
      expect(workPc.menu, containsAll(['Clock out', 'Break']));
      expect(workPc.menu.first, startsWith('Clocked in since 08:00'));
    });

    testWidgets('a project from the menu starts; quit quits', (tester) async {
      await tester.runAsync(
        () =>
            repo.write('projects', 'p', {'name': 'Werk Süd', 'favorite': true}),
      );
      t = tester;
      await pump(tester, store, repo, workPc, autostarted: false);
      expect(workPc.menu, contains('Werk Süd'));
      workPc.actions.add('project:p');
      await settle(tester);
      expect((await state()).projectId, 'p');
      expect(
        workPc.tray!.items.singleWhere((i) => i.label == 'Werk Süd').checked,
        isTrue,
      );
      workPc.actions.add('quit');
      await settle(tester);
      expect(workPc.quitted, isTrue);
    });

    testWidgets('due reminders become Windows notifications', (tester) async {
      // Working since 02:00 Berlin without a break: 6 h at 08:00.
      await tester.runAsync(
        () => repo.write('work_sessions', 's', {
          'start_utc': '2026-11-09T01:00:00Z',
          'end_utc': null,
          'location': 'office',
        }),
      );
      t = tester;
      await pump(tester, store, repo, workPc, autostarted: false);
      await tester.pump(const Duration(minutes: 1));
      await settle(tester);
      expect(workPc.notifications, [
        (
          'Time for a break',
          '5:45 h without a break – after 6 h a break is required.',
        ),
      ]);
      // Shown once.
      await tester.pump(const Duration(minutes: 1));
      await settle(tester);
      expect(workPc.notifications, hasLength(1));
    });
  });
}
