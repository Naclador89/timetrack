// spec: backup.md
import 'package:test/test.dart';
import 'package:timetrack_core/timetrack_core.dart';

const deviceA = 'aaaaaaaaaaaaaaaa';
const deviceB = 'bbbbbbbbbbbbbbbb';

/// A device whose wall clock the test moves by hand.
Future<(SyncedRepository, void Function(int))> device(String id) async {
  var ms = 1794067200000;
  final repo = await SyncedRepository.open(
    InMemorySyncStore(),
    id,
    now: () => ms,
  );
  return (repo, (int minutes) => ms += minutes * 60000);
}

Future<List<StoredRow>> rowsOf(SyncedRepository repo, String table) =>
    repo.store.transaction((tx) => tx.rows(table));

Future<Map<String, Object?>> fieldsOf(
  SyncedRepository repo,
  String table,
  String id,
) async => (await repo.get(table, id))!.fields;

Future<Backup> backupOf(SyncedRepository repo) async {
  final rows = await repo.store.watchRows(syncedTables).first;
  return decodeBackup(encodeBackup(rows, DateTime.utc(2026, 11, 8)));
}

void main() {
  test('§1 a backup round-trips; foreign files and newer formats are refused', () async {
    final (a, _) = await device(deviceA);
    await a.write('projects', 'p1', {'name': 'Werk Süd'});
    await a.delete('projects', 'p1');
    final backup = await backupOf(a);
    expect(backup.rows.single.isDeleted, isTrue);
    expect(backup.rows.single.fields['name'], 'Werk Süd');
    expect(backup.exported, DateTime.utc(2026, 11, 8));

    expect(() => decodeBackup('nope'), throwsA(isA<BackupFormatException>()));
    expect(
      () => decodeBackup('{"app":"Other","format":1,"rows":[]}'),
      throwsA(isA<BackupFormatException>()),
    );
    expect(
      () => decodeBackup(
        '{"app":"TimeTrack","format":${syncFormatVersion + 1},"exported":"2026-11-08T00:00:00Z","rows":[]}',
      ),
      throwsA(isA<BackupFormatException>()),
    );
    expect(
      () => decodeBackup(
        '{"app":"TimeTrack","format":1,"exported":"2026-11-08T00:00:00Z","rows":[{"tbl":"projects","id":"p","fields":{"name":"x"},"fieldClock":{"name":"bad"}}]}',
      ),
      throwsA(isA<BackupFormatException>()),
    );
  });

  test(
    '§2.1 merge on an empty device brings everything back and is idempotent',
    () async {
      final (a, _) = await device(deviceA);
      await a.write('projects', 'p1', {'name': 'Werk Süd'});
      await a.write('work_sessions', 's1', {
        'start_utc': '2026-11-03T07:00:00Z',
      });
      final backup = await backupOf(a);

      final (b, _) = await device(deviceB);
      final preview = await restoreBackup(
        b,
        backup,
        RestoreMode.merge,
        dryRun: true,
      );
      expect((preview.added, preview.changed, preview.deleted), (2, 0, 0));
      expect(
        await rowsOf(b, 'projects'),
        isEmpty,
        reason: 'dry run writes nothing',
      );

      final done = await restoreBackup(b, backup, RestoreMode.merge);
      expect((done.added, done.changed, done.deleted), (2, 0, 0));
      expect(await fieldsOf(b, 'projects', 'p1'), {'name': 'Werk Süd'});
      // The original clocks travel along, so other devices treat them as known.
      expect(
        (await b.get('projects', 'p1'))!.fieldClock,
        (await a.get('projects', 'p1'))!.fieldClock,
      );
      expect(await b.store.transaction((tx) => tx.outbox()), hasLength(2));
      expect(
        (await restoreBackup(b, backup, RestoreMode.merge)).isEmpty,
        isTrue,
      );
    },
  );

  test('§2.1 merge keeps everything newer than the backup', () async {
    final (a, tick) = await device(deviceA);
    await a.write('projects', 'p1', {'name': 'Alt', 'client': 'Bosch'});
    await a.write('projects', 'p2', {'name': 'Gelöscht'});
    final backup = await backupOf(a);
    tick(5);
    await a.write('projects', 'p1', {'name': 'Neu'});
    await a.delete('projects', 'p2');
    await a.write('projects', 'p3', {'name': 'Danach'});

    final summary = await restoreBackup(a, backup, RestoreMode.merge);
    expect(summary.isEmpty, isTrue);
    expect(await fieldsOf(a, 'projects', 'p1'), {
      'name': 'Neu',
      'client': 'Bosch',
    });
    expect((await a.get('projects', 'p2'))!.isDeleted, isTrue);
    expect(await fieldsOf(a, 'projects', 'p3'), {'name': 'Danach'});
  });

  test(
    '§2.2 replace makes the data exactly the backup, on every device',
    () async {
      final (a, tick) = await device(deviceA);
      await a.write('projects', 'p1', {'name': 'Alt'});
      await a.write('projects', 'p2', {'name': 'Später gelöscht'});
      final backup = await backupOf(a);
      tick(5);
      await a.write('projects', 'p1', {'name': 'Neu', 'client': 'Bosch'});
      await a.delete('projects', 'p2');
      await a.write('projects', 'p3', {'name': 'Danach'});

      // Device B already has all of it (synced).
      final (b, _) = await device(deviceB);
      final synced = await a.store.transaction((tx) => tx.outbox());
      await b.store.transaction((tx) async {
        for (final c in synced) {
          await tx.putRow(applyChange(await tx.row(c.table, c.id), c));
        }
      });
      await a.store.transaction((tx) => tx.clearOutbox());

      tick(1);
      final preview = await restoreBackup(
        a,
        backup,
        RestoreMode.replace,
        dryRun: true,
      );
      final done = await restoreBackup(a, backup, RestoreMode.replace);
      expect((done.added, done.changed, done.deleted), (1, 1, 1));
      expect((preview.added, preview.changed, preview.deleted), (1, 1, 1));
      expect(await fieldsOf(a, 'projects', 'p1'), {
        'name': 'Alt',
        'client': null,
      });
      expect((await a.get('projects', 'p2'))!.isDeleted, isFalse);
      expect((await a.get('projects', 'p3'))!.isDeleted, isTrue);

      // The fresh writes win on B too.
      final restore = await a.store.transaction((tx) => tx.outbox());
      await b.store.transaction((tx) async {
        for (final c in restore) {
          await tx.putRow(applyChange(await tx.row(c.table, c.id), c));
        }
      });
      for (final id in ['p1', 'p2', 'p3']) {
        expect(
          (await b.get('projects', id))!.fields,
          (await a.get('projects', id))!.fields,
        );
      }
      expect(
        (await restoreBackup(a, backup, RestoreMode.replace)).isEmpty,
        isTrue,
      );
    },
  );
}
