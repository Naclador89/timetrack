// spec: calculations.md §21
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:timetrack_core/timetrack_core.dart';

import 'helpers.dart';

void main() {
  testWidgets('§21.3 night hours show on Today; excluded, they explain why', (
    tester,
  ) async {
    await pumpApp(
      tester,
      seed: (repo) async {
        await saveSetting(repo, SettingKeys.nightWorkCredit, 'exclude');
        // Wed 04:00–07:30 local, before "now" (08:30).
        await repo.write('work_sessions', 's', {
          'start_utc': '2026-11-04T03:00:00Z',
          'end_utc': '2026-11-04T06:30:00Z',
          'location': 'office',
        });
      },
    );
    expect(find.text('Night hours'), findsOneWidget);
    expect(find.text('2:00'), findsWidgets);
    await tester.tap(find.text('Night hours'));
    await tester.pumpAndSettle();
    expect(find.text('Paid out, not on the overtime account.'), findsOneWidget);
    expect(find.text('− 2:00'), findsOneWidget);
  });

  testWidgets('§21 special holidays and night work are settings', (
    tester,
  ) async {
    final (store, _) = await pumpApp(tester);
    final context = tester.element(find.byType(Scaffold).first);
    GoRouterHelper(context).push('/settings/travel');
    await tester.pumpAndSettle();
    final tile = find.text('Special holidays');
    await tester.scrollUntilVisible(
      tile,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(tile);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Christmas Day'));
    await tester.tap(find.text('Whit Sunday'));
    await tester.tap(find.text('Save'));
    await settle(tester);
    expect(find.text('Whit Sunday, Christmas Day'), findsOneWidget);

    final exclude = find.text('Not on the account');
    await tester.scrollUntilVisible(
      exclude,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(exclude);
    await settle(tester);
    final rows = store.rowsOf('settings');
    expect(
      rows[SettingKeys.specialDays]!.fields['value'],
      'whit_sunday,christmas_day',
    );
    expect(rows[SettingKeys.nightWorkCredit]!.fields['value'], 'exclude');
  });
}
