// spec: calculations.md §22
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:timetrack_core/timetrack_core.dart';

import 'helpers.dart';

void main() {
  testWidgets('§22 the week view shows worked time and the average', (
    tester,
  ) async {
    await pumpApp(
      tester,
      seed: (repo) async {
        await saveSetting(repo, SettingKeys.balanceStartDate, '2026-11-02');
        // Mon and Tue, 12 h each (06:00–18:00 local).
        for (final d in ['02', '03']) {
          await repo.write('work_sessions', 's$d', {
            'start_utc': '2026-11-${d}T05:00:00Z',
            'end_utc': '2026-11-${d}T17:00:00Z',
            'location': 'office',
          });
        }
      },
    );
    await tester.tap(find.text('Calendar').last);
    await tester.pumpAndSettle();
    final line = find.text('Worked 24:00 of max. 60:00');
    await tester.scrollUntilVisible(
      line,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(line, findsOneWidget);
    expect(
      find.text('Average of 24 weeks 24:00 (limit 48:00)'),
      findsOneWidget,
    );
  });

  testWidgets('§22 the limits are settings', (tester) async {
    final (store, _) = await pumpApp(tester);
    final context = tester.element(find.byType(Scaffold).first);
    GoRouterHelper(context).push('/settings/account');
    await tester.pumpAndSettle();
    final tile = find.text('Most per week');
    await tester.scrollUntilVisible(
      tile,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(tile);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '0');
    await tester.tap(find.text('Save'));
    await settle(tester);
    expect(store.rowsOf('settings')[SettingKeys.weekMax]!.fields['value'], 0);
  });
}
