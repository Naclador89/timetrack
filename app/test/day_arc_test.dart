// spec: navigation.md "Today" (day arc), reminders.md §2 (target reached)
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timetrack/widgets/day_arc.dart';
import 'package:timetrack/widgets/motion.dart';
import 'package:timetrack_core/timetrack_core.dart';

import 'helpers.dart';

/// 8 h Mon–Fri from Monday 2 Nov.
Future<void> _schedule(SyncedRepository repo) async {
  await repo.write('work_schedules', 'w', {
    'valid_from': '2026-11-02',
    for (final d in ['mon', 'tue', 'wed', 'thu', 'fri']) 'minutes_$d': 480,
  });
}

Future<void> _session(
  SyncedRepository repo,
  String id,
  String from, [
  String? to,
]) => repo.write('work_sessions', id, {
  'start_utc': from,
  'end_utc': ?to,
  'location': 'office',
});

void main() {
  testWidgets('nothing worked yet: the ring; once clocked in: the arc', (
    tester,
  ) async {
    final (_, repo) = await pumpApp(tester, seed: _schedule);
    expect(find.byType(ProgressRing), findsOneWidget);
    expect(find.byType(DayArc), findsNothing);

    await tester.runAsync(() => _session(repo, 's', '2026-11-04T06:00:00Z'));
    await settle(tester);
    final arc = tester.widget<DayArc>(find.byType(DayArc));
    final at = epochMinute(appTestNow);
    expect(arc.start, at - 90);
    expect(arc.now, at);
    // 8 h + the 30 min break still required; 10 h + 45 min (ArbZG §4).
    expect(arc.targetAt, at - 90 + 510);
    expect(arc.end, at - 90 + 645);
  });

  testWidgets('a finished day: target tick where it was reached', (
    tester,
  ) async {
    await pumpApp(
      tester,
      seed: (repo) async {
        await _schedule(repo);
        await _session(
          repo,
          'a',
          '2026-11-03T23:00:00Z',
          '2026-11-04T03:00:00Z',
        );
        await _session(
          repo,
          'b',
          '2026-11-04T03:30:00Z',
          '2026-11-04T07:30:00Z',
        );
      },
    );
    final arc = tester.widget<DayArc>(find.byType(DayArc));
    final start = epochMinute(DateTime.utc(2026, 11, 3, 23));
    expect((arc.start, arc.targetAt, arc.now), (start, start + 510, null));
    expect(arc.end, start + 630, reason: '10 h of work plus the 30 min gap');
  });

  testWidgets('the target pulse plays when reached on screen, not on opening', (
    tester,
  ) async {
    final (_, repo) = await pumpApp(
      tester,
      seed: (repo) async {
        await _schedule(repo);
        await _session(repo, 's', '2026-11-04T07:00:00Z');
      },
    );
    expect(find.byKey(const ValueKey('target-pulse-1')), findsNothing);
    // 7:30 h earlier today, then a 30 min break: 8 h reached now.
    await tester.runAsync(
      () => _session(
        repo,
        'early',
        '2026-11-03T23:00:00Z',
        '2026-11-04T06:30:00Z',
      ),
    );
    await settle(tester);
    expect(find.byKey(const ValueKey('target-pulse-1')), findsOneWidget);
  });

  testWidgets('opening after the target was reached plays no pulse', (
    tester,
  ) async {
    await pumpApp(
      tester,
      seed: (repo) async {
        await _schedule(repo);
        await _session(
          repo,
          'early',
          '2026-11-03T23:00:00Z',
          '2026-11-04T06:30:00Z',
        );
        await _session(repo, 's', '2026-11-04T07:00:00Z');
      },
    );
    expect(find.byType(DayArc), findsOneWidget);
    expect(find.byKey(const ValueKey('target-pulse-1')), findsNothing);
  });
}
