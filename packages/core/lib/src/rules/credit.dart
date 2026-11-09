import '../model/planning.dart';
import '../time/local_date.dart';
import 'holidays.dart' as holidays;

/// Day types for the travel rules (spec: calculations.md §9).
enum TripDayType {
  /// Monday–Friday with a target.
  workday,

  /// Saturday.
  saturday,

  /// Sunday.
  sunday,

  /// Public holiday (any weekday).
  holiday,

  /// Monday–Friday without a target, e.g. a part-time day off.
  dayOff,
}

/// How a trip Sunday is counted.
enum TripSundayCredit {
  /// Travel and work together count as **Sunday hours** for HR (extra pay),
  /// at most [TravelRules.sundayCapMinutes]; nothing is credited to the
  /// overtime balance (default, user decision 2026-11-07).
  sundayHours,

  /// Work at the destination is credited, travel counts 0.
  workOnly,
}

/// A holiday whose Sunday hours are reported separately (spec:
/// calculations.md §21.1), e.g. for a higher supplement.
enum SpecialDay {
  /// 1 January.
  newYear('new_year'),

  /// Easter Sunday.
  easterSunday('easter_sunday'),

  /// Easter Monday.
  easterMonday('easter_monday'),

  /// 1 May.
  mayDay('may_day'),

  /// Whit Sunday.
  whitSunday('whit_sunday'),

  /// Whit Monday.
  whitMonday('whit_monday'),

  /// 25 December.
  christmasDay('christmas_day'),

  /// 26 December.
  boxingDay('boxing_day');

  const SpecialDay(this.code);

  /// The code in the setting `supplement.special_days`.
  final String code;

  /// The date of this day in [year].
  LocalDate inYear(int year) => switch (this) {
    newYear => LocalDate(year, 1, 1),
    easterSunday => holidays.easterSunday(year),
    easterMonday => holidays.easterSunday(year).addDays(1),
    mayDay => LocalDate(year, 5, 1),
    whitSunday => holidays.easterSunday(year).addDays(49),
    whitMonday => holidays.easterSunday(year).addDays(50),
    christmasDay => LocalDate(year, 12, 25),
    boxingDay => LocalDate(year, 12, 26),
  };

  /// Parses the comma-separated codes of the setting; unknown codes are
  /// skipped.
  static Set<SpecialDay> parseList(String? codes) => {
    for (final c in (codes ?? '').split(','))
      for (final d in values)
        if (d.code == c.trim()) d,
  };
}

/// How night hours (calculations.md §21.2) affect the credited time.
enum NightWorkCredit {
  /// Only reported; credited like any other work (default).
  count,

  /// Reported and left out of the credited time (paid out instead).
  exclude,
}

/// Which rule a holiday or day off on a trip follows.
enum TripDayRule {
  /// Like a Saturday: travel counts (capped), work counts.
  likeSaturday,

  /// Like a Sunday: travel doesn't count, work counts.
  likeSunday,
}

/// The employer's travel rules. Each value is a setting; the defaults are the
/// employer's working-time rules as the user explained them (spec:
/// calculations.md §9).
final class TravelRules {
  /// Creates travel rules.
  const TravelRules({
    this.serviceSaturdayCapMinutes = 480,
    this.dayCapMinutes = 600,
    this.sunday = TripSundayCredit.sundayHours,
    this.sundayCapMinutes = 720,
    this.holiday = TripDayRule.likeSunday,
    this.dayOff = TripDayRule.likeSaturday,
    this.specialDays = const {},
    this.night = NightWorkCredit.count,
  });

  /// Max minutes credited on a Saturday of a service trip
  /// (setting `travel.service_saturday_cap_min`).
  final int serviceSaturdayCapMinutes;

  /// Max minutes credited on a day of another trip and on a Saturday without
  /// a trip (setting `travel.day_cap_min`).
  final int dayCapMinutes;

  /// Rule for Sundays (setting `travel.sunday`).
  final TripSundayCredit sunday;

  /// Max Sunday hours per day, in minutes
  /// (setting `travel.sunday_hours_cap_min`).
  final int sundayCapMinutes;

