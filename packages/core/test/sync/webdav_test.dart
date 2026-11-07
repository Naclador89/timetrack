// spec: sync-format.md §2, §7 — WebDAV mapping, tested against a simulated
// Nextcloud (MockClient backed by InMemoryRemoteFolder).
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:timetrack_core/testing.dart';
import 'package:timetrack_core/timetrack_core.dart';

const _davRoot = '/remote.php/dav/files/alice/Zeit Erfassung/';
final _rootUrl = Uri.parse(
  'https://cloud.example.com${Uri.encodeFull(_davRoot)}',
);

WebDavRemoteFolder dav(MockClient client, {String password = 'secret'}) =>
    WebDavRemoteFolder(
      root: _rootUrl,
      username: 'alice',
      appPassword: password,
      client: client,
    );

void main() {
  late InMemoryRemoteFolder files;
  setUp(() => files = InMemoryRemoteFolder());

  test(
    'maps folders, files, ETags and paths with spaces and umlauts',
    () async {
      final remote = dav(fakeNextcloud(files, davRoot: _davRoot));
      await remote.makeDirectory('devices');
      await remote.makeDirectory('devices'); // 405 = exists → fine
      await remote.makeDirectory('devices/Gerät 1');
      expect(
        await remote.createFile('devices/Gerät 1/a b.txt', utf8.encode('x')),
        isTrue,
      );
      expect(
        await remote.createFile('devices/Gerät 1/a b.txt', utf8.encode('y')),
        isFalse,
      );
      expect(utf8.decode((await remote.read('devices/Gerät 1/a b.txt'))!), 'x');
      expect(await remote.read('missing'), isNull);

      final listing = await remote.list('devices');
      expect(listing.map((e) => (e.path, e.isDirectory)), [
        ('devices/Gerät 1', true),
      ]);
      final before = listing.single.etag;
      await remote.writeFile('devices/Gerät 1/b.txt', [1]);
      expect(
        (await remote.list('devices')).single.etag,
        isNot(before),
        reason: 'folder ETag changes',
      );
      expect((await remote.stat(''))!.isDirectory, isTrue);
      expect(await remote.list('nope'), isEmpty);

      await remote.delete('devices/Gerät 1/b.txt');
      await remote.delete('devices/Gerät 1/b.txt'); // 404 → fine
      expect((await remote.list('devices/Gerät 1')).map((e) => e.name), [
        'a b.txt',
      ]);
    },
  );

  test('a missing parent folder and wrong credentials are errors', () async {
    await expectLater(
      dav(fakeNextcloud(files, davRoot: _davRoot)).makeDirectory('a/b'),
      throwsA(isA<RemoteException>()),
    );
    final denied = dav(
      fakeNextcloud(files, davRoot: _davRoot),
      password: 'wrong',
    );
    await expectLater(
      denied.list(''),
      throwsA(
        isA<RemoteException>().having(
          (e) => e.isUnauthorized,
          'unauthorized',
          isTrue,
        ),
      ),
    );
  });

  test('§7 two devices sync through WebDAV end to end', () async {
    final log = <String>[];
    final server = fakeNextcloud(files, davRoot: _davRoot, log: log);
    Future<SyncEngine> device(String id) async {
      final remote = dav(server);
      final cipher = await connectSyncFolder(
        remote,
        'pass',
        memoryKiB: 64,
        iterations: 1,
      );
      final repo = await SyncedRepository.open(InMemorySyncStore(), id);
      return SyncEngine(repository: repo, remote: remote, cipher: cipher);
    }

    final a = await device('aaaaaaaaaaaaaaaa');
    final b = await device('bbbbbbbbbbbbbbbb');
    await a.repository.write('projects', 'p', {'name': 'Werk Süd'});
    expect((await a.sync()).uploadedChanges, 1);
    expect((await b.sync()).appliedChanges, 1);
    expect(
      (await b.repository.get('projects', 'p'))!.fields['name'],
      'Werk Süd',
    );

    log.clear();
    final idle = await b.sync();
    expect(idle.downloadedFiles, 0);
    expect(
      log.where((l) => l.startsWith('GET') && l.contains('/ops/')),
      isEmpty,
      reason: 'unchanged folder ETags: no downloads',
    );
  });

  group('Login Flow v2', () {
    test('start, pending, then credentials and the WebDAV root', () async {
      var approved = false;
      final client = MockClient((r) async {
        if (r.url.path == '/nc/index.php/login/v2') {
          return http.Response(
            jsonEncode({
              'poll': {
                'token': 'tok',
                'endpoint':
                    'https://cloud.example.com/nc/index.php/login/v2/poll',
              },
              'login':
                  'https://cloud.example.com/nc/index.php/login/v2/flow/abc',
            }),
            200,
          );
        }
        if (r.url.path.endsWith('/poll')) {
          expect(r.bodyFields['token'], 'tok');
          if (!approved) return http.Response('', 404);
          return http.Response(
            jsonEncode({
              'server': 'https://cloud.example.com/nc',
              'loginName': 'alice',
              'appPassword': 'app-pass',
            }),
            200,
          );
        }
        return http.Response('', 500);
      });
      final flow = await LoginFlow.start(
        Uri.parse('https://cloud.example.com/nc'),
        client: client,
      );
      expect(flow.loginUrl.path, endsWith('/flow/abc'));
      expect(await flow.poll(), isNull);
      approved = true;
      final creds = (await flow.poll())!;
      expect((creds.loginName, creds.appPassword), ('alice', 'app-pass'));
      expect(
        creds.webDavRoot().toString(),
        'https://cloud.example.com/nc/remote.php/dav/files/alice/TimeTrack/',
      );
    });
  });
}
