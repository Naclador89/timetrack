// spec: calculations.md §3.1
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timetrack_core/timetrack_core.dart';

import 'helpers.dart';

/// "Werk Süd" with a 10-hour budget, 4 h on Monday and 4 h on Tuesday.
Future<void> project(SyncedRepository repo) async {
  await repo.write('projects', 'p', {
    'name': 'Werk Süd',
    'project_number': 'P-2026/014',
    'budget_min': 600,
  });
  for (final (day, note) in [('02', 'Planung'), ('03', 'Abnahme')]) {
    await repo.write('work_sessions', 's$day', {
      'start_utc': '2026-11-${day}T07:00:00Z',
      'end_utc': '2026-11-${day}T11:00:00Z',
      'location': 'office',
    });
    await repo.write('project_entries', 'd$day', {
      'project_id': 'p',
      'date': '2026-11-$day',
      'duration_min': 240,
      'note': note,
    });
  }
}

void main() {
  testWidgets('the project page: figures, budget and what was done', (
    tester,
  ) async {
    await pumpApp(tester, seed: project);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await settle(tester);
    expect(find.text('8:00 of 10:00 (80 %)'), findsOneWidget, reason: 'list');
    await tester.tap(find.text('Werk Süd'));
    await settle(tester);

    expect(find.text('P-2026/014'), findsOneWidget);
    expect(find.text('This week'), findsOneWidget);
    expect(find.text('8:00'), findsWidgets);
    expect(find.text('2:00 left'), findsOneWidget);
    expect(find.text('Planung'), findsOneWidget);
    expect(find.text('Abnahme'), findsOneWidget);

    // Book more from the page: the project is preset.
    await tester.tap(find.text('Book project time'));
    await settle(tester);
    expect(find.text('Werk Süd'), findsWidgets);
  });

  testWidgets('80 % of the budget is a notice that opens the project', (
    tester,
  ) async {
    await pumpApp(tester, seed: project);
    expect(
      find.textContaining('Werk Süd: 80 % of the budget (10:00) used'),
      findsOneWidget,
    );
    await tester.tap(find.text('Open project'));
    await settle(tester);
    expect(find.text('2:00 left'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
  });
}
