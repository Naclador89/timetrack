import '../model/planning.dart';
import '../time/home_time_zone.dart';
import '../time/local_date.dart';
import '../time/span.dart';

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
  });

  /// The local date.
  final LocalDate date;

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

/// The per-diem days of [trip] (spec: calculations.md §13). An open trip has
/// no per-diem yet and yields an empty list.
List<PerDiemDay> perDiemForTrip(
  Trip trip, {
  required HomeTimeZone zone,
  required List<PerDiemRate> rates,
  List<TripMeals> meals = const [],
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
        _rateOn(rates, trip.country, date),
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

PerDiemRate? _rateOn(List<PerDiemRate> rates, String country, LocalDate date) {
  PerDiemRate? best;
  for (final r in rates) {
    if (r.country != country || r.validFrom.isAfter(date)) continue;
    if (best == null || r.validFrom.isAfter(best.validFrom)) best = r;
  }
  return best;
}

PerDiemDay _priced(
  LocalDate date,
  int minutes,
  PerDiemCategory category,
  PerDiemRate? rate,
  Iterable<TripMeals> meals,
  MealReductions reductions,
) {
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
  );
}
