// spec: calculations.md §23
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timetrack/features/calendar/day_screen.dart';

import 'helpers.dart';

void main() {
  testWidgets('reports show pattern hints; a hint opens its first day', (
    tester,
  ) async {
    await pumpApp(
      tester,
      seed: (repo) async {
        // 8 h without a break on Monday and Tuesday.
        for (final (id, date) in [('a', '2026-11-02'), ('b', '2026-11-03')]) {
          await repo.write('work_sessions', id, {
            'start_utc': '${date}T07:00:00Z',
            'end_utc': '${date}T15:00:00Z',
            'location': 'office',
          });
        }
      },
    );
    await tester.tap(find.text('Reports').last);
    await tester.pumpAndSettle();
    final hint = find.text('2× too little break – step out more often?');
    await tester.scrollUntilVisible(hint, 200);
    expect(find.text('Worth a look'), findsOneWidget);
    await tester.tap(hint);
    await tester.pumpAndSettle();
    expect(find.byType(DayScreen), findsOneWidget);
    expect(find.text('Monday, November 2'), findsOneWidget);
  });

  testWidgets('no pattern, no card', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Reports').last);
    await tester.pumpAndSettle();
    expect(find.text('Worth a look'), findsNothing);
  });
}
