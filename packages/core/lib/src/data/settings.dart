import '../rules/arbzg.dart';
import '../rules/balance_zone.dart';
import '../rules/credit.dart';
import '../rules/holidays.dart';
import '../rules/home_office.dart';
import '../rules/trip_expenses.dart';
import '../rules/week_limits.dart';
import '../sync/change.dart';
import '../sync/repository.dart';
import '../time/local_date.dart';

/// Setting keys (row ids in the `settings` table, spec: data-model.md §7).
abstract final class SettingKeys {
  /// Federal state code, e.g. `NW` (calculations.md §6). No default.
  static const federalState = 'federal_state';

  /// Mariä Himmelfahrt in Bavaria (calculations.md §6).
  static const bavariaAssumptionDay = 'by_assumption_day';

  /// Heiligabend and Silvester as half days (calculations.md §6.1).
  static const halfDayEves = 'half_day_eves';

  /// IANA home time zone (calculations.md §1).
  static const homeTimeZone = 'home_time_zone';

  /// `warn` or `deduct` (calculations.md §4).
  static const breakRuleMode = 'break_rule_mode';

  /// Overtime carried over from before [balanceStartDate], in minutes (§8).
  static const startingBalance = 'starting_balance';

  /// First day counted in the balance, `YYYY-MM-DD` (§8).
  static const balanceStartDate = 'balance_start_date';

  /// `majority`, `any` or `proportional` (§11.1).
  static const homeOfficeDayRule = 'home_office.day_rule';

  /// Max minutes on a Saturday of a service trip (§9).
  static const travelServiceSaturdayCap = 'travel.service_saturday_cap_min';

  /// Max minutes on a day of another trip or a Saturday without one (§9).
  static const travelDayCap = 'travel.day_cap_min';

  /// `sunday_hours` or `work_only` (§9).
  static const travelSunday = 'travel.sunday';

  /// Cap for Sunday hours per day, in minutes (§9). A new key: the old
  /// `travel.sunday_cap_min` held the earlier 11 h default.
  static const travelSundayCap = 'travel.sunday_hours_cap_min';

  /// `like_sunday` or `like_saturday` (§9).
  static const travelHoliday = 'travel.holiday';

  /// `like_saturday` or `like_sunday` (§9).
  static const travelDayOff = 'travel.day_off';

  /// Comma-separated special holidays, e.g. `christmas_day,may_day`
  /// (§21.1).
  static const specialDays = 'supplement.special_days';

  /// `count` or `exclude` (§21.2).
  static const nightWorkCredit = 'night_work.credit';

  /// Mileage for the own car in cents per km (§13.3).
  static const mileageCentsPerKm = 'travel.mileage_cents_per_km';

  /// Site days in a row that start the site allowance (§13.4).
  static const siteAllowanceMinDays = 'travel.site_allowance_min_days';

  /// Laundry on trips touching more dates than this, 0 = off (§13.5).
  static const laundryAfterDays = 'travel.laundry_after_days';

  /// Months to submit an expense claim, 0 = off (§13.5).
  static const claimDeadlineMonths = 'travel.claim_deadline_months';

  /// Most worked minutes in one week, 0 = off (§22).
  static const weekMax = 'limits.week_max_min';

  /// Most average worked minutes per week, 0 = off (§22).
  static const weekAverage = 'limits.week_avg_min';

  /// Weeks of the rolling average (§22).
  static const averageWeeks = 'limits.avg_weeks';

  /// Balance zone limits in minutes, unset = none (§20).
  static const balanceYellowPlus = 'balance.yellow_plus_min';

  /// See [balanceYellowPlus].
  static const balanceYellowMinus = 'balance.yellow_minus_min';

  /// See [balanceYellowPlus].
  static const balanceRedPlus = 'balance.red_plus_min';

  /// See [balanceYellowPlus].
  static const balanceRedMinus = 'balance.red_minus_min';

  /// See [balanceYellowPlus].
  static const balanceMaxPlus = 'balance.max_plus_min';

