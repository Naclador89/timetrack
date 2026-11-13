// spec: navigation.md, Keyboard shortcuts
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timetrack_core/timetrack_core.dart';

import 'helpers.dart';

void main() {
  Future<TrackerState> state(
    WidgetTester tester,
    SyncedRepository repo,
  ) async => (await tester.runAsync(
    () => TimeTracker(repo, now: () => appTestNow).state(),
  ))!;

  Future<void> ctrl(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(key);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await settle(tester);
  }

  testWidgets('Ctrl+E clocks in, Ctrl+P takes a break, Ctrl+E clocks out', (
    tester,
  ) async {
    final (_, repo) = await pumpApp(tester);
    await ctrl(tester, LogicalKeyboardKey.keyE);
    expect((await state(tester, repo)).clockedIn, isTrue);
    await ctrl(tester, LogicalKeyboardKey.keyP);
    expect((await state(tester, repo)).onBreak, isTrue);
    await ctrl(tester, LogicalKeyboardKey.keyP);
    expect((await state(tester, repo)).onBreak, isFalse);
    await ctrl(tester, LogicalKeyboardKey.keyE);
    expect((await state(tester, repo)).clockedIn, isFalse);
  });

  testWidgets('calendar: → next week, T back, M month; Ctrl+1 Today', (
    tester,
  ) async {
    await pumpApp(tester);
    await ctrl(tester, LogicalKeyboardKey.digit2);
    expect(find.text('Week 45'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(find.text('Week 46'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyT);
    await tester.pumpAndSettle();
    expect(find.text('Week 45'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
    await tester.pumpAndSettle();
    expect(find.text('November 2026'), findsWidgets);
    await ctrl(tester, LogicalKeyboardKey.digit1);
    expect(find.text('Not clocked in'), findsOneWidget);
  });

  testWidgets('F1 lists the shortcuts; plain keys leave text fields alone', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.f1);
    await tester.pumpAndSettle();
    expect(find.text('Keyboard shortcuts'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    await ctrl(tester, LogicalKeyboardKey.digit4);
    await tester.tap(find.byType(TextField).first);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyT);
    await tester.pumpAndSettle();
    expect(find.text('Keyboard shortcuts'), findsNothing);
  });
}
