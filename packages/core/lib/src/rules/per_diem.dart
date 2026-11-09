import '../model/planning.dart';
import '../time/home_time_zone.dart';
import '../time/local_date.dart';
import '../time/span.dart';
import 'bmf_rates.dart';

/// Per-diem category of a trip day (spec: calculations.md §13).
enum PerDiemCategory {
  /// No allowance.
  none,

  /// Partial-day rate: a day trip over 8 h, or an arrival/departure day.
  partial,

  /// Full-day rate: 24 h away.
  full,
}

/// Meal reductions in percent of the full-day rate (settings, §13).
final class MealReductions {
  /// Creates reductions; the defaults are the German rules.
  const MealReductions({
    this.breakfast = 20,
    this.lunch = 40,
    this.dinner = 40,
  });

  /// Reduction for a provided breakfast, in percent.
  final int breakfast;

  /// Reduction for a provided lunch, in percent.
  final int lunch;

  /// Reduction for a provided dinner, in percent.
  final int dinner;
}

/// The per-diem of one local date of a trip (spec: calculations.md §13).
final class PerDiemDay {
  /// Creates a day result. Use [perDiemForTrip] instead of calling this directly.
  const PerDiemDay({
    required this.date,
    required this.absenceMinutes,
    required this.category,
    required this.rateCents,
    required this.reductionCents,
    required this.rateMissing,
    this.place = const TripPlace('DE'),
  });

  /// The local date.
  final LocalDate date;

  /// Where the trip is on this date (§13.1).
  final TripPlace place;

  /// Minutes away from home on this date, `A(D)`.
  final int absenceMinutes;

  /// The allowance category.
  final PerDiemCategory category;

  /// Rate for the category before meal reductions, in cents.
  final int rateCents;

  /// Sum of meal reductions, in cents.
  final int reductionCents;

  /// No rate row exists for the trip's country on this date.
  final bool rateMissing;

  /// Amount after reductions, never below 0, in cents.
  int get amountCents {
    final amount = rateCents - reductionCents;
    return amount > 0 ? amount : 0;
  }
}

/// A country and an optional city (spec: calculations.md §13.0).
final class TripPlace {
  /// Creates a place.
  const TripPlace(this.country, [this.city]);

  /// ISO 3166-1 alpha-2 country code.
  final String country;

  /// City for a city rate, or `null`.
  final String? city;

  @override
  bool operator ==(Object other) =>
      other is TripPlace && other.country == country && other.city == city;

  @override
  int get hashCode => Object.hash(country, city);

  @override
  String toString() => city == null ? country : '$country/$city';
}

/// The place of [trip] on [date] (§13.1): the stop with the greatest date
/// on or before [date], else the trip's own destination.
TripPlace tripPlaceOn(Trip trip, List<TripStop> stops, LocalDate date) {
  TripStop? best;
  for (final s in stops) {
    if (s.tripId != trip.id || s.date.isAfter(date)) continue;
    if (best == null || s.date.isAfter(best.date)) best = s;
  }
  return best == null
      ? TripPlace(trip.country, trip.city)
      : TripPlace(best.country, best.city);
}

/// The local dates [trip] touches, first to last; empty while it is open.
List<LocalDate> tripDates(Trip trip, HomeTimeZone zone) {
  final returnAt = trip.returnAt;
  if (returnAt == null) return const [];
  final away = Span.fromInstants(trip.depart, returnAt);
  if (away.isEmpty) return const [];
  final last = zone.dateOfMinute(away.end - 1);
  return [
    for (
      var d = zone.dateOfMinute(away.start);
      !d.isAfter(last);
      d = d.addDays(1)
    )
      d,
  ];
}

/// The per-diem days of [trip] (spec: calculations.md §13). An open trip has
/// no per-diem yet and yields an empty list.
List<PerDiemDay> perDiemForTrip(
  Trip trip, {
  required HomeTimeZone zone,
  required List<PerDiemRate> rates,
  List<TripMeals> meals = const [],
  List<TripStop> stops = const [],
  MealReductions reductions = const MealReductions(),
}) {
  final returnAt = trip.returnAt;
  if (returnAt == null) return const [];
  final away = Span.fromInstants(trip.depart, returnAt);
  if (away.isEmpty) return const [];

  final first = zone.dateOfMinute(away.start);
  final last = zone.dateOfMinute(away.end - 1);
  final absence = <LocalDate, int>{
    for (var d = first; !d.isAfter(last); d = d.addDays(1))
      d: away.intersect(zone.daySpan(d))?.length ?? 0,
  };
  final categories = _categories(absence, first, last, trip.overnight);

  return [
    for (final MapEntry(key: date, value: minutes) in absence.entries)
      _priced(
        date,
        minutes,
        categories[date]!,
        tripPlaceOn(trip, stops, date),
        rates,
        meals.where((m) => m.tripId == trip.id && m.date == date),
        reductions,
      ),
  ];
}