  /// See [balanceYellowPlus].
  static const balanceMaxMinus = 'balance.max_minus_min';

  /// Months to take carried-over vacation, 0 = off (§10.2).
  static const vacationCarryDeadline = 'vacation.carry_deadline_months';

  /// Minutes after which an open session is flagged (§12).
  static const openSessionLimit = 'open_session_limit_min';

  /// Starting a project while clocked out clocks in (concept §2).
  static const autoClockIn = 'auto_clock_in';

  /// Ending a break resumes the project that was running before it.
  static const resumeAfterBreak = 'resume_after_break';

  /// Ask for the time when clocking in or out and at breaks (§19).
  static const askStampTime = 'ask_stamp_time';

  /// Minimum unassigned time of a day before it is a notice (§12).
  static const noticeUnassignedMin = 'notices.unassigned_min';

  /// Usual start of the break, minutes since local midnight (§4.1).
  static const defaultBreakStart = 'breaks.default_start_min';

  /// Usual length of the break in minutes (§4.1).
  static const defaultBreakMinutes = 'breaks.default_min';

  /// Remind when a break is due (reminders.md §2).
  static const remindBreak = 'reminders.break';

  /// Remind before 10 hours of work (reminders.md §2).
  static const remindLongDay = 'reminders.long_day';

  /// Remind when today's target is reached (reminders.md §2).
  static const remindTarget = 'reminders.target';

  /// Whether notices of [category] are shown as cards (§12).
  static String noticeShow(String category) => 'notices.show.$category';

  /// Vacation entitlement override for a year (§10).
  static String vacationEntitlement(int year) => 'vacation.entitlement.$year';

  /// Vacation carry-over into a year (§10).
  static String vacationCarryOver(int year) => 'vacation.carry_over.$year';
}

/// All settings with their defaults, read from the `settings` rows.
final class AppSettings {
  /// Creates settings; every argument has the documented default.
  const AppSettings({
    this.federalState,
    this.bavariaAssumptionDay = true,
    this.halfDayEves = true,
    this.homeTimeZone = 'Europe/Berlin',
    this.breakMode = BreakRuleMode.warn,
    this.startingBalance = 0,
    this.balanceStart,
    this.homeOfficeDayRule = HomeOfficeDayRule.majority,
    this.travel = const TravelRules(),
    this.expenses = const ExpenseRules(),
    this.weekLimits = const WeekLimits(),
    this.balanceLimits = const BalanceLimits(),
    this.vacationCarryDeadlineMonths = 3,
    this.openSessionLimitMinutes = 720,
    this.autoClockIn = true,
    this.resumeAfterBreak = true,
    this.askStampTime = true,
    this.noticeUnassignedMinMinutes = 30,
    this.defaultBreakStart = 720,
    this.defaultBreakMinutes = 30,
    this.remindBreak = true,
    this.remindLongDay = true,
    this.remindTarget = true,
    this.raw = const {},
  });

