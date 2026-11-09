import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timetrack_core/timetrack_core.dart';

import 'helpers.dart';

void main() {
  // spec: calculations.md §18
  testWidgets('§18 Today shows when the target and 10 hours are reached', (
    tester,
  ) async {
    final (_, repo) = await pumpApp(tester);
    await tester.runAsync(
      () => repo.write('work_schedules', 'w', {
        'valid_from': '2026-01-01',
        for (final d in ['mon', 'tue', 'wed', 'thu', 'fri']) 'minutes_$d': 480,
      }),
    );
    await settle(tester);
    expect(find.textContaining('Target reached'), findsNothing);

    await tester.tap(find.text('Clock in'));
    await settle(tester);
    // Clocked in at 8:30: 8 h of work plus the 30-minute break.
    expect(
      find.text('Target reached at 17:00 (incl. 30 min break) · 10 h at 19:15'),
      findsOneWidget,
    );
  });

  // spec: calculations.md §19
  group('§19 the time of a stamp is asked', () {
    Future<void> enterTime(WidgetTester tester, int hour, int minute) async {
      await tester.tap(find.byIcon(Icons.keyboard_outlined));
      await tester.pumpAndSettle();
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), '$hour');
      await tester.enterText(fields.at(1), '$minute'.padLeft(2, '0'));
      await tester.tap(find.text('OK'));
      await settle(tester);
    }

    testWidgets('now is preselected; an earlier time is stored', (
      tester,
    ) async {
      await pumpApp(tester, askStampTime: true);
      await tester.tap(find.text('Clock in'));
      await tester.pumpAndSettle();
      expect(find.byType(TimePickerDialog), findsOneWidget);
      await enterTime(tester, 8, 10);
      expect(find.text('Clocked in since 08:10'), findsOneWidget);

      await tester.tap(find.text('Break'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await settle(tester);
      expect(find.text('On break since 08:30'), findsOneWidget);
    });

    testWidgets('cancelled or impossible: nothing is stamped', (tester) async {
      await pumpApp(tester, askStampTime: true);
      await tester.tap(find.text('Clock in'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await settle(tester);
      expect(find.text('Not clocked in'), findsOneWidget);

      await tester.tap(find.text('Clock in'));
      await tester.pumpAndSettle();
      await enterTime(tester, 9, 0);
      expect(find.text('That time is in the future.'), findsOneWidget);
      expect(find.text('Not clocked in'), findsOneWidget);
    });

    testWidgets('a clock-in ahead of now is refused, not moved to yesterday', (
      tester,
    ) async {
      // Monday 07:58; the last session ended on Friday.
      final (_, repo) = await pumpApp(
        tester,
        askStampTime: true,
        clock: () => DateTime.utc(2026, 11, 9, 6, 58),
        seed: (repo) => repo.write('work_sessions', 'fri', {
          'start_utc': '2026-11-06T07:00:00Z',
          'end_utc': '2026-11-06T15:00:00Z',
          'location': 'office',
        }),
      );
      await tester.tap(find.text('Clock in'));
      await tester.pumpAndSettle();
      await enterTime(tester, 8, 0);
      expect(find.text('That time is in the future.'), findsOneWidget);
      final open = await tester.runAsync(
        () => TimeTracker(repo, now: () => appTestNow).state(),
      );
      expect(open!.clockedIn, isFalse);
    });
  });
}
