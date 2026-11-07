// spec: concept.md §6 E1 (Android quick access); docs/status.md "always ask
// for a summary"
import 'package:test/test.dart';
import 'package:timetrack_core/timetrack_core.dart';

const dev = 'aaaaaaaaaaaaaaaa';

void main() {
  late InMemorySyncStore store;
  late SyncedRepository repo;
  late DateTime now;
  void at(String hhmm) {
    final p = hhmm.split(':');
    now = DateTime.utc(2026, 11, 4, int.parse(p[0]), int.parse(p[1]));
  }

  Future<String?> run(QuickAction a) => runQuickAction(repo, a, now: () => now);
  Future<TrackerState> state() => TimeTracker(repo, now: () => now).state();

  setUp(() async {
    store = InMemorySyncStore();
    repo = await SyncedRepository.open(store, dev);
    at('07:00');
  });

  test('URIs round-trip; unknown URIs are ignored', () {
    for (final a in QuickAction.values) {
      expect(QuickAction.parse(a.uri), a);
    }
    expect(QuickAction.toggle.uri.toString(), 'timetrack://quick/toggle');
    expect(QuickAction.parse(Uri.parse('timetrack://quick/nope')), isNull);
    expect(QuickAction.parse(Uri.parse('https://quick/toggle')), isNull);
    expect(QuickAction.parse(null), isNull);
  });

  test('toggle clocks in at the last location, then out', () async {
    await repo.write('work_sessions', 's0', {
      'start_utc': '2026-11-03T07:00:00Z',
      'end_utc': '2026-11-03T15:00:00Z',
      'location': 'home',
    });
    await run(QuickAction.toggle);
    expect((await state()).location, WorkLocation.home);
    at('15:00');
    await run(QuickAction.toggle);
    expect((await state()).clockedIn, isFalse);
  });

  test(
    'toggleBreak starts and ends a break; ignored when clocked out',
    () async {
      await run(QuickAction.toggleBreak);
      expect((await state()).onBreak, isFalse);
      await run(QuickAction.clockIn);
      await run(QuickAction.toggleBreak);
      expect((await state()).onBreak, isTrue);
      await run(QuickAction.toggleBreak);
      expect((await state()).onBreak, isFalse);
    },
  );

  test('a stopped project timer is queued for the summary prompt', () async {
    await TimeTracker(repo, now: () => now).startProject('p1');
    final entry = (await state()).entry!.id;
    at('09:00');
    expect(await run(QuickAction.toggleBreak), entry);
    // Resuming after the break starts a new entry; clocking out stops it.
    await run(QuickAction.toggleBreak);
    final resumed = (await state()).entry!.id;
    expect(await run(QuickAction.clockOut), resumed);
    final pending = PendingSummaries(store);
    expect(await pending.take(), [entry, resumed]);
    expect(await pending.take(), isEmpty);
  });

  test('QuickStatus: the stopwatch start stays fixed while working', () async {
    await run(QuickAction.clockIn);
    QuickStatus status() {
      final rows = store.allRows.values.toList();
      final ledger = appLedger(rows, now);
      return QuickStatus.of(
        TrackerState.fromRows(rows),
        ledger,
        ledger.zone.dateOf(now),
        nowMinute: epochMinute(now),
      );
    }

    at('08:30');
    final a = status();
    at('09:10');
    final b = status();
    expect(a.phase, QuickPhase.working);
    expect((a.todayMinutes, b.todayMinutes), (90, 130));
    expect(a.runningSince, epochMinute(DateTime.utc(2026, 11, 4, 7)));
    expect(a, b);
    await run(QuickAction.toggleBreak);
    final c = status();
    expect(c.phase, QuickPhase.onBreak);
    expect(c.breakSince, epochMinute(now));
    expect(c.runningSince, isNull);
  });
}
