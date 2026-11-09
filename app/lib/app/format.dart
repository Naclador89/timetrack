import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:timetrack_core/timetrack_core.dart';

import '../l10n/app_localizations.dart';

/// Locale-aware formatting for the UI. Durations use the spec format
/// (`formatMinutes`, calculations.md §14).
extension Formatting on BuildContext {
  /// The generated strings.
  AppLocalizations get l10n => AppLocalizations.of(this);

  String get _locale => Localizations.localeOf(this).toLanguageTag();

  /// Local wall-clock time of [instant] in [zone], e.g. `08:05`.
  String time(DateTime instant, HomeTimeZone zone) =>
      DateFormat.Hm(_locale).format(zone.toLocal(instant));

  /// Long date, e.g. `Mittwoch, 4. November`.
  String longDate(LocalDate d) => DateFormat.MMMMEEEEd(_locale).format(_dt(d));

  /// Short date with weekday, e.g. `Mi., 04.11.`.
  String shortDate(LocalDate d) =>
      '${DateFormat.E(_locale).format(_dt(d))}, ${DateFormat.Md(_locale).format(_dt(d))}';

  /// Numeric date, e.g. `04.11.2026`.
  String date(LocalDate d) => DateFormat.yMd(_locale).format(_dt(d));

  /// Money from cents, `14,00 €`.
  String euro(int cents) =>
      NumberFormat.currency(locale: _locale, symbol: '€').format(cents / 100);

  /// Days with up to one decimal, e.g. `2,5`.
  String days(num value) => NumberFormat('#0.#', _locale).format(value);

  /// Name of a work location.
  String locationName(WorkLocation l) => locationLabel(l10n, l);

  /// Name of an absence kind.
  String absenceName(AbsenceKind k) => absenceLabel(l10n, k);

  static DateTime _dt(LocalDate d) => DateTime(d.year, d.month, d.day);
}

/// Icon for a work location.
IconData locationIcon(WorkLocation l) => switch (l) {
  WorkLocation.office => Icons.business_outlined,
  WorkLocation.home => Icons.home_outlined,
  WorkLocation.onSite => Icons.place_outlined,
  WorkLocation.travel => Icons.train_outlined,
};

/// Icon of a day type (calculations.md §15), shown in front of each day in
/// the calendar.
IconData dayTypeIcon(DayType t) => switch (t) {
  DayType.office => Icons.business_outlined,
  DayType.home => Icons.home_outlined,
  DayType.businessTrip => Icons.flight,
  DayType.vacation => Icons.beach_access_outlined,
  DayType.sick => Icons.sick_outlined,
  DayType.childSick => Icons.child_care,
  DayType.flexTime => Icons.hourglass_bottom,
  DayType.shortTime => Icons.trending_down,
  DayType.specialLeave => Icons.local_florist_outlined,
};

/// Name of a day type.
String dayTypeLabel(AppLocalizations l, DayType t) => switch (t) {
  DayType.office => l.locationOffice,
  DayType.home => l.locationHome,
  DayType.businessTrip => l.dayBusinessTrip,
  _ => absenceLabel(l, t.absenceKind!),
};

/// Parses `h:mm` or decimal hours (`7,5` / `7.5`) into minutes; `null` if invalid.
int? parseHours(String text) {
  final t = text.trim().replaceAll('−', '-');
  final negative = t.startsWith('-');
  final body = negative ? t.substring(1) : t;
  int? minutes;
  final hm = RegExp(r'^(\d{1,3}):([0-5]\d)$').firstMatch(body);
  if (hm != null) {
    minutes = int.parse(hm[1]!) * 60 + int.parse(hm[2]!);
  } else {
    final dec = double.tryParse(body.replaceAll(',', '.'));
    if (dec != null && dec >= 0) minutes = (dec * 60).round();
  }
  if (minutes == null) return null;
  return negative ? -minutes : minutes;
}

/// Name of a work location (also usable without a BuildContext, e.g. in exports).
String locationLabel(AppLocalizations l, WorkLocation loc) => switch (loc) {
  WorkLocation.office => l.locationOffice,
  WorkLocation.home => l.locationHome,
  WorkLocation.onSite => l.locationOnSite,
  WorkLocation.travel => l.locationTravel,
};

/// Name of an absence kind (also usable without a BuildContext).
String absenceLabel(AppLocalizations l, AbsenceKind k) => switch (k) {
  AbsenceKind.vacation => l.absenceVacation,
  AbsenceKind.sick => l.absenceSick,
  AbsenceKind.specialLeave => l.absenceSpecialLeave,
  AbsenceKind.childSick => l.absenceChildSick,
  AbsenceKind.shortTime => l.absenceShortTime,
  AbsenceKind.compTime => l.absenceCompTime,
  AbsenceKind.extraHoliday => l.absenceExtraHoliday,
};

/// Icon of a notice category (settings).
IconData noticeCategoryIcon(NoticeCategory c) => switch (c) {
  NoticeCategory.unassigned => Icons.work_outline,
  NoticeCategory.breaks => Icons.coffee_outlined,
  NoticeCategory.longDay => Icons.timelapse,
  NoticeCategory.rest => Icons.bedtime_outlined,
  NoticeCategory.sundayWork => Icons.wb_sunny_outlined,
  NoticeCategory.openSession => Icons.timer_off_outlined,
  NoticeCategory.overlaps => Icons.layers_outlined,
  NoticeCategory.projectTime => Icons.rule,
  NoticeCategory.homeOfficeQuota => Icons.home_outlined,
  NoticeCategory.openTrip => Icons.luggage_outlined,
  NoticeCategory.projectBudget => Icons.savings_outlined,
  NoticeCategory.balanceZone => Icons.traffic_outlined,
  NoticeCategory.weekLimit => Icons.date_range_outlined,
};

/// Name of a notice category (settings).
String noticeCategoryLabel(AppLocalizations l, NoticeCategory c) => switch (c) {
  NoticeCategory.unassigned => l.noticeCatUnassigned,
  NoticeCategory.breaks => l.noticeCatBreaks,
  NoticeCategory.longDay => l.noticeCatLongDay,
  NoticeCategory.rest => l.noticeCatRest,
  NoticeCategory.sundayWork => l.noticeCatSunday,
  NoticeCategory.openSession => l.noticeCatOpenSession,
  NoticeCategory.overlaps => l.noticeCatOverlaps,
  NoticeCategory.projectTime => l.noticeCatProjectTime,
  NoticeCategory.homeOfficeQuota => l.noticeCatQuota,
  NoticeCategory.openTrip => l.noticeCatOpenTrip,
  NoticeCategory.projectBudget => l.noticeCatBudget,
  NoticeCategory.balanceZone => l.noticeCatBalanceZone,
  NoticeCategory.weekLimit => l.noticeCatWeekLimit,
};

/// The balance with its sign, e.g. `+12:30` or `−3:15`.
String signedBalance(int minutes) =>
    minutes > 0 ? '+${formatMinutes(minutes)}' : formatMinutes(minutes);

/// The country of an ISO code by its name in the BMF table (German, as
/// published), or the code itself (calculations §13.0).
String countryName(String code) => bmfCountryNames[code] ?? code;

/// `Frankreich · Paris`.
String placeLabel(TripPlace p) => [countryName(p.country), ?p.city].join(' · ');
