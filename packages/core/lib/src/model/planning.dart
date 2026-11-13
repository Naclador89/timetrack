import '../rules/bmf_rates.dart';
import '../time/local_date.dart';

/// A work schedule (contract), valid from [validFrom] until the next one
/// (spec: calculations.md §7).
final class WorkSchedule {
  /// Creates a schedule. [weekdayMinutes] has 7 entries, Monday first.
  WorkSchedule({
    required this.id,
    required this.validFrom,
    required List<int> weekdayMinutes,
    this.annualVacationDays = 0,
  }) : weekdayMinutes = List.unmodifiable(weekdayMinutes) {
    if (weekdayMinutes.length != 7) {
      throw ArgumentError.value(weekdayMinutes, 'weekdayMinutes', 'Need 7');
    }
  }

  /// Row id (UUIDv7).
  final String id;

  /// First day this schedule applies to.
  final LocalDate validFrom;

  /// Target minutes per weekday, index 0 = Monday … 6 = Sunday.
  final List<int> weekdayMinutes;

  /// Vacation days per calendar year (§10). Half days are allowed.
  final double annualVacationDays;

  /// Target minutes for [date]'s weekday, ignoring holidays.
  int minutesOn(LocalDate date) => weekdayMinutes[date.weekday - 1];
}

/// Kinds of absence (spec: calculations.md §7, §8).
enum AbsenceKind {
  /// Paid vacation: credits the target, counts against the vacation account.
  vacation,

  /// Sick day: credits the target.
  sick,

  /// Special leave (Sonderurlaub; in the app "Feier-/Trauertag"): credits
  /// the target.
  specialLeave,

  /// Child sick day (Kinderkrankentag): credits the target like [sick].
  childSick,

  /// Short-time work (Kurzarbeit): reduces the target, like [extraHoliday].
  shortTime,

  /// Taking overtime off (Überstundenabbau / Gleittag): no credit, so the
  /// day's target lowers the balance.
  compTime,

  /// Extra day off that works like a public holiday (e.g. 24 Dec): reduces
  /// the target.
  extraHoliday;

  /// The value used in sync changes and the database (`special_leave`, …).
  String get wireName => switch (this) {
    specialLeave => 'special_leave',
    childSick => 'child_sick',
    shortTime => 'short_time',
    compTime => 'comp_time',
    extraHoliday => 'extra_holiday',
    _ => name,
  };

  /// Parses a [wireName].
  static AbsenceKind parse(String wireName) => AbsenceKind.values.firstWhere(
    (k) => k.wireName == wireName,
    orElse: () =>
        throw ArgumentError.value(wireName, 'wireName', 'Unknown absence'),
  );

  /// Whether this absence adds `fraction × target` to the credited time.
  bool get creditsTarget =>
      this == vacation ||
      this == sick ||
      this == specialLeave ||
      this == childSick;

  /// Whether this absence lowers the target `T(D)` (§7) instead.
  bool get reducesTarget => this == extraHoliday || this == shortTime;
}

/// A full-day or half-day absence on [date].
final class Absence {
  /// Creates an absence. [fraction] is 1 (full day) or 0.5 (half day).
  const Absence({
    required this.id,
    required this.date,
    required this.kind,
    this.fraction = 1,
  });

  /// Row id (UUIDv7).
  final String id;

  /// The day of the absence.
  final LocalDate date;

  /// What kind of absence it is.
  final AbsenceKind kind;

  /// Share of the day: 1 or 0.5.
  final double fraction;
}

/// A business trip from [depart] to [returnAt] (spec: calculations.md §9, §13).
final class Trip {
  /// Creates a trip. [returnAt] is `null` while still travelling.
  const Trip({
    required this.id,
    required this.depart,
    this.returnAt,
    this.destination = '',
    this.country = 'DE',
    this.overnight = true,
    this.service = true,
    this.projectId,
    this.city,
    this.lodging = LodgingMode.company,
    this.lodgingCents = 0,
    this.carKm = 0,
    this.claimedOn,
    this.orderKind,
    this.orderNumber = '',
    this.note = '',
  });

  /// Row id (UUIDv7).
  final String id;

  /// What kind of order the trip is billed through, or `null`.
  final TripOrderKind? orderKind;

  /// The order number the trip is billed through, e.g. `4711`. Empty if none.
  final String orderNumber;

  /// Free-text notes on the trip.
  final String note;

  /// The order as shown in lists and reports, e.g. `MO 4711`; empty without
  /// an order number.
  String get orderLabel =>
      orderNumber.isEmpty ? '' : [?orderKind?.code, orderNumber].join(' ');

  /// City of the destination for a city rate (calculations.md §13.0), or
  /// `null` for the country's general rate.
  final String? city;

  /// How the nights are claimed (§13.2).
  final LodgingMode lodging;

  /// Receipts total for [LodgingMode.receipt], in cents.
  final int lodgingCents;

  /// Kilometres driven with the own car (§13.3).
  final int carKm;

  /// The day the expense claim was submitted, or `null` (§13.5).
  final LocalDate? claimedOn;

  /// Whether this is a service trip: service, installation or commissioning
  /// work on a site, paid with a flat supplement (calculations.md §9).
  final bool service;

  /// The project the trip is for, if any (shown in the travel report).
  final String? projectId;

  /// Departure instant (UTC).
  final DateTime depart;

  /// Return instant (UTC), or `null` while the trip is open.
  final DateTime? returnAt;

  /// Free-text destination, e.g. `Stuttgart`.
  final String destination;

  /// ISO 3166-1 alpha-2 country code of the destination; picks the per-diem rate.
  final String country;

  /// Whether the trip includes an overnight stay (§13 "Mitternachtsregel").
  final bool overnight;
}