  /// Reads settings from `settings` rows (other tables and deleted rows are
  /// ignored; unknown or malformed values fall back to the default).
  factory AppSettings.fromRows(Iterable<StoredRow> rows) {
    final v = <String, Object?>{
      for (final r in rows)
        if (r.table == 'settings' && !r.isDeleted) r.id: r.fields['value'],
    };
    T pick<T>(String key, T fallback) => v[key] is T ? v[key] as T : fallback;
    E enumOf<E extends Enum>(List<E> values, String key, E fallback) {
      final wire = v[key];
      for (final e in values) {
        if (_snake(e.name) == wire) return e;
      }
      return fallback;
    }

    FederalState? state;
    try {
      final code = v[SettingKeys.federalState];
      if (code is String) state = FederalState.parse(code);
    } on ArgumentError {
      state = null;
    }
    LocalDate? start;
    try {
      final date = v[SettingKeys.balanceStartDate];
      if (date is String) start = LocalDate.parse(date);
    } on FormatException {
      start = null;
    }
    const d = TravelRules();
    int? limit(String key) => switch (v[key]) {
      final num n when n > 0 => n.toInt(),
      _ => null,
    };
    return AppSettings(
      federalState: state,
      bavariaAssumptionDay: pick(SettingKeys.bavariaAssumptionDay, true),
      halfDayEves: pick(SettingKeys.halfDayEves, true),
      homeTimeZone: pick(SettingKeys.homeTimeZone, 'Europe/Berlin'),
      breakMode: enumOf(
        BreakRuleMode.values,
        SettingKeys.breakRuleMode,
        BreakRuleMode.warn,
      ),
      startingBalance: pick<num>(SettingKeys.startingBalance, 0).toInt(),
      balanceStart: start,
      homeOfficeDayRule: enumOf(
        HomeOfficeDayRule.values,
        SettingKeys.homeOfficeDayRule,
        HomeOfficeDayRule.majority,
      ),
      travel: TravelRules(
        serviceSaturdayCapMinutes: pick<num>(
          SettingKeys.travelServiceSaturdayCap,
          d.serviceSaturdayCapMinutes,
        ).toInt(),
        dayCapMinutes: pick<num>(
          SettingKeys.travelDayCap,
          d.dayCapMinutes,
        ).toInt(),
        sunday: enumOf(
          TripSundayCredit.values,
          SettingKeys.travelSunday,
          d.sunday,
        ),
        sundayCapMinutes: pick<num>(
          SettingKeys.travelSundayCap,
          d.sundayCapMinutes,
        ).toInt(),
        holiday: enumOf(
          TripDayRule.values,
          SettingKeys.travelHoliday,
          d.holiday,
        ),
        dayOff: enumOf(TripDayRule.values, SettingKeys.travelDayOff, d.dayOff),
        specialDays: SpecialDay.parseList(
          pick<String>(SettingKeys.specialDays, ''),
        ),
        night: enumOf(
          NightWorkCredit.values,
          SettingKeys.nightWorkCredit,
          d.night,
        ),
      ),
      expenses: ExpenseRules(
        mileageCentsPerKm: pick<num>(
          SettingKeys.mileageCentsPerKm,
          30,
        ).toInt().clamp(0, 1000),
        siteAllowanceMinDays: pick<num>(
          SettingKeys.siteAllowanceMinDays,
          2,
        ).toInt().clamp(1, 31),
        laundryAfterDays: pick<num>(
          SettingKeys.laundryAfterDays,
          0,
        ).toInt().clamp(0, 365),
        claimDeadlineMonths: pick<num>(
          SettingKeys.claimDeadlineMonths,
          0,
        ).toInt().clamp(0, 24),
      ),
      weekLimits: WeekLimits(
        maxMinutes: pick<num>(
          SettingKeys.weekMax,
          3600,
        ).toInt().clamp(0, 10080),
        averageMinutes: pick<num>(
          SettingKeys.weekAverage,
          2880,
        ).toInt().clamp(0, 10080),
        averageWeeks: pick<num>(
          SettingKeys.averageWeeks,
          24,
        ).toInt().clamp(1, 52),
      ),
      balanceLimits: BalanceLimits(
        yellowPlus: limit(SettingKeys.balanceYellowPlus),
        yellowMinus: limit(SettingKeys.balanceYellowMinus),
        redPlus: limit(SettingKeys.balanceRedPlus),
        redMinus: limit(SettingKeys.balanceRedMinus),
        maxPlus: limit(SettingKeys.balanceMaxPlus),
        maxMinus: limit(SettingKeys.balanceMaxMinus),
      ),
      vacationCarryDeadlineMonths: pick<num>(
        SettingKeys.vacationCarryDeadline,
        3,
      ).toInt().clamp(0, 12),
      openSessionLimitMinutes: pick<num>(
        SettingKeys.openSessionLimit,
        720,
      ).toInt(),
      autoClockIn: pick(SettingKeys.autoClockIn, true),
      resumeAfterBreak: pick(SettingKeys.resumeAfterBreak, true),
      askStampTime: pick(SettingKeys.askStampTime, true),
      noticeUnassignedMinMinutes: pick<num>(
        SettingKeys.noticeUnassignedMin,
        30,
      ).toInt(),
      defaultBreakStart: pick<num>(
        SettingKeys.defaultBreakStart,
        720,
      ).toInt().clamp(0, 1439),
      defaultBreakMinutes: pick<num>(
        SettingKeys.defaultBreakMinutes,
        30,
      ).toInt().clamp(5, 240),
      remindBreak: pick(SettingKeys.remindBreak, true),
      remindLongDay: pick(SettingKeys.remindLongDay, true),
      remindTarget: pick(SettingKeys.remindTarget, true),
      raw: v,
    );
  }

