// spec: calculations.md §13
import 'package:test/test.dart';
import 'package:timetrack_core/timetrack_core.dart';

final berlin = HomeTimeZone();
LocalDate d(String iso) => LocalDate.parse(iso);

DateTime at(String date, String hhmm) {
  final p = hhmm.split(':');
  return instantOfEpochMinute(
    berlin.daySpan(d(date)).start + int.parse(p[0]) * 60 + int.parse(p[1]),
  );
}

final rates = [
  ...defaultPerDiemRates(),
  PerDiemRate(
    id: 'at',
    country: 'AT',
    validFrom: d('2024-01-01'),
    partialCents: 2000,
    fullCents: 3000,
  ),
  PerDiemRate(
    id: 'at2',
    country: 'AT',
    validFrom: d('2026-12-01'),
    partialCents: 2200,
    fullCents: 3300,
  ),
];

List<PerDiemDay> perDiem(Trip trip, {List<TripMeals> meals = const []}) =>
    perDiemForTrip(trip, zone: berlin, rates: rates, meals: meals);

Trip trip(
  String from,
  String fromTime,
  String to,
  String toTime, {
  bool overnight = true,
  String country = 'DE',
}) => Trip(
  id: 't',
  depart: at(from, fromTime),
  returnAt: at(to, toTime),
  overnight: overnight,
  country: country,
);

void main() {
  test('§13 day trip: 7:59 h → nothing, 8:01 h → partial rate', () {
    expect(
      perDiem(trip('2026-11-04', '08:00', '2026-11-04', '15:59'))
          .single
          .category,
      PerDiemCategory.none,
    );
    final day = perDiem(trip('2026-11-04', '08:00', '2026-11-04', '16:01'))
        .single;
    expect(
      (day.category, day.absenceMinutes, day.amountCents),
      (PerDiemCategory.partial, 481, 1400),
    );
  });

  test('§13 multi-day trip with overnight stays: partial, full, partial', () {
    final days = perDiem(trip('2026-11-02', '06:00', '2026-11-04', '20:00'));
    expect(
      [for (final x in days) x.category],
      [PerDiemCategory.partial, PerDiemCategory.full, PerDiemCategory.partial],
    );
    expect(days.fold(0, (sum, x) => sum + x.amountCents), 1400 + 2800 + 1400);
    expect(days[1].absenceMinutes, 1440);
  });

  test('§13 day trip over midnight without overnight stay counts on the day with more hours', () {
    // 18:00–03:00: 6 h Monday, 3 h Tuesday, 9 h in total → Monday partial.
    final days = perDiem(
      trip('2026-11-02', '18:00', '2026-11-03', '03:00', overnight: false),
    );
    expect(
      [for (final x in days) x.category],
      [PerDiemCategory.partial, PerDiemCategory.none],
    );
    // 19:30–04:30: a tie → the departure date.
    final tie = perDiem(
      trip('2026-11-02', '19:30', '2026-11-03', '04:30', overnight: false),
    );
    expect(tie.first.category, PerDiemCategory.partial);
    // 20:00–04:00 is exactly 8 h: not more than 8 h → nothing.
    final short = perDiem(
      trip('2026-11-02', '20:00', '2026-11-03', '04:00', overnight: false),
    );
    expect(short.every((x) => x.category == PerDiemCategory.none), isTrue);
  });

  test('§13 provided meals reduce by 20/40/40 % of the full-day rate, never below 0', () {
    final days = perDiem(
      trip('2026-11-02', '06:00', '2026-11-04', '20:00'),
      meals: [
        TripMeals(
          id: 'm1',
          tripId: 't',
          date: d('2026-11-03'),
          breakfast: true,
        ),
        TripMeals(
          id: 'm2',
          tripId: 't',
          date: d('2026-11-04'),
          breakfast: true,
          lunch: true,
        ),
        TripMeals(
          id: 'other',
          tripId: 'x',
          date: d('2026-11-02'),
          dinner: true,
        ),
      ],
    );
    expect([for (final x in days) x.amountCents], [1400, 2800 - 560, 0]);
  });

  test(
    '§13 foreign rates by country and validity; missing rates are flagged',
    () {
      expect(
        perDiem(
          trip('2025-11-04', '06:00', '2025-11-04', '20:00', country: 'AT'),
        ).single.amountCents,
        2000,
      );
      // §13.0: the built-in BMF rate from 2026 supersedes the 2024 row.
      expect(
        perDiem(
          trip('2026-11-04', '06:00', '2026-11-04', '20:00', country: 'AT'),
        ).single.amountCents,
        3300,
      );
      expect(
        perDiem(
          trip('2026-12-02', '06:00', '2026-12-02', '20:00', country: 'AT'),
        ).single.amountCents,
        2200,
      );
      // No foreign rates are built in before 2026.
      final unknown = perDiem(
        trip('2025-11-04', '06:00', '2025-11-04', '20:00', country: 'FR'),
      ).single;
      expect((unknown.amountCents, unknown.rateMissing), (0, true));
    },
  );

  test('§13 an open trip has no per-diem yet', () {
    expect(
      perDiemForTrip(
        Trip(id: 'o', depart: at('2026-11-04', '06:00')),
        zone: berlin,
        rates: rates,
      ),
      isEmpty,
    );
  });

  test('§13 a user rate supersedes from its valid_from; on a tie the earlier row wins', () {
    PerDiemRate rate(String id, String from, int partial) => PerDiemRate(
      id: id,
      country: 'DE',
      validFrom: d(from),
      partialCents: partial,
      fullCents: partial * 2,
    );
    final own = [
      rate('mine', '2026-01-01', 1600),
      rate('same', '2026-01-01', 1700),
    ];
    final all = [...own, ...defaultPerDiemRates()];
    expect(perDiemRateOn(all, 'DE', d('2025-12-31'))!.id, 'default-de-2020');
    expect(perDiemRateOn(all, 'DE', d('2026-01-01'))!.id, 'mine');
    expect(perDiemRateOn(all, 'AT', d('2026-01-01'))!.id, 'bmf-2026-AT');
    expect(perDiemRateOn(all, 'AT', d('2025-12-31')), isNull);
  });
}
