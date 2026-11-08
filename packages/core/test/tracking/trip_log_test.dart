// spec: calculations.md §9.1
import 'package:test/test.dart';
import 'package:timetrack_core/timetrack_core.dart';

const dev = 'aaaaaaaaaaaaaaaa';

void main() {
  late InMemorySyncStore store;
  late SyncedRepository repo;
  final now = DateTime.utc(2026, 11, 10, 12);

  setUp(() async {
    store = InMemorySyncStore();
    repo = await SyncedRepository.open(store, dev);
    await repo.write('work_schedules', 'w', {
      'valid_from': '2026-01-01',
      for (final d in ['mon', 'tue', 'wed', 'thu', 'fri']) 'minutes_$d': 480,
    });
  });

  Ledger ledger() => appLedger(store.allRows.values, now);
  Future<void> leg(String date, String from, String to, String loc) =>
      repo.write('work_sessions', repo.newId(), {
        'start_utc': '${date}T$from:00Z',
        'end_utc': '${date}T$to:00Z',
        'location': loc,
      });
  List<(TripLegKind, int)> legs(LocalDate d) => [
    for (final l in tripLegs(ledger(), d)) (l.kind, l.span.length),
  ];

  test('§9.1 a day trip: outbound, on site, inbound with exact times; '
      'the account still gets the target', () async {
    await repo.write('trips', 't', {
      'depart_utc': '2026-11-04T05:00:00Z',
      'return_utc': '2026-11-04T19:00:00Z',
    });
    await leg('2026-11-04', '05:00', '08:15', 'travel');
    await leg('2026-11-04', '08:30', '16:00', 'on_site');
    await leg('2026-11-04', '16:00', '19:00', 'travel');
    final wed = LocalDate(2026, 11, 4);
    expect(
      legs(wed).join(),
      [
        (TripLegKind.outbound, 195),
        (TripLegKind.onSite, 450),
        (TripLegKind.inbound, 180),
      ].join(),
    );
    final day = ledger().day(wed);
    expect((day.work.worked, day.credited), (825, 480));
  });

  test(
    '§9.1 days without on-site time: first day out, last day back',
    () async {
      await repo.write('trips', 't', {
        'depart_utc': '2026-11-04T15:00:00Z',
        'return_utc': '2026-11-06T18:00:00Z',
      });
      await leg('2026-11-04', '15:00', '19:00', 'travel');
      await leg('2026-11-05', '08:00', '17:00', 'on_site');
      await leg('2026-11-06', '14:00', '18:00', 'travel');
      expect(legs(LocalDate(2026, 11, 4)).single.$1, TripLegKind.outbound);
      expect(legs(LocalDate(2026, 11, 6)).single.$1, TripLegKind.inbound);
      expect(legs(LocalDate(2026, 11, 3)), isEmpty, reason: 'no trip day');
    },
  );

  test('§9.1 steps follow the state of the trip day', () {
    expect(
      tripSteps(running: null, onSiteToday: false).first,
      TripStep.startOutbound,
    );
    expect(
      tripSteps(running: WorkLocation.travel, onSiteToday: false).first,
      TripStep.arriveOnSite,
    );
    expect(
      tripSteps(running: WorkLocation.onSite, onSiteToday: true).first,
      TripStep.startInbound,
    );
    expect(tripSteps(running: WorkLocation.travel, onSiteToday: true), [
      TripStep.endInbound,
    ]);
  });
}
