import '../model/attendance.dart';
import '../model/planning.dart';
import '../time/local_date.dart';
import 'ledger.dart';
import 'per_diem.dart';

/// The employer's expense rules (spec: calculations.md §13.2–§13.5). Each is
/// a setting; only the mileage rate is a public default.
final class ExpenseRules {
  /// Creates rules.
  const ExpenseRules({
    this.mileageCentsPerKm = 30,
    this.siteAllowanceMinDays = 2,
    this.laundryAfterDays = 0,
    this.claimDeadlineMonths = 0,
  });

  /// Mileage for the own car, cents per km (`travel.mileage_cents_per_km`).
  final int mileageCentsPerKm;

  /// Site days in a row that start the allowance
  /// (`travel.site_allowance_min_days`).
  final int siteAllowanceMinDays;

  /// Laundry can be claimed on trips touching more dates than this; 0 = off
  /// (`travel.laundry_after_days`).
  final int laundryAfterDays;

  /// Months after the return to submit the claim; 0 = off
  /// (`travel.claim_deadline_months`).
  final int claimDeadlineMonths;
}

/// One night of a trip and its lump sum (§13.2).
typedef TripNight = ({LocalDate date, TripPlace place, int? flatCents});

/// One allowance day of a service trip and its rate (§13.4); `cents` is
/// `null` without a rate.
typedef AllowanceDay = ({LocalDate date, TripPlace place, int? cents});

/// What a finished trip can be claimed for (spec: calculations.md §13.5).
final class TripExpenses {
  /// Creates the summary. Use [tripExpenses].
  const TripExpenses({
    required this.trip,
    required this.perDiem,
    required this.nights,
    required this.lodgingCents,
    required this.mileageCents,
    required this.siteDays,
    required this.allowanceDays,
    required this.laundry,
    required this.deadline,
  });

  /// The trip.
  final Trip trip;

  /// The per-diem per date (§13).
  final List<PerDiemDay> perDiem;

  /// The nights (every date of an overnight trip but the last).
  final List<TripNight> nights;

  /// What the nights are claimed for, by [Trip.lodging].
  final int lodgingCents;

  /// Mileage for the own car (§13.3).
  final int mileageCents;

  /// Dates with on-site time on a service trip.
  final Set<LocalDate> siteDays;

  /// The dates the site allowance is paid for (§13.4).
  final List<AllowanceDay> allowanceDays;

  /// Whether laundry can be claimed.
  final bool laundry;

  /// The last day to submit the claim, or `null` when the rule is off.
  final LocalDate? deadline;

  /// Per-diem total after meal reductions.
  int get perDiemCents => perDiem.fold(0, (a, d) => a + d.amountCents);

  /// Per-diem, lodging and mileage: what the claim adds up to.
  int get claimCents => perDiemCents + lodgingCents + mileageCents;

  /// The site allowance, paid with the salary (not part of [claimCents]).
  int get siteAllowanceCents =>
      allowanceDays.fold(0, (a, d) => a + (d.cents ?? 0));

  /// Whether a per-diem, lodging or allowance rate is missing.
  bool get rateMissing =>
      perDiem.any((d) => d.rateMissing) ||
      (trip.lodging == LodgingMode.flat &&
          nights.any((n) => n.flatCents == null)) ||
      allowanceDays.any((d) => d.cents == null);
}

