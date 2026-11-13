import '../model/planning.dart';
import '../time/local_date.dart';
import 'holidays.dart';

/// Target time per day from schedules, public holidays and `extra_holiday`
/// absences (spec: calculations.md §7).
final class TargetCalendar {
  /// Creates a calendar. [absences] may contain any kind; only those that
  /// [AbsenceKind.reducesTarget] (`extra_holiday`, `short_time`) affect it.
  TargetCalendar({
    required List<WorkSchedule> schedules,
    required this.holidays,
    List<Absence> absences = const [],
  }) : _schedules = [...schedules]
         ..sort((a, b) => b.validFrom.compareTo(a.validFrom)),
       _extraHoliday = _sumByDate(absences.where((a) => a.kind.reducesTarget));

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

  /// `T(D)`: 0 on public holidays, reduced by `extra_holiday` and
  /// `short_time` absences and on half days (§6.1).
  int targetMinutes(LocalDate date) {
    if (holidays.isHoliday(date)) return 0;
    return (scheduledMinutes(date) * (1 - _off(date))).round();
  }

  /// Whether [date] is a workday, i.e. `T(D) > 0`.
  bool isWorkday(LocalDate date) => targetMinutes(date) > 0;

  /// The share of the scheduled day still to be worked: 1 on a plain
  /// workday, 0.5 on a half day, 0 on a free day. Unlike
  /// `T(D) / T_sched(D)` it isn't skewed by rounding to the minute.
  double workShare(LocalDate date) {
    if (holidays.isHoliday(date) || scheduledMinutes(date) == 0) return 0;
    return 1 - _off(date);
  }

  /// The days an absence of [fraction] uses on [date]: at most what is left
  /// to work that day (§10), so nothing on a free day and at most half a day
  /// on Heiligabend.
  double usedDays(LocalDate date, double fraction) {
    final share = workShare(date);
    return fraction < share ? fraction : share;
  }

  /// The share of the scheduled day taken off: `extra_holiday` and
  /// `short_time` absences, at least half on a half day. They don't add up
  /// there, since an `extra_holiday` on Heiligabend is usually that very half.
  double _off(LocalDate date) {
    final off = (_extraHoliday[date] ?? 0).clamp(0.0, 1.0);
    return holidays.isHalfDay(date) && off < 0.5 ? 0.5 : off;
  }

  static Map<LocalDate, double> _sumByDate(Iterable<Absence> absences) {
    final result = <LocalDate, double>{};
    for (final a in absences) {
      result[a.date] = (result[a.date] ?? 0) + a.fraction;
    }
    return result;
  }
}
