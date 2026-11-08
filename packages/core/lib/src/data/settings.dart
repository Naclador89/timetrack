import '../rules/arbzg.dart';
import '../rules/credit.dart';
import '../rules/holidays.dart';
import '../rules/home_office.dart';
import '../sync/change.dart';
import '../sync/repository.dart';
import '../time/local_date.dart';

/// Setting keys (row ids in the `settings` table, spec: data-model.md §7).
abstract final class SettingKeys {
  /// Federal state code, e.g. `NW` (calculations.md §6). No default.
  static const federalState = 'federal_state';

  /// Mariä Himmelfahrt in Bavaria (calculations.md §6).
  static const bavariaAssumptionDay = 'by_assumption_day';

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

  /// `target` or `actual` (§9).
  static const travelWorkday = 'travel.workday';

  /// Saturday cap in minutes (§9).
  static const travelSaturdayCap = 'travel.saturday_cap_min';

  /// `total` or `travel_only` (§9).
  static const travelSaturdayCapScope = 'travel.saturday_cap_scope';

  /// `sunday_hours` or `work_only` (§9).
  static const travelSunday = 'travel.sunday';

  /// Cap for Sunday hours per trip Sunday, in minutes (§9).
  static const travelSundayCap = 'travel.sunday_cap_min';

  /// `like_sunday` or `like_saturday` (§9).
  static const travelHoliday = 'travel.holiday';

  /// `like_saturday` or `like_sunday` (§9).
  static const travelDayOff = 'travel.day_off';

  /// Minutes after which an open session is flagged (§12).
  static const openSessionLimit = 'open_session_limit_min';

  /// Starting a project while clocked out clocks in (concept §2).
  static const autoClockIn = 'auto_clock_in';

  /// Ending a break resumes the project that was running before it.
  static const resumeAfterBreak = 'resume_after_break';

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
    this.homeTimeZone = 'Europe/Berlin',
    this.breakMode = BreakRuleMode.warn,
    this.startingBalance = 0,
    this.balanceStart,
    this.homeOfficeDayRule = HomeOfficeDayRule.majority,
    this.travel = const TravelRules(),
    this.openSessionLimitMinutes = 720,
    this.autoClockIn = true,
    this.resumeAfterBreak = true,
    this.noticeUnassignedMinMinutes = 30,
    this.defaultBreakStart = 720,
    this.defaultBreakMinutes = 30,
    this.remindBreak = true,
    this.remindLongDay = true,
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
    return AppSettings(
      federalState: state,
      bavariaAssumptionDay: pick(SettingKeys.bavariaAssumptionDay, true),
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
        workday: enumOf(
          TripWorkdayCredit.values,
          SettingKeys.travelWorkday,
          d.workday,
        ),
        saturdayCapMinutes: pick<num>(
          SettingKeys.travelSaturdayCap,
          d.saturdayCapMinutes,
        ).toInt(),
        saturdayCapScope: enumOf(
          SaturdayCapScope.values,
          SettingKeys.travelSaturdayCapScope,
          d.saturdayCapScope,
        ),
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
      ),
      openSessionLimitMinutes: pick<num>(
        SettingKeys.openSessionLimit,
        720,
      ).toInt(),
      autoClockIn: pick(SettingKeys.autoClockIn, true),
      resumeAfterBreak: pick(SettingKeys.resumeAfterBreak, true),
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
      raw: v,
    );
  }

  /// The user's federal state; `null` until set (the app asks for it).
  final FederalState? federalState;

  /// Mariä Himmelfahrt in Bavaria.
  final bool bavariaAssumptionDay;

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

  /// Minutes after which an open session is flagged.
  final int openSessionLimitMinutes;

  /// Starting a project while clocked out clocks in.
  final bool autoClockIn;

  /// Ending a break resumes the project that ran before it.
  final bool resumeAfterBreak;

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

  /// Whether notices of the category with this wire name are shown as
  /// cards (default yes).
  bool showsNotice(String category) =>
      raw[SettingKeys.noticeShow(category)] != false;

  /// All raw values by key (also year-specific keys such as vacation).
  final Map<String, Object?> raw;

  /// A raw numeric value, e.g. `vacation.carry_over.2026`.
  double? number(String key) => (raw[key] as num?)?.toDouble();

  /// Holiday options derived from these settings.
  HolidayOptions get holidayOptions =>
      HolidayOptions(bavariaAssumptionDay: bavariaAssumptionDay);
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
