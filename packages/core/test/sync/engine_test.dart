// spec: sync-format.md §7, §7.1, §10
import 'dart:convert';

import 'package:test/test.dart';
import 'package:timetrack_core/timetrack_core.dart';

import 'sync_test_support.dart';

const a = 'aaaaaaaaaaaaaaaa', b = 'bbbbbbbbbbbbbbbb';

void main() {
  for (final kind in StoreKind.values) {
    group(kind.name, () => _engineTests(kind));
  }
}

void _engineTests(StoreKind kind) {
  late InMemoryRemoteFolder server;
  setUp(() => server = InMemoryRemoteFolder());

  test(
    '§7 a write on one device reaches the other; files are encrypted',
    () async {
      final da = await SimDevice.create(a, server, kind: kind);
      final db = await SimDevice.create(b, server, kind: kind);
      await da.repository.write('work_sessions', 's1', {
        'start_utc': '2026-11-07T08:00:00Z',
        'location': 'home',
      });
      expect((await da.engine.sync()).uploadedChanges, 1);
      final report = await db.engine.sync();
      expect((report.downloadedFiles, report.appliedChanges), (1, 1));
      expect(
        (await db.rowsOf('work_sessions'))['s1']!.fields['location'],
        'home',
      );

      final file = server.filePaths.firstWhere((p) => p.contains('/ops/'));
      expect(
        utf8.decode(server.rawFile(file)!, allowMalformed: true),
        isNot(contains('home')),
      );
      expect(server.filePaths, contains('devices/$a/device.json'));
    },
  );

  test('§7 nothing new → nothing downloaded (folder ETag unchanged)', () async {
    final da = await SimDevice.create(a, server, kind: kind);
    final db = await SimDevice.create(b, server, kind: kind);
    await da.repository.write('projects', 'p', {'name': 'X'});
    await da.engine.sync();
    await db.engine.sync();
    expect((await db.engine.sync()).downloadedFiles, 0);
  });

  test(
    '§7 connection lost after upload: retry reuses the name, no duplicate',
    () async {
      final da = await SimDevice.create(a, server, kind: kind);
      final db = await SimDevice.create(b, server, kind: kind);
      await da.engine.sync(); // prepare first, so the fault hits the batch
      await da.repository.write('projects', 'p', {'name': 'X'});
      da.remote.failAfterNextCreate = true;
      expect(await da.trySync(), isNull);
      await da.repository.write('projects', 'p', {'name': 'Y'});
      await da.engine.sync(); // re-sends the frozen batch (412 → done)
      await da.engine.sync(); // then the new outbox
      expect(
        server.filePaths.where((p) => p.startsWith('devices/$a/ops/')),
        hasLength(2),
      );
      await db.engine.sync();
      expect((await db.rowsOf('projects'))['p']!.fields['name'], 'Y');
    },
  );

  test(
    '§7 connection lost before upload or during download: nothing lost',
    () async {
      final da = await SimDevice.create(a, server, kind: kind);
      final db = await SimDevice.create(b, server, kind: kind);
      await da.engine.sync(); // prepare first, so the fault hits the batch
      await da.repository.write('projects', 'p', {'name': 'X'});
      da.remote.failBeforeNextCreate = true;
      expect(await da.trySync(), isNull);
      await da.engine.sync();
      db.remote.failNextRead = true;
      expect(await db.trySync(), isNull);
      await db.engine.sync();
      expect((await db.rowsOf('projects'))['p']!.fields['name'], 'X');
    },
  );

  test('§7.1 two sessions opened offline: the older one is closed at the newer start', () async {
    final da = await SimDevice.create(a, server, kind: kind);
    final db = await SimDevice.create(b, server, kind: kind);
    await da.repository.write('work_sessions', 'early', {
      'start_utc': '2026-11-07T08:00:00Z',
      'end_utc': null,
    });
    await db.repository.write('work_sessions', 'late', {
      'start_utc': '2026-11-07T08:05:00Z',
      'end_utc': null,
    });
    await da.engine.sync();
    final report = await db.engine.sync();
    expect(report.resolvedRows, 1);
    await db.engine.sync();
    await da.engine.sync();
    for (final d in [da, db]) {
      final rows = (await d.rowsOf('work_sessions'));
      expect(rows['early']!.fields['end_utc'], '2026-11-07T08:05:00Z');
      expect(rows['late']!.fields['end_utc'], isNull);
    }
  });

  test('§10 a wrong passphrase on a further device is rejected', () async {
    await SimDevice.create(a, server, kind: kind);
    await expectLater(
      SimDevice.create(b, server, passphrase: 'wrong', kind: kind),
      throwsA(isA<SyncCryptoException>()),
    );
  });

  test('§10 a damaged file stops the sync without applying anything', () async {
    final da = await SimDevice.create(a, server, kind: kind);
    final db = await SimDevice.create(b, server, kind: kind);
    await da.repository.write('projects', 'p', {'name': 'X'});
    await da.engine.sync();
    final file = server.filePaths.firstWhere((p) => p.contains('/ops/'));
    server.tamper(file, [...server.rawFile(file)!]..[30] ^= 1);
    await expectLater(db.engine.sync(), throwsA(isA<SyncCryptoException>()));
    expect((await db.rowsOf('projects')), isEmpty);
  });

  test('§9 a newer remote format stops the sync', () async {
    final da = await SimDevice.create(a, server, kind: kind);
    final json = jsonDecode(
      utf8.decode(server.rawFile('format.json')!),
    ) as Map<String, Object?>;
    await server.writeFile(
      'format.json',
      utf8.encode(jsonEncode({...json, 'format': 2})),
    );
    await expectLater(da.engine.sync(), throwsA(isA<SyncFormatException>()));
  });
}
