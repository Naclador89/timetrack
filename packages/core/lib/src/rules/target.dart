import '../model/planning.dart';
import '../time/local_date.dart';
import 'holidays.dart';

/// Target time per day from schedules, public holidays and `extra_holiday`
/// absences (spec: calculations.md §7).
final class TargetCalendar {
  /// Creates a calendar. [absences] may contain any kind; only
  /// [AbsenceKind.extraHoliday] affects the target.
  TargetCalendar({
    required List<WorkSchedule> schedules,
    required this.holidays,
    List<Absence> absences = const [],
  }) : _schedules = [...schedules]
         ..sort((a, b) => b.validFrom.compareTo(a.validFrom)),
       _extraHoliday = _sumByDate(
         absences.where((a) => a.kind == AbsenceKind.extraHoliday),
       );

  /// Holidays of the user's federal state.
  final HolidayCalendar holidays;

  /// Newest first, so the first match is the schedule in force.
  final List<WorkSchedule> _schedules;
  final Map<LocalDate, double> _extraHoliday;

  /// The schedule in force on [date] (greatest `validFrom ≤ date`), if any.
  WorkSchedule? scheduleOn(LocalDate date) {
    for (final s in _schedules) {
      if (!s.validFrom.isAfter(date)) return s;
    }
    return null;
  }

  /// `T_sched(D)`: the schedule's minutes for the weekday, before holidays.
  int scheduledMinutes(LocalDate date) =>
      scheduleOn(date)?.minutesOn(date) ?? 0;

  /// `T(D)`: 0 on public holidays, reduced by `extra_holiday` absences.
  int targetMinutes(LocalDate date) {
    if (holidays.isHoliday(date)) return 0;
    final off = (_extraHoliday[date] ?? 0).clamp(0, 1);
    return (scheduledMinutes(date) * (1 - off)).round();
  }

  /// Whether [date] is a workday, i.e. `T(D) > 0`.
  bool isWorkday(LocalDate date) => targetMinutes(date) > 0;

  static Map<LocalDate, double> _sumByDate(Iterable<Absence> absences) {
    final result = <LocalDate, double>{};
    for (final a in absences) {
      result[a.date] = (result[a.date] ?? 0) + a.fraction;
    }
    return result;
  }
}