/// The kind of order a trip is billed through (data-model.md §9).
enum TripOrderKind {
  /// Montageauftrag (MO): installation.
  installation('mo'),

  /// Gewährleistungsauftrag (GA): warranty work.
  warranty('ga'),

  /// Serviceauftrag (SA): service.
  service('sa');

  const TripOrderKind(this.wire);

  /// The stored value.
  final String wire;

  /// The short code on the order, e.g. `MO`.
  String get code => wire.toUpperCase();
}

/// How the nights of a trip are claimed (spec: calculations.md §13.2).
enum LodgingMode {
  /// Booked and paid by the employer: nothing to claim (default).
  company,

  /// The lodging lump sum of each night's place.
  flat,

  /// The receipts, as a total.
  receipt,
}

/// The place of a trip from [date] on (spec: calculations.md §13.1).
final class TripStop {
  /// Creates a stop.
  const TripStop({
    required this.id,
    required this.tripId,
    required this.date,
    required this.country,
    this.city,
  });

  /// Row id (UUIDv7).
  final String id;

  /// The trip.
  final String tripId;

  /// First day at this place.
  final LocalDate date;

  /// ISO 3166-1 alpha-2 country code.
  final String country;

  /// City for a city rate, or `null`.
  final String? city;
}

/// The employer's site allowance per day in a country (spec:
/// calculations.md §13.4).
final class SiteAllowanceRate {
  /// Creates a rate row.
  const SiteAllowanceRate({
    required this.id,
    required this.country,
    required this.validFrom,
    required this.cents,
  });

  /// Row id (UUIDv7).
  final String id;

  /// ISO 3166-1 alpha-2 country code, or `*` for every other country.
  final String country;

  /// First day the rate applies to.
  final LocalDate validFrom;

  /// Amount per allowance day, in cents.
  final int cents;
}

/// Length of a home-office quota period (spec: calculations.md §11.2).
enum QuotaPeriod {
  /// ISO week, Monday–Sunday.
  week,

  /// Calendar month.
  month,
}

/// What a home-office quota counts.
enum QuotaUnit {
  /// Home-office days (by the day rule, §11.1).
  days,

  /// Hours worked at home.
  hours,
}

/// What a home-office percentage refers to.
enum QuotaBasis {
  /// Days actually worked so far in the period (default).
  worked,

  /// Scheduled workdays of the whole period, minus absences.
  scheduled,
}

/// One version of a home-office quota rule (spec: calculations.md §11.2).
///
/// Rows with the same [period] and [unit] are versions of one rule; the
/// version valid on the first day of a period applies to the whole period.
final class HomeOfficeRule {
  /// Creates a rule version.
  const HomeOfficeRule({
    required this.id,
    required this.validFrom,
    required this.period,
    this.unit = QuotaUnit.days,
    required this.maxPercent,
    this.basis = QuotaBasis.worked,
  });

  /// Row id (UUIDv7).
  final String id;

  /// First day this version applies to.
  final LocalDate validFrom;

  /// Week or month.
  final QuotaPeriod period;

  /// Days or hours.
  final QuotaUnit unit;

  /// Allowed home-office share in percent, e.g. 40.
  final int maxPercent;

  /// What the percentage refers to.
  final QuotaBasis basis;
}

/// Per-diem rates for one country, valid from [validFrom]
/// (spec: calculations.md §13). Amounts are integer cents.
final class PerDiemRate {
  /// Creates a rate row.
  const PerDiemRate({
    required this.id,
    required this.country,
    required this.validFrom,
    required this.partialCents,
    required this.fullCents,
    this.city,
    this.lodgingCents,
  });

  /// Row id (UUIDv7).
  final String id;

  /// ISO 3166-1 alpha-2 country code.
  final String country;

  /// The city the rate is for, or `null` for the whole country (the rest of
  /// it, where cities have their own rate).
  final String? city;

  /// Lodging lump sum per night (§13.2), or `null` to keep the built-in one.
  final int? lodgingCents;

  /// First day the rates apply to.
  final LocalDate validFrom;

  /// Rate for a partial day (more than 8 h, or arrival/departure day).
  final int partialCents;

  /// Rate for a full 24-hour day; also the base for meal reductions.
  final int fullCents;
}

/// The built-in rates (spec: calculations.md §13.0): Germany and the BMF
/// table from 2026.
List<PerDiemRate> defaultPerDiemRates() => _defaults;

final _defaults = List<PerDiemRate>.unmodifiable([
  PerDiemRate(
    id: 'default-de-2020',
    country: 'DE',
    validFrom: LocalDate(2020, 1, 1),
    partialCents: 1400,
    fullCents: 2800,
    lodgingCents: 2000,
  ),
  for (final (country, city, full, partial, lodging) in bmfRates2026)
    PerDiemRate(
      id: 'bmf-2026-$country${city == null ? '' : '-$city'}',
      country: country,
      city: city,
      validFrom: LocalDate(2026, 1, 1),
      partialCents: partial * 100,
      fullCents: full * 100,
      lodgingCents: lodging * 100,
    ),
]);

/// Meals provided on one trip day; each reduces the per-diem (§13).
final class TripMeals {
  /// Creates a meals row.
  const TripMeals({
    required this.id,
    required this.tripId,
    required this.date,
    this.breakfast = false,
    this.lunch = false,
    this.dinner = false,
  });

  /// Row id (UUIDv7).
  final String id;

  /// The trip these meals belong to.
  final String tripId;

  /// The day of the meals.
  final LocalDate date;

  /// Breakfast was provided (e.g. included in the hotel price).
  final bool breakfast;

  /// Lunch was provided.
  final bool lunch;

  /// Dinner was provided.
  final bool dinner;
}
