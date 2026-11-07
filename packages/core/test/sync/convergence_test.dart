// spec: sync-format.md §1, §6, §7 — property-based convergence test.
//
// Three devices with skewed clocks write randomly to a small set of rows (so
// conflicts are frequent), sync in random order and lose the connection at
// random moments. After syncing until nothing changes any more, every device
// must hold exactly the state obtained by merging all uploaded changes, every
// local write must have been uploaded, and at most one session may be open.
import 'dart:math';

import 'package:test/test.dart';
import 'package:timetrack_core/timetrack_core.dart';

import 'sync_test_support.dart';

const _ids = ['aaaaaaaaaaaaaaaa', 'bbbbbbbbbbbbbbbb', 'cccccccccccccccc'];
const _tables = ['work_sessions', 'project_entries', 'projects'];

String _iso(int millis) =>
    '${DateTime.fromMillisecondsSinceEpoch(millis ~/ 60000 * 60000, isUtc: true).toIso8601String().substring(0, 16)}:00Z';

Future<void> _runScenario(int seed, {int steps = 120}) async {
  final random = Random(seed);
  final server = InMemoryRemoteFolder();
  var time = 1794000000000;
  final devices = <SimDevice>[];
  for (final id in _ids) {
    final skew = random.nextInt(600001) - 300000; // ±5 minutes
    devices.add(await SimDevice.create(id, server, now: () => time + skew));
  }
  final localWrites = <String>{};

  for (var step = 0; step < steps; step++) {
    time += random.nextInt(120000);
    final device = devices[random.nextInt(devices.length)];
    final roll = random.nextDouble();
    if (roll < 0.55) {
      final table = _tables[random.nextInt(_tables.length)];
      final id = 'r${random.nextInt(4)}';
      final fields = <String, Object?>{
        if (random.nextBool())
          'start_utc': _iso(time - random.nextInt(3600000)),
        if (random.nextBool()) 'end_utc': random.nextBool() ? null : _iso(time),
        if (random.nextBool()) 'note': 'n${random.nextInt(100)}',
        if (random.nextDouble() < 0.1) 'deleted': random.nextDouble() < 0.7,
      };
      if (fields.isEmpty) fields['note'] = 'touch';
      final change = await device.repository.write(table, id, fields);
      localWrites.add(change.hlc.toString());
    } else {
      switch (random.nextInt(12)) {
        case 0:
          device.remote.failBeforeNextCreate = true;
        case 1:
          device.remote.failAfterNextCreate = true;
        case 2:
          device.remote.failNextRead = true;
      }
      await device.trySync();
      device.remote
        ..failBeforeNextCreate = false
        ..failAfterNextCreate = false
        ..failNextRead = false;
    }
  }

  // Sync until a full round changes nothing (bounded).
  for (var round = 0; round < 10; round++) {
    var activity = 0;
    for (final d in devices) {
      final r = (await d.engine.sync());
      activity += r.uploadedChanges + r.downloadedFiles + r.resolvedRows;
    }
    if (activity == 0) break;
    if (round == 9) fail('seed $seed: no quiescence after 10 rounds');
  }

  // Expected state: all uploaded changes merged (in any order, §6).
  final cipher = await connectSyncFolder(
    server,
    'correct horse',
    memoryKiB: 64,
    iterations: 1,
  );
  final uploaded = <Change>[];
  for (final path in server.filePaths.where((p) => p.contains('/ops/'))) {
    uploaded.addAll(
      decodeBatch(await cipher.open(server.rawFile(path)!, path)),
    );
  }
  final expected = <String, StoredRow>{};
  for (final c in uploaded..shuffle(random)) {
    final key = '${c.table}/${c.id}';
    expected[key] = applyChange(expected[key], c);
  }

  final uploadedHlcs = {for (final c in uploaded) c.hlc.toString()};
  expect(
    localWrites.difference(uploadedHlcs),
    isEmpty,
    reason: 'seed $seed: lost writes',
  );
  expect(
    uploaded.length,
    uploadedHlcs.length,
    reason: 'seed $seed: duplicated changes',
  );

  for (final d in devices) {
    final actual = d.store.allRows;
    expect(
      actual.keys.toSet(),
      expected.keys.toSet(),
      reason: 'seed $seed ${d.id}: rows',
    );
    for (final key in expected.keys) {
      expect(
        actual[key]!.fields,
        expected[key]!.fields,
        reason: 'seed $seed ${d.id}: $key',
      );
      expect(
        actual[key]!.fieldClock,
        expected[key]!.fieldClock,
        reason: 'seed $seed ${d.id}: clocks of $key',
      );
    }
    for (final table in ['work_sessions', 'project_entries']) {
      final open = d.store
          .rowsOf(table)
          .values
          .where(
            (r) =>
                !r.isDeleted &&
                r.fields['end_utc'] == null &&
                r.fields['start_utc'] is String,
          );
      expect(
        open.length,
        lessThanOrEqualTo(1),
        reason: 'seed $seed ${d.id}: §7.1 in $table',
      );
    }
  }
}

void main() {
  test('§1/§6/§7 three devices converge under random edits, syncs and connection losses', () async {
    for (var seed = 1; seed <= 30; seed++) {
      await _runScenario(seed);
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}
