// spec: sync-format.md §3, §5, §6, §10
import 'dart:convert';

import 'package:test/test.dart';
import 'package:timetrack_core/timetrack_core.dart';

const devA = 'aaaaaaaaaaaaaaaa';
const devB = 'bbbbbbbbbbbbbbbb';

Change change(String id, Hlc hlc, Map<String, Object?> set) =>
    Change(table: 'work_sessions', id: id, hlc: hlc, set: set);

void main() {
  group('§3 HLC', () {
    test('string form has fixed widths and sorts like the clock', () {
      final h = Hlc(1794067200123, 0x2a, devA);
      expect(h.toString(), '1794067200123-002a-$devA');
      expect(Hlc.parse(h.toString()), h);
      expect(
        Hlc(1794067200123, 1, devA).isAfter(Hlc(1794067200123, 0, devB)),
        isTrue,
      );
      expect(
        Hlc(1794067200123, 0, devB).isAfter(Hlc(1794067200123, 0, devA)),
        isTrue,
      );
      expect(() => Hlc.parse('1794067200123-2a-$devA'), throwsFormatException);
      expect(() => Hlc(0, 0, 'XYZ'), throwsArgumentError);
    });

    test('tick never goes backwards, even if the wall clock does', () {
      var wall = 1000;
      final clock = HlcClock(devA, now: () => wall);
      final a = clock.tick();
      wall = 900; // clock jumped back
      final b = clock.tick();
      final c = clock.tick();
      expect([a.millis, b.millis, c.millis], [1000, 1000, 1000]);
      expect([a.counter, b.counter, c.counter], [0, 1, 2]);
      wall = 2000;
      expect(clock.tick().toString(), Hlc(2000, 0, devA).toString());
    });

    test('receive moves past a remote clock that is ahead', () {
      final clock = HlcClock(devA, now: () => 1000);
      clock.receive(Hlc(5000, 7, devB));
      expect((clock.last.millis, clock.last.counter), (5000, 8));
      expect(clock.tick().isAfter(Hlc(5000, 7, devB)), isTrue);
    });

    test('receive with equal millis takes the larger counter + 1', () {
      final clock = HlcClock(devA, last: Hlc(5000, 3, devA), now: () => 1000);
      clock.receive(Hlc(5000, 9, devB));
      expect(clock.last.counter, 10);
    });

    test('counter overflow moves to the next millisecond', () {
      final clock = HlcClock(
        devA,
        last: Hlc(5000, 0xffff, devA),
        now: () => 1000,
      );
      expect((clock.tick().millis, clock.last.counter), (5001, 0));
    });

    test('device ids are 16 lowercase hex characters', () {
      expect(newDeviceId(), matches(RegExp(r'^[0-9a-f]{16}$')));
    });
  });

  group('§6 merge', () {
    final c1 = change('s', Hlc(1, 0, devA), {'start_utc': 'a', 'note': 'x'});
    final c2 = change('s', Hlc(2, 0, devB), {'note': 'y'});
    final c3 = change('s', Hlc(3, 0, devA), {'end_utc': 'b'});

    Map<String, Object?> fold(List<Change> changes) =>
        changes.fold<StoredRow?>(null, applyChange)!.fields;

    test('the result is independent of order and repetition', () {
      final expected = {'start_utc': 'a', 'note': 'y', 'end_utc': 'b'};
      expect(fold([c1, c2, c3]), expected);
      expect(fold([c3, c2, c1]), expected);
      expect(fold([c2, c1, c3, c1, c2]), expected);
    });

    test('per field, not per row: a stale note edit does not undo end_utc', () {
      final stop = change('s', Hlc(5, 0, devA), {'end_utc': '11:00'});
      final staleEdit = change('s', Hlc(4, 0, devB), {'note': 'late sync'});
      final row = fold([c1, stop, staleEdit]);
      expect(row['end_utc'], '11:00');
      expect(row['note'], 'late sync');
    });

    test(
      'a delete is a tombstone; a later edit does not bring the row back',
      () {
        final del = change('s', Hlc(5, 0, devA), {'deleted': true});
        final edit = change('s', Hlc(6, 0, devB), {'note': 'z'});
        final row = [c1, del, edit].fold<StoredRow?>(null, applyChange)!;
        expect(row.isDeleted, isTrue);
      },
    );

    test('an update can arrive before its create: the row is partial', () {
      final row = applyChange(null, c2);
      expect(row.fields.containsKey('start_utc'), isFalse);
      expect(applyChange(row, c1).fields['note'], 'y');
    });
  });

  group('§5 batch files', () {
    final changes = [
      change('s2', Hlc(20, 0, devA), {'note': 'ä'}),
      change('s1', Hlc(10, 0, devA), {
        'start_utc': '2026-11-07T08:00:00Z',
        'n': 3,
      }),
    ];

    test('round trip; sorted by HLC; named after the first change', () {
      final decoded = decodeBatch(
        encodeBatch(devA, changes),
        expectedDeviceId: devA,
      );
      expect([for (final c in decoded) c.id], ['s1', 's2']);
      expect(decoded.last.set, {'note': 'ä'});
      expect(batchFileName(decoded), '${Hlc(10, 0, devA)}.jsonl.gz.enc');
    });

    test('rejects other devices, newer formats and garbage', () {
      final bytes = encodeBatch(devA, changes);
      expect(
        () => decodeBatch(bytes, expectedDeviceId: devB),
        throwsA(isA<BatchFormatException>()),
      );
      expect(
        () => decodeBatch(utf8.encode('nope')),
        throwsA(isA<BatchFormatException>()),
      );
    });
  });

  group('§10 encryption', () {
    test(
      'seal/open round trip; path is bound as AAD; tampering is detected',
      () async {
        final (params, cipher) = await createEncryption(
          'secret',
          memoryKiB: 64,
          iterations: 1,
        );
        final sealed = await cipher.seal(
          utf8.encode('hello'),
          'devices/a/ops/1',
        );
        expect(utf8.decode(sealed.sublist(0, 4)), 'TTE1');
        expect(
          utf8.decode(await cipher.open(sealed, 'devices/a/ops/1')),
          'hello',
        );
        await expectLater(
          cipher.open(sealed, 'devices/a/ops/2'),
          throwsA(isA<SyncCryptoException>()),
        );
        final tampered = [...sealed]..[20] ^= 1;
        await expectLater(
          cipher.open(tampered, 'devices/a/ops/1'),
          throwsA(isA<SyncCryptoException>()),
        );
        expect(params.toJson()['kdf'], 'argon2id');
      },
    );

    test(
      'a further device unlocks with the passphrase; a wrong one fails',
      () async {
        final (params, first) = await createEncryption(
          'secret',
          memoryKiB: 64,
          iterations: 1,
        );
        final restored = EncryptionParams.fromJson(
          jsonDecode(jsonEncode(params.toJson())) as Map<String, Object?>,
        );
        final second = await unlockEncryption('secret', restored);
        final sealed = await first.seal([1, 2, 3], 'x');
        expect(await second.open(sealed, 'x'), [1, 2, 3]);
        await expectLater(
          unlockEncryption('wrong', restored),
          throwsA(isA<SyncCryptoException>()),
        );
      },
    );
  });
}
