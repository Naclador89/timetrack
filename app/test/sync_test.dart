import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timetrack/app/providers.dart';
import 'package:timetrack/app/router.dart';
import 'package:timetrack/main.dart';
import 'package:timetrack/sync/sync_controller.dart';
import 'package:timetrack_core/testing.dart';
import 'package:timetrack_core/timetrack_core.dart';

import 'helpers.dart';

final fixedNow = DateTime.utc(2026, 11, 4, 7, 30);
final root = Uri.parse(
  'https://cloud.example.com/remote.php/dav/files/alice/TimeTrack/',
);

void main() {
  testWidgets('a local write is uploaded, encrypted, after the debounce', (
    tester,
  ) async {
    final files = InMemoryRemoteFolder();
    final client = fakeNextcloud(files);
    // The first device already set up the sync folder (key derivation runs in
    // an isolate, so it needs real async).
    final keyBytes = (await tester.runAsync(() async {
      final remote = WebDavRemoteFolder(
        root: root,
        username: 'alice',
        appPassword: 'secret',
        client: client,
      );
      final cipher = await connectSyncFolder(
        remote,
        'passphrase',
        memoryKiB: 64,
        iterations: 1,
      );
      return cipher.key.extractBytes();
    }))!;
    final config = MemorySyncConfigStore()
      ..config = SyncConfig(
        root: root,
        loginName: 'alice',
        appPassword: 'secret',
        keyBytes: keyBytes,
      );

    final writes = StreamController<void>.broadcast();
    addTearDown(writes.close);
    final store = InMemorySyncStore();
    final repo = await SyncedRepository.open(
      store,
      'aaaaaaaaaaaaaaaa',
      now: () => fixedNow.millisecondsSinceEpoch,
      onLocalWrite: () => writes.add(null),
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
          syncConfigStoreProvider.overrideWithValue(config),
          httpClientFactoryProvider.overrideWithValue((_) => client),
          localWritesProvider.overrideWithValue(writes.stream),
        ],
        child: TimeTrackApp(router: buildRouter()),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      files.filePaths,
      contains('devices/aaaaaaaaaaaaaaaa/device.json'),
      reason: 'first sync on start',
    );

    await tester.tap(find.text('Clock in'));
    await tester.pumpAndSettle();
    expect(
      files.filePaths.where((p) => p.contains('/ops/')),
      isEmpty,
      reason: 'debounced',
    );

    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    final batches = files.filePaths.where((p) => p.contains('/ops/')).toList();
    expect(batches, hasLength(1));
    expect(
      utf8.decode(files.rawFile(batches.single)!, allowMalformed: true),
      isNot(contains('work_sessions')),
    );

    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
    expect(find.text('cloud.example.com'), findsOneWidget);
  });
}
