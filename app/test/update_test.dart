// spec: updates.md
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:timetrack/app/providers.dart';
import 'package:timetrack/app/router.dart';
import 'package:timetrack/main.dart';
import 'package:timetrack/sync/sync_controller.dart';
import 'package:timetrack/update/installer.dart';
import 'package:timetrack/update/update_controller.dart';
import 'package:timetrack/work_pc/work_pc.dart';
import 'package:timetrack_core/timetrack_core.dart';

import 'helpers.dart';

final fixedNow = DateTime.utc(2026, 11, 8, 9);
final apk = utf8.encode('the new app');

/// GitHub with one release [tag]; [sums] replaces the real checksum file.
MockClient fakeGitHub(String tag, {String? sums}) {
  const base = 'https://github.com/Naclador89/timetrack/releases/download';
  return MockClient((request) async {
    final url = '${request.url}';
    if (request.url == latestReleaseUrl) {
      return http.Response(
        jsonEncode({
          'tag_name': tag,
          'html_url':
              'https://github.com/Naclador89/timetrack/releases/tag/$tag',
          'body': 'Neu: Updates aus der App',
          'assets': [
            for (final name in ['timetrack-linux-x64.tar.gz', 'SHA256SUMS'])
              {'name': name, 'browser_download_url': '$base/$tag/$name'},
          ],
        }),
        200,
      );
    }
    if (url.endsWith('/SHA256SUMS')) {
      final digest = await sha256Hex(Stream.value(apk));
      return http.Response(
        sums ?? '$digest  timetrack-linux-x64.tar.gz\n',
        200,
      );
    }
    if (url.endsWith('/timetrack-linux-x64.tar.gz')) {
      return http.Response.bytes(apk, 200);
    }
    return http.Response('', 404);
  });
}

/// Records what would be installed.
class FakeInstaller implements UpdateInstaller {
  FakeInstaller(this.folder);

  final Directory folder;
  final installed = <String>[];
  var restarted = false;

  @override
  Future<Directory> downloadFolder() async => folder;

  @override
  Future<bool> canSelfInstall() async => true;

  @override
  Future<bool> install(File file) async {
    installed.add(file.readAsStringSync());
    return true;
  }

  @override
  Future<void> restart() async => restarted = true;

  @override
  Future<void> cleanUp() async {}
}

Future<(InMemorySyncStore, FakeInstaller)> pumpWithUpdates(
  WidgetTester tester,
  http.Client github,
) async {
  final store = InMemorySyncStore();
  final repo = await SyncedRepository.open(
    store,
    'aaaaaaaaaaaaaaaa',
    now: () => fixedNow.millisecondsSinceEpoch,
  );
  final folder = Directory.systemTemp.createTempSync('tt-update-test');
  addTearDown(() => folder.deleteSync(recursive: true));
  final installer = FakeInstaller(folder);
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
        httpClientFactoryProvider.overrideWithValue((_) => github),
        installedVersionProvider.overrideWith(
          (ref) async => const AppVersion(0, 4, 0),
        ),
        updatePlatformProvider.overrideWithValue(UpdatePlatform.linux),
        updateInstallerProvider.overrideWithValue(installer),
        networkChangesProvider.overrideWithValue(const Stream.empty()),
        // No tray or window channel in tests, also on a Windows host.
        workPcPlatformProvider.overrideWithValue(null),
      ],
      child: TimeTrackApp(router: buildRouter()),
    ),
  );
  // Real file I/O for the download.
  await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  await tester.pumpAndSettle();
  return (store, installer);
}

/// Taps [finder] and lets the work it starts finish: the download does real
/// file I/O, which only completes in real time, its callbacks run on [pump].
Future<void> tapAndWait(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  for (var i = 0; i < 20; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    '§4 a newer release shows the banner; update downloads, verifies, installs',
    (tester) async {
      final (_, installer) = await pumpWithUpdates(
        tester,
        fakeGitHub('v0.4.1'),
      );
      expect(find.text('TimeTrack 0.4.1 is available'), findsOneWidget);

      await tester.tap(find.text("What's new"));
      await tester.pumpAndSettle();
      expect(find.text('Neu: Updates aus der App'), findsOneWidget);
      await tapAndWait(tester, find.text('Update').last);
      expect(installer.installed, ['the new app']);
      expect(find.textContaining('is installed'), findsOneWidget);
      await tester.tap(find.text('Restart'));
      expect(installer.restarted, isTrue);
    },
  );

  testWidgets('§5 a checksum mismatch installs nothing', (tester) async {
    final (_, installer) = await pumpWithUpdates(
      tester,
      fakeGitHub('v0.4.1', sums: '${'0' * 64}  timetrack-linux-x64.tar.gz\n'),
    );
    await tapAndWait(tester, find.text('Update'));
    expect(installer.installed, isEmpty);
    expect(find.textContaining('Checksum mismatch'), findsOneWidget);
    expect(installer.folder.listSync(), isEmpty, reason: 'bad file deleted');
  });

  testWidgets('§3 later hides the banner; skip remembers the version', (
    tester,
  ) async {
    final (store, _) = await pumpWithUpdates(tester, fakeGitHub('v0.4.1'));
    await tester.tap(find.text('Later'));
    await tester.pumpAndSettle();
    expect(find.textContaining('is available'), findsNothing);

    final state = UpdateState.decode(
      await store.transaction((tx) => tx.localValue(UpdateChecker.stateKey)),
    );
    expect(state.checked, fixedNow);
    expect(
      state.notified,
      const AppVersion(0, 4, 1),
      reason: 'seen in the banner',
    );
  });

  testWidgets('§3 the same version is not offered; a manual check says so', (
    tester,
  ) async {
    await pumpWithUpdates(tester, fakeGitHub('v0.4.0'));
    expect(find.textContaining('is available'), findsNothing);
    final context = tester.element(find.byType(Scaffold).first);
    GoRouterHelper(context).push('/settings');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Check for updates'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Check for updates'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Installed: 0.4.0'), findsOneWidget);
    await tapAndWait(tester, find.text('Check for updates'));
    expect(find.text('TimeTrack is up to date.'), findsOneWidget);
  });

  testWidgets('§4 an update started in settings shows Restart there', (
    tester,
  ) async {
    final (_, installer) = await pumpWithUpdates(tester, fakeGitHub('v0.4.1'));
    await tester.tap(find.text('Later'));
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(Scaffold).first);
    GoRouterHelper(context).push('/settings');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Check for updates'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Check for updates'));
    await tester.pumpAndSettle();
    await tapAndWait(tester, find.text('Check for updates'));
    expect(find.text('Neu: Updates aus der App'), findsOneWidget);
    expect(find.text('Update'), findsNWidgets(2), reason: 'banner + dialog');
    await tapAndWait(tester, find.text('Update').last);
    expect(installer.installed, ['the new app']);
    // The tabs behind Settings show it too; the top one is Settings'.
    expect(find.textContaining('is installed'), findsWidgets);
    await tester.tap(find.text('Restart').last);
    expect(installer.restarted, isTrue);
  });
}
