import '../time/local_date.dart';

/// The 16 German federal states (Bundesländer), named by their official
/// two-letter codes. Public holidays depend on the state (spec: calculations.md §6).
enum FederalState {
  /// Baden-Württemberg
  bw,

  /// Bayern
  by,

  /// Berlin
  be,

  /// Brandenburg
  bb,

  /// Bremen
  hb,

  /// Hamburg
  hh,

  /// Hessen
  he,

  /// Mecklenburg-Vorpommern
  mv,

  /// Niedersachsen
  ni,

  /// Nordrhein-Westfalen
  nw,

  /// Rheinland-Pfalz
  rp,

  /// Saarland
  sl,

  /// Sachsen
  sn,

  /// Sachsen-Anhalt
  st,

  /// Schleswig-Holstein
  sh,

  /// Thüringen
  th;

  /// The official code in upper case, e.g. `BY`.
  String get code => name.toUpperCase();

  /// Parses a state code such as `BY` or `by`.
  static FederalState parse(String code) => FederalState.values.firstWhere(
    (s) => s.name == code.toLowerCase(),
    orElse: () => throw ArgumentError.value(code, 'code', 'Unknown state'),
  );
}

/// A public holiday on [date], with its official German [name].
final class PublicHoliday {
  /// Creates a holiday.
  const PublicHoliday(this.date, this.name);

  /// The date of the holiday.
  final LocalDate date;

  /// The German name, e.g. `Tag der Deutschen Einheit`.
  final String name;

  @override
  bool operator ==(Object other) =>
      other is PublicHoliday && other.date == date && other.name == name;

  @override
  int get hashCode => Object.hash(date, name);

  @override
  String toString() => '$date $name';
}

/// Options for holidays that exist only in parts of a state.
final class HolidayOptions {
  /// Creates holiday options.
  const HolidayOptions({
    this.bavariaAssumptionDay = true,
    this.halfDayEves = true,
  });

  /// Whether Mariä Himmelfahrt (15 August) counts in Bavaria. It is a holiday
  /// only in the (mostly Catholic) municipalities, which are the large majority,
  /// hence the default `true`. Setting: `by_assumption_day`.
  final bool bavariaAssumptionDay;

  /// Whether Heiligabend (24 December) and Silvester (31 December) are half
  /// days: not public holidays, but many employers give the second half off
  /// (calculations.md §6.1). Setting: `half_day_eves`.
  final bool halfDayEves;
}

/// The earliest year the holiday rules are valid for (spec: calculations.md §6).
const int firstSupportedHolidayYear = 1995;

/// Easter Sunday of [year] in the Gregorian calendar.
///
/// Uses the anonymous Gregorian algorithm (Meeus/Jones/Butcher), which is exact
/// for every Gregorian year.
LocalDate easterSunday(int year) {
  final a = year % 19;
  final b = year ~/ 100;
  final c = year % 100;
  final d = b ~/ 4;
  final e = b % 4;
  final f = (b + 8) ~/ 25;
  final g = (b - f + 1) ~/ 3;
  final h = (19 * a + b - d - g + 15) % 30;
  final i = c ~/ 4;
  final k = c % 4;
  final l = (32 + 2 * e + 2 * i - h - k) % 7;
  final m = (a + 11 * h + 22 * l) ~/ 451;
  final month = (h + l - 7 * m + 114) ~/ 31;
  final day = (h + l - 7 * m + 114) % 31 + 1;
  return LocalDate(year, month, day);
}

