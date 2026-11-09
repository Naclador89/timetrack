// spec: booking-transfer.md §1, §5, §7
import 'package:flutter_test/flutter_test.dart';
import 'package:timetrack/booking/booking_store.dart';
import 'package:timetrack/work_pc/work_pc.dart';
import 'package:timetrack_core/timetrack_core.dart';

import 'helpers.dart';
import 'week_check_test.dart' show openCalendar;

/// Week 45: Monday 1:40 h on P100/7 and 1 h on a project without a number.
Future<void> week(SyncedRepository repo, {bool withUrl = true}) async {
  await repo.write('work_schedules', 'w', {
    'valid_from': '2026-01-01',
    for (final d in ['mon', 'tue', 'wed', 'thu', 'fri']) 'minutes_$d': 480,
  });
  await repo.write('projects', 'a', {
    'name': 'Werk Süd',
    'project_number': 'P100',
    'order_number': '7',
  });
  await repo.write('projects', 'x', {'name': 'Ohne Nummer'});
  await repo.write('work_sessions', 's', {
    'start_utc': '2026-11-02T07:00:00Z',
    'end_utc': '2026-11-02T15:00:00Z',
    'location': 'office',
  });
  for (final (id, project, minutes) in [('e1', 'a', 100), ('e2', 'x', 60)]) {
    await repo.write('project_entries', id, {
      'project_id': project,
      'date': '2026-11-02',
      'duration_min': minutes,
    });
  }
  if (withUrl) await saveBookingUrl(repo.store, 'http://booking.example/x');
}

final overrides = [
  bookingSupportedProvider.overrideWithValue(true),
  workPcPlatformProvider.overrideWithValue(null),
];

void main() {
  testWidgets('§1 not offered without an address', (tester) async {
    await pumpApp(
      tester,
      seed: (repo) => week(repo, withUrl: false),
      overrides: overrides,
    );
    await openCalendar(tester);
    expect(find.text('Booking system'), findsNothing);
  });

  testWidgets('§1 not offered off Windows', (tester) async {
    await pumpApp(
      tester,
      seed: week,
      overrides: [
        bookingSupportedProvider.overrideWithValue(false),
        workPcPlatformProvider.overrideWithValue(null),
      ],
    );
    await openCalendar(tester);
    expect(find.text('Booking system'), findsNothing);
  });

  testWidgets('§5 preview: rounded hours, skipped project, rounding', (
    tester,
  ) async {
    await pumpApp(tester, seed: week, overrides: overrides);
    await openCalendar(tester);
    expect(find.text('Not transferred yet'), findsOneWidget);
    await tester.tap(find.text('Transfer to booking system'));
    await settle(tester);
    expect(find.text('Transfer week 45'), findsOneWidget);
    expect(find.text('P100'), findsOneWidget);
    expect(find.text('Werk Süd'), findsOneWidget);
    expect(find.text('1.5'), findsNWidgets(4), reason: 'Mon, row and sums');
    expect(
      find.text(
        'Ohne Nummer (1:00) has no project number and is not transferred',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Rounded to half hours: 1:30 instead of 1:40'),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await settle(tester);
    expect(find.text('Transfer week 45'), findsNothing);
  });

  testWidgets('§7 the marker shows the transfer and later changes', (
    tester,
  ) async {
    final (_, repo) = await pumpApp(
      tester,
      seed: (repo) async {
        await week(repo);
        final w = WeekBooking(
          monday: LocalDate(2026, 11, 2),
          rows: const [
            WeekBookingRow(
              projectNumber: 'P100',
              orderNumber: '7',
              projectNames: ['Werk Süd'],
              halfHours: [3, 0, 0, 0, 0, 0, 0],
            ),
          ],
          skipped: const [],
          runningTimer: false,
          unassignedByDay: const {},
          roundingDifferences: const [],
          exactMinutes: 90,
        );
        await saveBookingMarker(repo.store, w, DateTime.utc(2026, 11, 3, 9));
      },
      overrides: overrides,
    );
    await openCalendar(tester);
    expect(find.text('Transferred on 11/3/2026'), findsOneWidget);

    await tester.runAsync(
      () => repo.write('project_entries', 'e1', {'duration_min': 130}),
    );
    await settle(tester);
    expect(
      find.text('Changed since the transfer on 11/3/2026'),
      findsOneWidget,
    );
  });
}
