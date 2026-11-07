import 'attendance.dart';
import 'planning.dart';

/// What kind of day a date is (calculations.md §15). The user picks one per
/// day in the calendar and on Today; it decides what can be recorded:
/// project time on office and home-office days, travel and on-site time on
/// business trips, nothing on absence days.
enum DayType {
  /// At the office (sessions at [WorkLocation.office]).
  office,

  /// Home office (sessions at [WorkLocation.home]).
  home,

  /// Business trip (the day lies in a trip, §9).
  businessTrip,

  /// Vacation ([AbsenceKind.vacation]).
  vacation,

  /// Sick ([AbsenceKind.sick]).
  sick,

  /// Child sick day ([AbsenceKind.childSick]).
  childSick,

  /// Taking overtime off ([AbsenceKind.compTime], "Gleitzeit").
  flexTime,

  /// Short-time work ([AbsenceKind.shortTime]).
  shortTime,

  /// Celebration or bereavement leave ([AbsenceKind.specialLeave]).
  specialLeave;

  /// The absence recorded for this type, or `null` for working days.
  AbsenceKind? get absenceKind => switch (this) {
    vacation => AbsenceKind.vacation,
    sick => AbsenceKind.sick,
    childSick => AbsenceKind.childSick,
    flexTime => AbsenceKind.compTime,
    shortTime => AbsenceKind.shortTime,
    specialLeave => AbsenceKind.specialLeave,
    office || home || businessTrip => null,
  };

  /// Whether this is a working day type (office, home, trip).
  bool get isWork => absenceKind == null;

  /// Whether project time can be recorded (office and home office only).
  bool get allowsProjectTime => this == office || this == home;

  /// The session locations offered on such a day.
  List<WorkLocation> get locations => switch (this) {
    office => const [WorkLocation.office],
    home => const [WorkLocation.home],
    businessTrip => const [WorkLocation.travel, WorkLocation.onSite],
    _ => const [],
  };

  /// The type for an absence of [kind] (`extra_holiday` has none).
  static DayType? ofAbsence(AbsenceKind kind) => switch (kind) {
    AbsenceKind.vacation => vacation,
    AbsenceKind.sick => sick,
    AbsenceKind.childSick => childSick,
    AbsenceKind.compTime => flexTime,
    AbsenceKind.shortTime => shortTime,
    AbsenceKind.specialLeave => specialLeave,
    AbsenceKind.extraHoliday => null,
  };

  /// The value stored in `days.type` (only `office` and `home` are stored;
  /// the other types live in `trips` and `absences`, data-model §12).
  String get wireName => switch (this) {
    businessTrip => 'business_trip',
    childSick => 'child_sick',
    flexTime => 'flex_time',
    shortTime => 'short_time',
    specialLeave => 'special_leave',
    _ => name,
  };

  /// Parses a [wireName].
  static DayType parse(String wireName) => values.firstWhere(
    (t) => t.wireName == wireName,
    orElse: () =>
        throw ArgumentError.value(wireName, 'wireName', 'Unknown day type'),
  );
}