Map<LocalDate, PerDiemCategory> _categories(
  Map<LocalDate, int> absence,
  LocalDate first,
  LocalDate last,
  bool overnight,
) {
  final total = absence.values.fold(0, (a, b) => a + b);
  if (first == last || !overnight) {
    // One day, or the "Mitternachtsregel": the whole duration counts on the
    // date with the most hours (ties go to the departure date).
    var best = first;
    for (final MapEntry(key: d, value: m) in absence.entries) {
      if (m > absence[best]!) best = d;
    }
    return {
      for (final d in absence.keys)
        d: d == best && total > 480
            ? PerDiemCategory.partial
            : PerDiemCategory.none,
    };
  }
  return {
    for (final d in absence.keys)
      d: d == first || d == last
          ? PerDiemCategory.partial
          : PerDiemCategory.full,
  };
}

/// The rate a trip day in [country] (and [city]) on [date] uses (spec:
/// calculations.md §13.0): the city's rows if there are any, else the
/// country's general ones; the greatest `valid_from ≤ date` wins, on a tie
/// the earlier row in [rates]. A country without any row uses the BMF
/// letter's alias or Luxembourg. [where] narrows the rows, e.g. to those
/// with a lodging rate.
PerDiemRate? perDiemRateOn(
  List<PerDiemRate> rates,
  String country,
  LocalDate date, {
  String? city,
  bool Function(PerDiemRate r)? where,
}) {
  var c = bmfRateAliases[country] ?? country;
  if (!rates.any((r) => r.country == c)) c = 'LU';
  final cityKey = city?.trim().toLowerCase();
  PerDiemRate? pick(bool Function(PerDiemRate r) matches) {
    PerDiemRate? best;
    for (final r in rates) {
      if (r.country != c || r.validFrom.isAfter(date) || !matches(r)) continue;
      if (where != null && !where(r)) continue;
      if (best == null || r.validFrom.isAfter(best.validFrom)) best = r;
    }
    return best;
  }

  if (cityKey != null && cityKey.isNotEmpty) {
    final forCity = pick((r) => r.city?.trim().toLowerCase() == cityKey);
    if (forCity != null) return forCity;
  }
  return pick((r) => r.city == null);
}

/// The lodging lump sum of a night at [place] on [date], in cents (§13.2);
/// `null` without a rate.
int? lodgingRateOn(List<PerDiemRate> rates, TripPlace place, LocalDate date) =>
    perDiemRateOn(
      rates,
      place.country,
      date,
      city: place.city,
      where: (r) => r.lodgingCents != null,
    )?.lodgingCents;

PerDiemDay _priced(
  LocalDate date,
  int minutes,
  PerDiemCategory category,
  TripPlace place,
  List<PerDiemRate> rates,
  Iterable<TripMeals> meals,
  MealReductions reductions,
) {
  final rate = perDiemRateOn(rates, place.country, date, city: place.city);
  final rateCents = switch (category) {
    PerDiemCategory.none => 0,
    PerDiemCategory.partial => rate?.partialCents ?? 0,
    PerDiemCategory.full => rate?.fullCents ?? 0,
  };
  var percent = 0;
  if (category != PerDiemCategory.none) {
    for (final m in meals) {
      if (m.breakfast) percent += reductions.breakfast;
      if (m.lunch) percent += reductions.lunch;
      if (m.dinner) percent += reductions.dinner;
    }
  }
  return PerDiemDay(
    date: date,
    absenceMinutes: minutes,
    category: category,
    rateCents: rateCents,
    reductionCents: ((rate?.fullCents ?? 0) * percent) ~/ 100,
    rateMissing: category != PerDiemCategory.none && rate == null,
    place: place,
  );
}