  /// The user's federal state; `null` until set (the app asks for it).
  final FederalState? federalState;

  /// Mariä Himmelfahrt in Bavaria.
  final bool bavariaAssumptionDay;

  /// Heiligabend and Silvester as half days.
  final bool halfDayEves;

  /// IANA home time zone.
  final String homeTimeZone;

  /// How missing breaks are handled.
  final BreakRuleMode breakMode;

  /// Overtime carried over, in minutes.
  final int startingBalance;

  /// First day of the balance; `null` = the first day with a schedule.
  final LocalDate? balanceStart;

  /// How a home-office day is decided.
  final HomeOfficeDayRule homeOfficeDayRule;

  /// The employer's travel rules.
  final TravelRules travel;

  /// The employer's expense rules (§13.2–§13.5).
  final ExpenseRules expenses;

  /// Weekly limits of worked time (§22).
  final WeekLimits weekLimits;

  /// Limits of the overtime account (§20).
  final BalanceLimits balanceLimits;

  /// Months to take carried-over vacation, 0 = off (§10.2).
  final int vacationCarryDeadlineMonths;

  /// Minutes after which an open session is flagged.
  final int openSessionLimitMinutes;

  /// Starting a project while clocked out clocks in.
  final bool autoClockIn;

  /// Ending a break resumes the project that ran before it.
  final bool resumeAfterBreak;

  /// Ask for the time when clocking in or out and at breaks (§19).
  final bool askStampTime;

  /// Unassigned time below this is no notice (§12).
  final int noticeUnassignedMinMinutes;

  /// Usual start of the break, minutes since local midnight (§4.1).
  final int defaultBreakStart;

  /// Usual length of the break in minutes (§4.1).
  final int defaultBreakMinutes;

  /// Remind when a break is due (reminders.md §2).
  final bool remindBreak;

  /// Remind before 10 hours of work (reminders.md §2).
  final bool remindLongDay;

  /// Remind when today's target is reached (reminders.md §2).
  final bool remindTarget;

  /// Whether notices of the category with this wire name are shown as
  /// cards (default yes).
  bool showsNotice(String category) =>
      raw[SettingKeys.noticeShow(category)] != false;

  /// All raw values by key (also year-specific keys such as vacation).
  final Map<String, Object?> raw;

  /// A raw numeric value, e.g. `vacation.carry_over.2026`.
  double? number(String key) => (raw[key] as num?)?.toDouble();

  /// Holiday options derived from these settings.
  HolidayOptions get holidayOptions => HolidayOptions(
    bavariaAssumptionDay: bavariaAssumptionDay,
    halfDayEves: halfDayEves,
  );
}

/// The wire form of an enum value name, e.g. `likeSunday` → `like_sunday`.
String settingValueOf(Enum value) => _snake(value.name);

String _snake(String camel) =>
    camel.replaceAllMapped(RegExp('[A-Z]'), (m) => '_${m[0]!.toLowerCase()}');

/// Saves one setting through the repository (a synced `settings` row).
Future<void> saveSetting(
  SyncedRepository repo,
  String key,
  Object? value,
) => repo.write('settings', key, {
  'value': value is Enum ? settingValueOf(value) : value,
  // A setting is never meant to stay deleted; this revives a tombstoned row.
  'deleted': false,
});