/// All public holidays of [state] in [year], sorted by date
/// (spec: calculations.md §6).
///
/// Throws an [ArgumentError] for years before [firstSupportedHolidayYear].
List<PublicHoliday> publicHolidays(
  int year,
  FederalState state, {
  HolidayOptions options = const HolidayOptions(),
}) {
  if (year < firstSupportedHolidayYear) {
    throw ArgumentError.value(year, 'year', 'Holidays are supported from 1995');
  }
  final easter = easterSunday(year);
  bool isIn(Set<FederalState> states) => states.contains(state);

  final holidays = <PublicHoliday>[
    PublicHoliday(LocalDate(year, 1, 1), 'Neujahr'),
    if (isIn({FederalState.bw, FederalState.by, FederalState.st}))
      PublicHoliday(LocalDate(year, 1, 6), 'Heilige Drei Könige'),
    if ((state == FederalState.be && year >= 2019) ||
        (state == FederalState.mv && year >= 2023))
      PublicHoliday(LocalDate(year, 3, 8), 'Internationaler Frauentag'),
    PublicHoliday(easter.addDays(-2), 'Karfreitag'),
    if (state == FederalState.bb) PublicHoliday(easter, 'Ostersonntag'),
    PublicHoliday(easter.addDays(1), 'Ostermontag'),
    PublicHoliday(LocalDate(year, 5, 1), 'Tag der Arbeit'),
    if (state == FederalState.be && (year == 2020 || year == 2025))
      PublicHoliday(LocalDate(year, 5, 8), 'Tag der Befreiung'),
    PublicHoliday(easter.addDays(39), 'Christi Himmelfahrt'),
    if (state == FederalState.bb)
      PublicHoliday(easter.addDays(49), 'Pfingstsonntag'),
    PublicHoliday(easter.addDays(50), 'Pfingstmontag'),
    if (isIn(_corpusChristiStates))
      PublicHoliday(easter.addDays(60), 'Fronleichnam'),
    if (state == FederalState.sl ||
        (state == FederalState.by && options.bavariaAssumptionDay))
      PublicHoliday(LocalDate(year, 8, 15), 'Mariä Himmelfahrt'),
    if (state == FederalState.th && year >= 2019)
      PublicHoliday(LocalDate(year, 9, 20), 'Weltkindertag'),
    PublicHoliday(LocalDate(year, 10, 3), 'Tag der Deutschen Einheit'),
    if (isIn(_reformationStates(year)))
      PublicHoliday(LocalDate(year, 10, 31), 'Reformationstag'),
    if (isIn(_allSaintsStates))
      PublicHoliday(LocalDate(year, 11, 1), 'Allerheiligen'),
    if (state == FederalState.sn)
      PublicHoliday(_dayOfRepentance(year), 'Buß- und Bettag'),
    PublicHoliday(LocalDate(year, 12, 25), '1. Weihnachtstag'),
    PublicHoliday(LocalDate(year, 12, 26), '2. Weihnachtstag'),
  ];
  holidays.sort((a, b) => a.date.compareTo(b.date));
  return holidays;
}

const _corpusChristiStates = {
  FederalState.bw,
  FederalState.by,
  FederalState.he,
  FederalState.nw,
  FederalState.rp,
  FederalState.sl,
};

const _allSaintsStates = {
  FederalState.bw,
  FederalState.by,
  FederalState.nw,
  FederalState.rp,
  FederalState.sl,
};

Set<FederalState> _reformationStates(int year) {
  // 2017 (500 years of the Reformation) was a one-off holiday everywhere.
  if (year == 2017) return FederalState.values.toSet();
  return {
    FederalState.bb,
    FederalState.mv,
    FederalState.sn,
    FederalState.st,
    FederalState.th,
    if (year >= 2018) ...{
      FederalState.hb,
      FederalState.hh,
      FederalState.ni,
      FederalState.sh,
    },
  };
}

/// Buß- und Bettag: the Wednesday before 23 November.
LocalDate _dayOfRepentance(int year) {
  final nov22 = LocalDate(year, 11, 22);
  final daysBack = (nov22.weekday - DateTime.wednesday + 7) % 7;
  return nov22.addDays(-daysBack);
}

/// Fast holiday lookup for one state, with the holidays of each year computed
/// once and cached.
final class HolidayCalendar {
  /// Creates a calendar for [state].
  HolidayCalendar(this.state, {this.options = const HolidayOptions()});

  /// The federal state whose holidays apply.
  final FederalState state;

  /// Options for regional holidays.
  final HolidayOptions options;

  final Map<int, Map<LocalDate, PublicHoliday>> _byYear = {};

  /// The holiday on [date], or `null` if it's not a public holiday.
  PublicHoliday? holidayOn(LocalDate date) => _year(date.year)[date];

  /// Whether [date] is a public holiday.
  bool isHoliday(LocalDate date) => holidayOn(date) != null;

  /// Heiligabend or Silvester on [date] when they are half days
  /// ([HolidayOptions.halfDayEves], calculations.md §6.1), else `null`.
  PublicHoliday? halfDayOn(LocalDate date) {
    if (!options.halfDayEves || date.month != 12 || isHoliday(date)) {
      return null;
    }
    return switch (date.day) {
      24 => PublicHoliday(date, 'Heiligabend'),
      31 => PublicHoliday(date, 'Silvester'),
      _ => null,
    };
  }

  /// Whether [date] is a half day (calculations.md §6.1).
  bool isHalfDay(LocalDate date) => halfDayOn(date) != null;

  Map<LocalDate, PublicHoliday> _year(int year) => _byYear.putIfAbsent(
    year,
    () => {
      for (final h in publicHolidays(year, state, options: options)) h.date: h,
    },
  );
}