/// The expense summary of a finished [trip] (spec: calculations.md §13.5);
/// `null` while it is open.
TripExpenses? tripExpenses(
  Trip trip, {
  required Ledger ledger,
  required List<PerDiemRate> rates,
  List<TripMeals> meals = const [],
  List<TripStop> stops = const [],
  List<SiteAllowanceRate> siteRates = const [],
  ExpenseRules rules = const ExpenseRules(),
  MealReductions reductions = const MealReductions(),
}) {
  final dates = tripDates(trip, ledger.zone);
  if (dates.isEmpty) return null;
  TripPlace place(LocalDate d) => tripPlaceOn(trip, stops, d);

  final nights = <TripNight>[
    if (trip.overnight)
      for (final d in dates.take(dates.length - 1))
        (
          date: d,
          place: place(d),
          flatCents: lodgingRateOn(rates, place(d), d),
        ),
  ];
  final lodging = switch (trip.lodging) {
    LodgingMode.company => 0,
    LodgingMode.flat => nights.fold(0, (a, n) => a + (n.flatCents ?? 0)),
    LodgingMode.receipt => trip.lodgingCents,
  };

  final siteDays = {
    if (trip.service)
      for (final d in dates)
        if (ledger.day(d).work.workedAt(WorkLocation.onSite) > 0) d,
  };
  final allowance = <AllowanceDay>[];
  if (_longestRun(dates, siteDays) >= rules.siteAllowanceMinDays) {
    final first = dates.firstWhere(siteDays.contains);
    final last = dates.lastWhere(siteDays.contains);
    for (var d = first; !d.isAfter(last); d = d.addDays(1)) {
      allowance.add((
        date: d,
        place: place(d),
        cents: siteAllowanceOn(siteRates, place(d).country, d)?.cents,
      ));
    }
  }

  return TripExpenses(
    trip: trip,
    perDiem: perDiemForTrip(
      trip,
      zone: ledger.zone,
      rates: rates,
      meals: meals,
      stops: stops,
      reductions: reductions,
    ),
    nights: nights,
    lodgingCents: lodging,
    mileageCents: trip.carKm * rules.mileageCentsPerKm,
    siteDays: siteDays,
    allowanceDays: allowance,
    laundry:
        rules.laundryAfterDays > 0 && dates.length > rules.laundryAfterDays,
    deadline: rules.claimDeadlineMonths > 0
        ? addMonths(dates.last, rules.claimDeadlineMonths)
        : null,
  );
}

/// The site allowance rate for [country] on [date] (§13.4): the country's
/// rows, else those for `*`; the greatest `valid_from ≤ date` wins.
SiteAllowanceRate? siteAllowanceOn(
  List<SiteAllowanceRate> rates,
  String country,
  LocalDate date,
) {
  SiteAllowanceRate? pick(String c) {
    SiteAllowanceRate? best;
    for (final r in rates) {
      if (r.country != c || r.validFrom.isAfter(date)) continue;
      if (best == null || r.validFrom.isAfter(best.validFrom)) best = r;
    }
    return best;
  }

  return pick(country) ?? pick('*');
}

/// [date] plus [months], on the same day of month or the month's last day.
LocalDate addMonths(LocalDate date, int months) {
  final index = date.year * 12 + date.month - 1 + months;
  final year = index ~/ 12;
  final month = index % 12 + 1;
  final last =
      (month == 12 ? LocalDate(year + 1, 1, 1) : LocalDate(year, month + 1, 1))
          .addDays(-1)
          .day;
  return LocalDate(year, month, date.day < last ? date.day : last);
}

/// A finished trip whose claim is still to be submitted (§13.5).
typedef ClaimDue = ({Trip trip, LocalDate deadline, bool urgent});

/// The trips to claim on [today] (§13.5): finished, not claimed, deadline
/// not passed; `urgent` in the last 14 days. Soonest deadline first.
List<ClaimDue> claimsDue(
  List<Trip> trips, {
  required Ledger ledger,
  required ExpenseRules rules,
}) {
  if (rules.claimDeadlineMonths <= 0) return const [];
  final today = ledger.today;
  final due = <ClaimDue>[];
  for (final t in trips) {
    if (t.claimedOn != null) continue;
    final dates = tripDates(t, ledger.zone);
    if (dates.isEmpty || !dates.last.isBefore(today.addDays(1))) continue;
    final deadline = addMonths(dates.last, rules.claimDeadlineMonths);
    if (today.isAfter(deadline)) continue;
    due.add((
      trip: t,
      deadline: deadline,
      urgent: !today.addDays(14).isBefore(deadline),
    ));
  }
  return due..sort((a, b) => a.deadline.compareTo(b.deadline));
}

int _longestRun(List<LocalDate> dates, Set<LocalDate> days) {
  var best = 0, run = 0;
  for (final d in dates) {
    run = days.contains(d) ? run + 1 : 0;
    if (run > best) best = run;
  }
  return best;
}
