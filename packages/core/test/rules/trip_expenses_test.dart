// spec: calculations.md §13.0–§13.5
import 'package:test/test.dart';
import 'package:timetrack_core/timetrack_core.dart';

const dev = 'aaaaaaaaaaaaaaaa';
final rates = defaultPerDiemRates();
LocalDate d(String iso) => LocalDate.parse(iso);

void main() {
  group('§13.0 built-in rates', () {
    test('a city has its own rate, other places the country\'s', () {
      final date = d('2026-11-04');
      expect(perDiemRateOn(rates, 'FR', date, city: 'Paris')!.fullCents, 5800);
      expect(perDiemRateOn(rates, 'FR', date, city: 'paris ')!.fullCents, 5800);
      expect(perDiemRateOn(rates, 'FR', date, city: 'Lyon')!.fullCents, 5300);
      expect(perDiemRateOn(rates, 'FR', date)!.lodgingCents, 10500);
      expect(
        perDiemRateOn(rates, 'US', date, city: 'Boston')!.lodgingCents,
        33300,
      );
    });

    test('Germany: 14/28 € and 20 € lodging', () {
      final de = perDiemRateOn(rates, 'DE', d('2026-11-04'))!;
      expect(
        (de.partialCents, de.fullCents, de.lodgingCents),
        (1400, 2800, 2000),
      );
    });

    test('aliases and the Luxembourg rate for unlisted countries', () {
      final date = d('2026-11-04');
      expect(perDiemRateOn(rates, 'GD', date)!.country, 'TT');
      expect(perDiemRateOn(rates, 'FM', date)!.country, 'PH');
      final iraq = perDiemRateOn(rates, 'IQ', date)!;
      expect(
        (iraq.country, iraq.fullCents, iraq.partialCents),
        ('LU', 6300, 4200),
      );
    });

    test('the table has every country with ISO codes', () {
      expect(bmfCountryNames.length, 167);
      expect(bmfCountryNames['GB'], startsWith('Vereinigtes Königreich'));
      expect(bmfRates2026.length, 214);
    });

    test('a user row keeps the built-in lodging rate if it has none', () {
      final own = [
        PerDiemRate(
          id: 'mine',
          country: 'AT',
          validFrom: d('2026-06-01'),
          partialCents: 3500,
          fullCents: 5200,
        ),
        ...rates,
      ];
      const at = TripPlace('AT');
      expect(perDiemRateOn(own, 'AT', d('2026-11-04'))!.id, 'mine');
      expect(lodgingRateOn(own, at, d('2026-11-04')), 11700);
    });
  });

  group('trips', () {
    late InMemorySyncStore store;
    late SyncedRepository repo;

    setUp(() async {
      store = InMemorySyncStore();
      repo = await SyncedRepository.open(store, dev);
      await saveSetting(repo, SettingKeys.federalState, 'NW');
    });

    Ledger ledger() =>
        appLedger(store.allRows.values, DateTime.utc(2026, 12, 1, 12));
    Future<void> trip(Map<String, Object?> fields) => repo.write('trips', 't', {
      'depart_utc': '2026-11-02T05:00:00Z',
      'return_utc': '2026-11-06T17:00:00Z',
      'country': 'FR',
      ...fields,
    });
    Future<void> onSite(String date) =>
        repo.write('work_sessions', 'site-$date', {
          'start_utc': '${date}T08:00:00Z',
          'end_utc': '${date}T15:00:00Z',
          'location': 'on_site',
        });
    TripExpenses expenses() {
      final l = ledger();
      return tripExpenses(
        l.data.trips.single,
        ledger: l,
        rates: rates,
        stops: l.data.tripStops,
        siteRates: l.data.siteAllowances,
        rules: l.settings.expenses,
      )!;
    }

    test('§13.1 a stop changes the place from its date on', () async {
      await trip({'city': 'Paris'});
      await repo.write('trip_stops', 's', {
        'trip_id': 't',
        'date': '2026-11-04',
        'country': 'BE',
      });
      final e = expenses();
      expect(e.perDiem.map((p) => p.place.toString()), [
        'FR/Paris',
        'FR/Paris',
        'BE',
        'BE',
        'BE',
      ]);
      // Paris partial 39, full 58, Belgium full 59 ×2, partial 40.
      expect(e.perDiemCents, 3900 + 5800 + 5900 + 5900 + 4000);
    });

    test('§13.2 lodging: company, lump sum per night, receipts', () async {
      await trip({'city': 'Paris'});
      expect(expenses().nights, hasLength(4));
      expect(expenses().lodgingCents, 0);
      await trip({'city': 'Paris', 'lodging': 'flat'});
      expect(expenses().lodgingCents, 4 * 15900);
      await trip({'lodging': 'receipt', 'lodging_cents': 51234});
      expect(expenses().lodgingCents, 51234);
      await trip({'overnight': false});
      expect(expenses().nights, isEmpty);
    });

    test('§13.3 mileage: km × 30 ct by default', () async {
      await trip({'car_km': 412});
      expect(expenses().mileageCents, 12360);
      await saveSetting(repo, SettingKeys.mileageCentsPerKm, 38);
      expect(expenses().mileageCents, 412 * 38);
    });

    test('§13.4 site allowance from the first to the last site day', () async {
      await trip({});
      await repo.write('site_allowances', 'fr', {
        'country': 'FR',
        'valid_from': '2026-01-01',
        'cents': 2000,
      });
      await repo.write('site_allowances', 'all', {
        'country': '*',
        'valid_from': '2026-01-01',
        'cents': 4000,
      });
      // Tue and Wed on site, Thu travel only, Fri on site.
      await onSite('2026-11-03');
      await onSite('2026-11-04');
      await onSite('2026-11-06');
      final e = expenses();
      expect(e.siteDays, {d('2026-11-03'), d('2026-11-04'), d('2026-11-06')});
      expect(e.allowanceDays.map((a) => a.date), [
        d('2026-11-03'),
        d('2026-11-04'),
        d('2026-11-05'),
        d('2026-11-06'),
      ]);
      expect(e.siteAllowanceCents, 4 * 2000);
      expect(e.claimCents, e.perDiemCents, reason: 'paid with the salary');
      final sheet = buildTimesheet(ledger(), 2026, 11);
      expect((sheet.siteAllowanceDays, sheet.siteAllowanceCents), (4, 8000));
    });

    test('§13.4 no two site days in a row, or no service trip: none', () async {
      await trip({});
      await onSite('2026-11-03');
      await onSite('2026-11-05');
      expect(expenses().allowanceDays, isEmpty);
      await onSite('2026-11-04');
      expect(expenses().allowanceDays, hasLength(3));
      expect(expenses().rateMissing, isTrue, reason: 'no rate entered');
      await trip({'service': false});
      expect(expenses().siteDays, isEmpty);
    });

    test('§13.5 laundry and the claim deadline', () async {
      await trip({});
      expect(expenses().laundry, isFalse);
      expect(expenses().deadline, isNull);
      await saveSetting(repo, SettingKeys.laundryAfterDays, 5);
      await saveSetting(repo, SettingKeys.claimDeadlineMonths, 3);
      expect(expenses().laundry, isFalse, reason: '5 dates, not more');
      expect(expenses().deadline, d('2027-02-06'));
      await trip({'return_utc': '2026-11-07T10:00:00Z'});
      expect(expenses().laundry, isTrue);
    });

    test('§13.5 claims due until claimed or past the deadline', () async {
      await saveSetting(repo, SettingKeys.claimDeadlineMonths, 1);
      await trip({});
      final l = ledger();
      final due = claimsDue(
        l.data.trips,
        ledger: l,
        rules: l.settings.expenses,
      );
      expect(due.single.deadline, d('2026-12-06'));
      expect(due.single.urgent, isTrue, reason: '5 days left on 1 Dec');
      await trip({'claimed_on': '2026-11-20'});
      final l2 = ledger();
      expect(
        claimsDue(l2.data.trips, ledger: l2, rules: l2.settings.expenses),
        isEmpty,
      );
    });

    test('addMonths keeps the day or takes the month\'s last', () {
      expect(addMonths(d('2026-11-30'), 3), d('2027-02-28'));
      expect(addMonths(d('2026-10-15'), 3), d('2027-01-15'));
    });
  });
}
