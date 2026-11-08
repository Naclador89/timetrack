// spec: reminders.md
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:timetrack/reminders/forgotten_clock_out.dart';
import 'package:timetrack/reminders/reminders.dart';
import 'package:timetrack_core/timetrack_core.dart';

import 'helpers.dart';

/// Clocked in yesterday (Tue 3 Nov) at 08:00 and forgot to clock out.
Future<void> forgotYesterday(SyncedRepository repo) async {
  await repo.write('work_schedules', 'w', {
    'valid_from': '2026-01-01',
    for (final d in ['mon', 'tue', 'wed', 'thu', 'fri']) 'minutes_$d': 480,
  });
  await repo.write('work_sessions', 's', {
    'start_utc': '2026-11-03T07:00:00Z',
    'end_utc': null,
    'location': 'office',
  });
}

void main() {
  testWidgets('§1 forgotten clock-out: a suggestion clocks out then', (
    tester,
  ) async {
    final (_, repo) = await pumpApp(tester, seed: forgotYesterday);
    expect(find.text('Still clocked in?'), findsOneWidget);
    expect(
      find.text('Clocked in since yesterday, 08:00. When did you finish?'),
      findsOneWidget,
    );
    await tester.tap(find.text('yesterday, 16:30 · Target reached'));
    await settle(tester);
    final session = await tester.runAsync(() => repo.get('work_sessions', 's'));
    expect(session!.fields['end_utc'], '2026-11-03T15:30:00Z');
    expect(find.text('Clocked out at yesterday, 16:30'), findsOneWidget);
  });

  testWidgets('§1 "still working" is not asked again for that session', (
    tester,
  ) async {
    final (store, _) = await pumpApp(tester, seed: forgotYesterday);
    await tester.tap(find.text('Still working'));
    await settle(tester);
    expect(find.text('Still clocked in?'), findsNothing);
    expect(
      await tester.runAsync(
        () => store.transaction(
          (tx) => tx.localValue(ForgottenClockOutHost.ackKey),
        ),
      ),
      's',
    );
  });

  testWidgets('§2 the reminders can be switched off', (tester) async {
    final (store, _) = await pumpApp(
      tester,
      overrides: [remindersAvailableProvider.overrideWithValue(true)],
    );
    final context = tester.element(find.byType(Scaffold).first);
    GoRouterHelper(context).push('/settings');
    await tester.pumpAndSettle();
    final tile = find.text('Reminders: Break due');
    await tester.scrollUntilVisible(
      tile,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(tile);
    await tester.pumpAndSettle();
    await tester.tap(tile);
    await settle(tester);
    final rows = await tester.runAsync(
      () => store.watchRows(syncedTables).first,
    );
    expect(AppSettings.fromRows(rows!).remindBreak, isFalse);
  });
}
