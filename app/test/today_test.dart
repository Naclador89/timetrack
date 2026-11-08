import 'package:flutter_test/flutter_test.dart';

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
}