  /// Rule for public holidays (setting `travel.holiday`).
  final TripDayRule holiday;

  /// Rule for weekdays without target on a trip (setting `travel.day_off`).
  final TripDayRule dayOff;

  /// Holidays whose Sunday hours are reported separately (setting
  /// `supplement.special_days`, §21.1); none built in.
  final Set<SpecialDay> specialDays;

  /// How night hours count (setting `night_work.credit`, §21.2).
  final NightWorkCredit night;

  /// Whether [date] is one of [specialDays].
  bool isSpecialDay(LocalDate date) =>
      specialDays.any((d) => d.inYear(date.year) == date);
}

/// The §9 day type of [date], given whether it is a public holiday and its
/// target `T(D)`.
TripDayType tripDayType(
  LocalDate date, {
  required bool isHoliday,
  required int target,
}) {
  if (isHoliday) return TripDayType.holiday;
  if (date.weekday == DateTime.sunday) return TripDayType.sunday;
  if (date.weekday == DateTime.saturday) return TripDayType.saturday;
  return target > 0 ? TripDayType.workday : TripDayType.dayOff;
}

/// Credited minutes of a day that follows §9, before absence credit
/// (spec: calculations.md §9).
///
/// [effectiveWorked] is `W_eff(D)`; [travelWorked] is `W_loc(D, travel)`.
/// [service] is set on days of a service trip: their workdays count the
/// target and their Saturdays at most [TravelRules.serviceSaturdayCapMinutes];
/// other days at most [TravelRules.dayCapMinutes].
int tripDayCredit({
  required TripDayType type,
  required int target,
  required int effectiveWorked,
  required int travelWorked,
  bool service = false,
  TravelRules rules = const TravelRules(),
}) {
  int capped(int cap) => effectiveWorked < cap ? effectiveWorked : cap;
  final travel = travelWorked < effectiveWorked
      ? travelWorked
      : effectiveWorked;
  int saturday() =>
      capped(service ? rules.serviceSaturdayCapMinutes : rules.dayCapMinutes);
  final sunday = rules.sunday == TripSundayCredit.sundayHours
      ? 0
      : effectiveWorked - travel;
  return switch (type) {
    TripDayType.workday => service ? target : capped(rules.dayCapMinutes),
    TripDayType.saturday => saturday(),
    TripDayType.sunday => sunday,
    TripDayType.holiday =>
      rules.holiday == TripDayRule.likeSaturday ? saturday() : sunday,
    TripDayType.dayOff =>
      rules.dayOff == TripDayRule.likeSaturday ? saturday() : sunday,
  };
}

/// Whether a trip day of [type] follows the Sunday rule under [rules].
bool followsSundayRule(TripDayType type, TravelRules rules) => switch (type) {
  TripDayType.sunday => true,
  TripDayType.holiday => rules.holiday == TripDayRule.likeSunday,
  TripDayType.dayOff => rules.dayOff == TripDayRule.likeSunday,
  TripDayType.workday || TripDayType.saturday => false,
};

/// **Sunday hours** of a trip day (spec: calculations.md §9): with
/// [TripSundayCredit.sundayHours], on days following the Sunday rule, travel
/// and work together up to the cap. They are reported for extra pay and are
/// not part of the overtime balance. Otherwise 0.
int tripSundayHours({
  required TripDayType type,
  required int effectiveWorked,
  TravelRules rules = const TravelRules(),
}) {
  if (rules.sunday != TripSundayCredit.sundayHours ||
      !followsSundayRule(type, rules)) {
    return 0;
  }
  final cap = rules.sundayCapMinutes;
  return effectiveWorked < cap ? effectiveWorked : cap;
}

/// Credit from vacation, sick and special-leave absences on one day:
/// `Σ fraction × T(D)`, at most `T(D)` (spec: calculations.md §8).
int absenceCredit(Iterable<Absence> absencesOnDay, int target) {
  final share = absencesOnDay
      .where((a) => a.kind.creditsTarget)
      .fold(0.0, (sum, a) => sum + a.fraction);
  final credit = (share.clamp(0, 1) * target).round();
  return credit;
}
