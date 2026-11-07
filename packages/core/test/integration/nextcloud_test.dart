// Integration test against a real Nextcloud (spec: sync-format.md §2, §7, §10).
//
// Skipped unless these environment variables are set:
//   NEXTCLOUD_URL=http://127.0.0.1:8089 NEXTCLOUD_USER=admin NEXTCLOUD_PASSWORD=…
// A local server: see docs/dev-setup.md ("Local Nextcloud for tests").
// Each run works in a fresh folder `TimeTrackTest-<random>` and deletes it.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:test/test.dart';
import 'package:timetrack_core/timetrack_core.dart';

void main() {
  final env = Platform.environment;
  final url = env['NEXTCLOUD_URL'];
  final skip = url == null ? 'NEXTCLOUD_URL not set' : null;

  late NextcloudCredentials creds;
  late String folder;
  WebDavRemoteFolder remote() => WebDavRemoteFolder(
    root: creds.webDavRoot(folder),
    username: creds.loginName,
    appPassword: creds.appPassword,
  );

  setUpAll(() {
    if (url == null) return;
    creds = NextcloudCredentials(
      server: Uri.parse(url),
      loginName: env['NEXTCLOUD_USER']!,
      appPassword: env['NEXTCLOUD_PASSWORD']!,
    );
    folder = 'TimeTrackTest-${Random().nextInt(1 << 32).toRadixString(16)}';
  });
  tearDownAll(() async {
    if (url != null) await remote().delete('');
  });

  test(
    'real server: 412 on existing files, ETags propagate to folders',
    () async {
      final r = remote();
      await r.makeDirectory('');
      await r.makeDirectory('devices');
      await r.makeDirectory('devices/x');
      final before = (await r.list(''))
          .firstWhere((e) => e.name == 'devices')
          .etag;
      expect(await r.createFile('devices/x/a.bin', [1, 2, 3]), isTrue);
      expect(
        await r.createFile('devices/x/a.bin', [9]),
        isFalse,
        reason: 'If-None-Match: * → 412',
      );
      expect(await r.read('devices/x/a.bin'), [1, 2, 3]);
      final after = (await r.list(''))
          .firstWhere((e) => e.name == 'devices')
          .etag;
      expect(
        after,
        isNot(before),
        reason: 'Nextcloud propagates ETags to parent folders',
      );
      await r.delete('devices');
    },
    skip: skip,
  );

  test(
    'real server: two devices sync encrypted, a third joins with the passphrase',
    () async {
      Future<SyncEngine> device(String id, String passphrase) async {
        final r = remote();
        final cipher = await connectSyncFolder(
          r,
          passphrase,
          memoryKiB: 1024,
          iterations: 1,
        );
        final repo = await SyncedRepository.open(InMemorySyncStore(), id);
        return SyncEngine(
          repository: repo,
          remote: r,
          cipher: cipher,
          deviceName: id,
          platform: 'test',
        );
      }

      final a = await device('aaaaaaaaaaaaaaaa', 'pass');
      final b = await device('bbbbbbbbbbbbbbbb', 'pass');
      await a.repository.write('work_sessions', 's', {
        'start_utc': '2026-11-07T08:00:00Z',
        'end_utc': null,
        'location': 'home',
      });
      await b.repository.write('work_sessions', 't', {
        'start_utc': '2026-11-07T08:05:00Z',
        'end_utc': null,
        'location': 'office',
      });
      await a.sync();
      await b.sync();
      await b.sync();
      await a.sync();
      for (final e in [a, b]) {
        final s = await e.repository.get('work_sessions', 's');
        expect(
          s!.fields['end_utc'],
          '2026-11-07T08:05:00Z',
          reason: 'resolve §7.1',
        );
      }
      final format =
          jsonDecode(utf8.decode((await remote().read('format.json'))!)) as Map;
      expect((format['encryption'] as Map)['kdf'], 'argon2id');
      await expectLater(
        device('cccccccccccccccc', 'wrong'),
        throwsA(isA<SyncCryptoException>()),
      );
      final c = await device('cccccccccccccccc', 'pass');
      expect((await c.sync()).appliedChanges, greaterThanOrEqualTo(3));
    },
    skip: skip,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
