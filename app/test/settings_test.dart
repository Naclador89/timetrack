// spec: navigation.md, "Settings structure"
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:timetrack_core/timetrack_core.dart';

import 'helpers.dart';

void main() {
  Future<void> openSettings(WidgetTester tester) async {
    final context = tester.element(find.byType(Scaffold).first);
    GoRouterHelper(context).push('/settings');
    await tester.pumpAndSettle();
  }

  testWidgets('the overview lists the pages with a summary', (tester) async {
    await pumpApp(
      tester,
      seed: (repo) async {
        await saveSetting(repo, SettingKeys.noticeShow('balance_zone'), false);
      },
    );
    await openSettings(tester);
    for (final title in [
      'Sync',
      'Working time & account',
      'Clocking & breaks',
      'Home-office rules',
      'Trips & supplements',
      'Notices',
      'Appearance & updates',
      'Setup',
    ]) {
      expect(find.text(title), findsOneWidget, reason: title);
    }
    // Only on Windows.
    expect(find.text('Work PC'), findsNothing);
    final all = NoticeCategory.values.length;
    expect(find.text('${all - 1} of $all on'), findsOneWidget);
    expect(find.text('Missing breaks: Warn only'), findsOneWidget);
  });

  testWidgets('a page opens with its groups', (tester) async {
    await pumpApp(tester);
    await openSettings(tester);
    await tester.tap(find.text('Clocking & breaks'));
    await tester.pumpAndSettle();
    expect(find.text('Breaks'), findsOneWidget);
    expect(find.text('Missing breaks'), findsOneWidget);
    await tester.tap(find.text('Deduct automatically'));
    await settle(tester);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Missing breaks: Deduct automatically'), findsOneWidget);
  });

  testWidgets('the search finds settings of every page, under their page', (
    tester,
  ) async {
    final (store, _) = await pumpApp(tester);
    await openSettings(tester);
    await tester.enterText(find.byType(TextField).first, 'resume');
    await tester.pumpAndSettle();
    expect(find.text('Clocking & breaks › Clocking'), findsOneWidget);
    expect(find.text('Trips & supplements'), findsNothing);
    await tester.tap(find.text('Resume the project after a break'));
    await settle(tester);
    expect(
      store.rowsOf('settings')[SettingKeys.resumeAfterBreak]!.fields['value'],
      false,
    );
  });
}
