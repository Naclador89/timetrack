// spec: work-pc.md §2
import 'package:test/test.dart';
import 'package:timetrack_core/timetrack_core.dart';

const dev = 'aaaaaaaaaaaaaaaa';

void main() {
  late InMemorySyncStore store;
  late SyncedRepository repo;
  // 8:00 in Berlin.
  var now = DateTime.utc(2026, 11, 9, 7);
  StartPrompt prompt() => StartPrompt(store, now: () => now);

  Future<void> session(String id, String start, String? end, {String? at}) =>
      repo.write('work_sessions', id, {
        'start_utc': start,
        'end_utc': end,
        'location': at ?? 'office',
      });

  setUp(() async {
    store = InMemorySyncStore();
    repo = await SyncedRepository.open(store, dev);
    now = DateTime.utc(2026, 11, 9, 7);
  });

  test('§2 nothing tracked today → ask, offering the last location', () async {
    await session(
      's0',
      '2026-11-06T07:00:00Z',
      '2026-11-06T15:00:00Z',
      at: 'home',
    );
    expect(await prompt().offer(), WorkLocation.home);
  });

  test('§2 no sessions at all → ask, offering the office', () async {
    expect(await prompt().offer(), WorkLocation.office);
  });

  test("§2 today's day type wins over the last location", () async {
    await session('s0', '2026-11-06T07:00:00Z', '2026-11-06T15:00:00Z');
    await repo.write('days', '2026-11-09', {'type': 'home'});
    expect(await prompt().offer(), WorkLocation.home);
  });

  test('§2 clocked in (e.g. on the phone) → no question', () async {
    await session('s1', '2026-11-09T06:15:00Z', null);
    expect(await prompt().offer(), isNull);
  });

  test('§2 a session today that already ended → no question', () async {
    await session('s1', '2026-11-09T05:00:00Z', '2026-11-09T06:00:00Z');
    expect(await prompt().offer(), isNull);
  });

  test('§2 a night session into today counts (home time zone)', () async {
    // 22:00–00:30 Berlin: ends 30 minutes into today.
    await session('s1', '2026-11-08T21:00:00Z', '2026-11-08T23:30:00Z');
    expect(await prompt().offer(), isNull);
  });

  test('§2 a session ending at midnight belongs to yesterday', () async {
    await session('s1', '2026-11-08T21:00:00Z', '2026-11-08T23:00:00Z');
    expect(await prompt().offer(), isNotNull);
  });

  test('§2 a deleted session does not count', () async {
    await session('s1', '2026-11-09T05:00:00Z', '2026-11-09T06:00:00Z');
    await repo.delete('work_sessions', 's1');
    expect(await prompt().offer(), isNotNull);
  });

  test('§2 "not today" holds until the next day', () async {
    await prompt().decline();
    expect(await prompt().offer(), isNull);
    now = DateTime.utc(2026, 11, 9, 16);
    expect(await prompt().offer(), isNull, reason: 'second sign-in today');
    now = DateTime.utc(2026, 11, 10, 7);
    expect(await prompt().offer(), isNotNull);
  });
}
