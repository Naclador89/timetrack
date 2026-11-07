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

  /// Special leave (Sonderurlaub): credits the target.
  specialLeave,

  /// Taking overtime off (Überstundenabbau / Gleittag): no credit, so the
  /// day's target lowers the balance.
  compTime,

  /// Extra day off that works like a public holiday (e.g. 24 Dec): reduces
  /// the target.
  extraHoliday;

  /// The value used in sync changes and the database (`special_leave`, …).
  String get wireName => switch (this) {
    specialLeave => 'special_leave',
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
      this == vacation || this == sick || this == specialLeave;
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
  });

  /// Row id (UUIDv7).
  final String id;

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
