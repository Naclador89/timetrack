import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:timetrack/app/providers.dart';
import 'package:timetrack/app/router.dart';
import 'package:timetrack/main.dart';
import 'package:timetrack/sync/sync_controller.dart';
import 'package:timetrack_core/timetrack_core.dart';

/// Keeps the sync config in memory (no platform channels in tests).
class MemorySyncConfigStore implements SyncConfigStore {
  SyncConfig? config;

  @override
  Future<SyncConfig?> load() async => config;

  @override
  Future<void> save(SyncConfig c) async => config = c;

  @override
  Future<void> clear() async => config = null;
}

/// Wednesday 4 Nov 2026, 08:30 in Berlin.
final appTestNow = DateTime.utc(2026, 11, 4, 7, 30);

Future<(InMemorySyncStore, SyncedRepository)> pumpApp(
  WidgetTester tester, {
  GoRouter? router,
  DateTime Function()? clock,
  List<Override> overrides = const [],
}) async {
  final now = clock ?? () => appTestNow;
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
        networkChangesProvider.overrideWithValue(const Stream.empty()),
        ...overrides,
      ],
      child: TimeTrackApp(router: router ?? buildRouter()),
    ),
  );
  await tester.pumpAndSettle();
  return (store, repo);
}

/// Pumps until store reads and writes started by a frame are through (they
/// run outside the fake clock).
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
}
