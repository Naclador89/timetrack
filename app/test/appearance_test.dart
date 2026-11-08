import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:timetrack/app/appearance.dart';

import 'helpers.dart';

void main() {
  testWidgets('appearance: light or dark is kept on this device', (
    tester,
  ) async {
    final (store, _) = await pumpApp(tester);
    ThemeMode mode() =>
        tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode!;
    expect(mode(), ThemeMode.system);

    final context = tester.element(find.byType(Scaffold).first);
    GoRouterHelper(context).push('/settings');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Light'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Light'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();
    expect(mode(), ThemeMode.light);
    expect(
      await tester.runAsync(() => Appearance.load(store)),
      isA<Appearance>().having((a) => a.mode, 'mode', ThemeMode.light),
    );
  });
}
