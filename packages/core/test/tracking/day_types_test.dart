// spec: calculations.md §7, §8, §15; data-model.md §5, §12
import 'package:test/test.dart';
import 'package:timetrack_core/timetrack_core.dart';

const dev = 'aaaaaaaaaaaaaaaa';
final zone = HomeTimeZone();
final wed = LocalDate(2026, 11, 4);

void main() {
  late InMemorySyncStore store;
  late SyncedRepository repo;
  final now = DateTime.utc(2026, 11, 6, 12);

  setUp(() async {
    store = InMemorySyncStore();
    repo = await SyncedRepository.open(store, dev);
    await repo.write('work_schedules', 'w', {
      'valid_from': '2026-01-01',
      for (final d in ['mon', 'tue', 'wed', 'thu', 'fri']) 'minutes_$d': 480,
    });
  });

  Ledger ledger() => appLedger(store.allRows.values, now);
  Future<void> set(DayType t) => setDayType(repo, wed, t, zone: zone);
  Future<void> session(String from, String to, String location) =>
      repo.write('work_sessions', repo.newId(), {
        'start_utc': '2026-11-04T${from}Z',
        'end_utc': '2026-11-04T${to}Z',
        'location': location,
      });
  List<StoredRow> live(String table) =>
      store.rowsOf(table).values.where((r) => !r.isDeleted).toList();

  test('§15 derived: main location, else nothing', () async {
    expect(ledger().day(wed).type, isNull);
    await session('07:00:00', '10:00:00', 'home');
    await session('10:00:00', '12:00:00', 'office');
    expect(ledger().day(wed).type, DayType.home);
  });

  test('§15 office/home: stored per date, sessions follow', () async {
    await session('07:00:00', '15:00:00', 'office');
    await set(DayType.home);
    expect(ledger().day(wed).type, DayType.home);
    expect(live('work_sessions').single.fields['location'], 'home');
    expect(live('days').single.id, '2026-11-04');
    await set(DayType.office);
    expect(live('work_sessions').single.fields['location'], 'office');
  });

  test('§15 an absence type replaces the others; office removes it', () async {
    await set(DayType.home);
    await set(DayType.vacation);
    expect(ledger().day(wed).type, DayType.vacation);
    expect(live('days'), isEmpty);
    await set(DayType.sick);
    expect(live('absences').single.fields['kind'], 'sick');
    await set(DayType.office);
    expect(live('absences'), isEmpty);
    expect(ledger().day(wed).type, DayType.office);
  });

  test('§7/§8 child sick credits the target, short-time work lowers it, '
      'flexitime costs the balance', () async {
    Future<DayResult> as(DayType t) async {
      await set(t);
      return ledger().day(wed);
    }

    final child = await as(DayType.childSick);
    expect((child.target, child.credited, child.delta), (480, 480, 0));
    final kurz = await as(DayType.shortTime);
    expect((kurz.target, kurz.credited, kurz.delta), (0, 0, 0));
    final gleit = await as(DayType.flexTime);
    expect((gleit.target, gleit.credited, gleit.delta), (480, 0, -480));
    final feier = await as(DayType.specialLeave);
    expect((feier.target, feier.credited, feier.delta), (480, 480, 0));
  });

  test('§15 a trip day is a business trip unless absent all day', () async {
    await repo.write('trips', 't', {
      'depart_utc': '2026-11-04T05:00:00Z',
      'return_utc': '2026-11-04T18:00:00Z',
    });
    expect(ledger().day(wed).type, DayType.businessTrip);
    await set(DayType.sick);
    expect(ledger().day(wed).type, DayType.sick);
  });

  test('day type rules: what can be recorded', () {
    expect(DayType.home.allowsProjectTime, isTrue);
    expect(DayType.businessTrip.allowsProjectTime, isFalse);
    expect(DayType.businessTrip.locations, [
      WorkLocation.travel,
      WorkLocation.onSite,
    ]);
    expect(DayType.vacation.isWork, isFalse);
    for (final t in DayType.values) {
      expect(DayType.parse(t.wireName), t);
    }
  });
}
