import '../model/attendance.dart';
import '../model/planning.dart';
import '../time/home_time_zone.dart';
import '../time/local_date.dart';
import '../time/span.dart';
import 'arbzg.dart';
import 'credit.dart';
import 'day_work.dart';
import 'holidays.dart';
import 'target.dart';

/// Settings that affect the daily calculation.
final class LedgerSettings {
  /// Creates ledger settings.
  const LedgerSettings({
    required this.balanceStart,
    this.startingBalance = 0,
    this.breakMode = BreakRuleMode.warn,
    this.travel = const TravelRules(),
  });

  /// First day counted in the overtime balance (setting `balance_start_date`).
  final LocalDate balanceStart;

  /// Balance carried over from before [balanceStart], in minutes; may be
  /// negative (setting `starting_balance`).
  final int startingBalance;

  /// How missing breaks are handled (§4).
  final BreakRuleMode breakMode;

  /// The employer's travel rules (§9).
  final TravelRules travel;
}

/// All rows the ledger works on, already converted to plain values.
final class LedgerData {
  /// Creates the data set. Pass complete rows only (sync-format.md §6).
  const LedgerData({
    this.sessions = const [],
    this.breaks = const [],
    this.entries = const [],
    this.durations = const [],
    this.schedules = const [],
    this.absences = const [],
    this.trips = const [],
  });

  /// Work sessions (attendance).
  final List<WorkSession> sessions;

  /// Breaks.
  final List<WorkBreak> breaks;

  /// Project entries recorded as time spans (timer or start/end).
  final List<ProjectEntry> entries;

  /// Project time recorded as durations on a date.
  final List<ProjectDuration> durations;

  /// Work schedules (contracts).
  final List<WorkSchedule> schedules;

  /// Absences of every kind.
  final List<Absence> absences;

  /// Business trips.
  final List<Trip> trips;
}

/// The full evaluation of one day (spec: calculations.md §2–§9).
final class DayResult {
  /// Creates a result. Use [Ledger.day] instead of calling this directly.
  const DayResult({
    required this.date,
    required this.work,
    required this.breaks,
    required this.target,
    required this.credited,
    required this.tripDayType,
    required this.absences,
    required this.warnings,
    this.sundayHours = 0,
    this.tripProjectId,
  });

  /// The evaluated day.
  final LocalDate date;

  /// Attendance and project time (§2, §3).
  final DayWork work;

  /// Break check and effective worked time (§4).
  final BreakEvaluation breaks;

  /// Target `T(D)` (§7).
  final int target;

  /// Credited time `Cr(D)` including absence credit (§8, §9).
  final int credited;

  /// Sunday and holiday hours for HR (§9): reported separately, not part of
  /// [credited] or the balance.
  final int sundayHours;

  /// The §9 day type if this is a trip day, otherwise `null`.
  final TripDayType? tripDayType;

  /// Absences on this day.
  final List<Absence> absences;

  /// Working Hours Act warnings (§4, §5).
  final List<ArbzgWarning> warnings;

  /// Daily difference `Δ(D) = Cr(D) − T(D)` (§8).
  int get delta => credited - target;

  /// Whether a business trip touches this day.
  bool get isTripDay => tripDayType != null;

  /// The project of the trip on this day, if it has one. On trip days the
  /// user records no project time (travel and on-site only); the day's
  /// unassigned time is booked to this project instead (§3, user decision
  /// 2026-11-08).
  final String? tripProjectId;

  /// Project time per project id including the trip project (§3): what
  /// the order report and statistics count.
  Map<String, int> get bookedByProject {
    final trip = tripProjectId;
    if (trip == null || work.unassigned == 0) return work.byProject;
    return {
      ...work.byProject,
      trip: (work.byProject[trip] ?? 0) + work.unassigned,
    };
  }

  /// Worked time not booked to any project, after the trip project (§3).
  int get unassigned => tripProjectId == null ? work.unassigned : 0;
}

/// Evaluates days and the overtime balance from a [LedgerData] snapshot
/// (spec: calculations.md §7–§9).
///
/// Results are cached; create a new ledger when the data or "now" changes.
final class Ledger {
  /// Creates a ledger. Open rows (still clocked in, running trip) are
  /// evaluated up to [nowMinute] (minutes since the epoch).
  Ledger({
    required this.data,
    required this.zone,
    required this.holidays,
    required this.settings,
    required this.nowMinute,
  }) : targets = TargetCalendar(
         schedules: data.schedules,
         holidays: holidays,
         absences: data.absences,
       );

  /// The rows being evaluated.
  final LedgerData data;

  /// Home time zone for calendar days (§1).
  final HomeTimeZone zone;

  /// Public holidays of the user's state (§6).
  final HolidayCalendar holidays;

  /// Calculation settings.
  final LedgerSettings settings;

  /// "Now", in minutes since the epoch.
  final int nowMinute;

  /// Target time per day (§7).
  final TargetCalendar targets;

  final Map<LocalDate, DayWork> _work = {};
  final Map<LocalDate, DayResult> _days = {};

  /// Today's date in the home time zone.
  LocalDate get today => zone.dateOfMinute(nowMinute);

  /// The evaluation of [date].
  DayResult day(LocalDate date) => _days.putIfAbsent(date, () {
    final work = _dayWork(date);
    final breaks = evaluateBreaks(work.working, mode: settings.breakMode);
    final isHoliday = holidays.isHoliday(date);
    final target = targets.targetMinutes(date);
    final absences = [
      for (final a in data.absences)
        if (a.date == date) a,
    ];
    final type = tripDayType(date, isHoliday: isHoliday, target: target);
    final tripType = _isTripDay(date) ? type : null;
    // Saturdays, Sundays and holidays follow their rule on every day, trip
    // or not (user decision 2026-11-08); workdays and days off only on trips.
    final ruleType =
        tripType ??
        switch (type) {
          TripDayType.saturday ||
          TripDayType.sunday ||
          TripDayType.holiday => type,
          TripDayType.workday || TripDayType.dayOff => null,
        };
    final base = ruleType == null
        ? breaks.effectiveWorked
        : tripDayCredit(
            type: ruleType,
            target: target,
            effectiveWorked: breaks.effectiveWorked,
            travelWorked: work.workedAt(WorkLocation.travel),
            rules: settings.travel,
          );
    return DayResult(
      date: date,
      work: work,
      breaks: breaks,
      target: target,
      credited: base + absenceCredit(absences, target),
      tripDayType: tripType,
      tripProjectId: tripType == null
          ? null
          : tripsOn(date).map((t) => t.projectId).nonNulls.firstOrNull,
      sundayHours: ruleType == null
          ? 0
          : tripSundayHours(
              type: ruleType,
              effectiveWorked: breaks.effectiveWorked,
              rules: settings.travel,
            ),
      absences: absences,
      warnings: arbzgWarnings(
        working: work.working,
        breaks: breaks,
        previousDay: _dayWork(date.addDays(-1)).working,
        isSundayOrHoliday: isHoliday || date.weekday == DateTime.sunday,
      ),
    );
  });

  /// Overtime balance at the end of [date]: starting balance plus `Δ` of every
  /// day from the balance start through [date] (§8). For today this includes
  /// today's credited time so far against the full target.
  int balanceAtEndOf(LocalDate date) {
    var balance = settings.startingBalance;
    for (var d = settings.balanceStart; !d.isAfter(date); d = d.addDays(1)) {
      balance += day(d).delta;
    }
    return balance;
  }

  DayWork _dayWork(LocalDate date) => _work.putIfAbsent(date, () {
    final window = zone.daySpan(date);
    bool touches(Span s) => s.start < window.end && s.end > window.start;
    return evaluateDay(
      date: date,
      day: window,
      nowMinute: nowMinute,
      sessions: [
        for (final s in data.sessions)
          if (touches(s.spanAt(nowMinute))) s,
      ],
      breaks: [
        for (final b in data.breaks)
          if (touches(b.spanAt(nowMinute))) b,
      ],
      entries: [
        for (final e in data.entries)
          if (touches(e.spanAt(nowMinute))) e,
      ],
      durations: [
        for (final d in data.durations)
          if (d.date == date) d,
      ],
    );
  });

  /// §9: every local date touched by `[depart, return)` is a trip day; an
  /// open trip touches every day up to now.
  bool _isTripDay(LocalDate date) => tripsOn(date).isNotEmpty;

  /// The trips touching [date] (§9), earliest departure first.
  List<Trip> tripsOn(LocalDate date) {
    final window = zone.daySpan(date);
    return [
      for (final trip in data.trips)
        if ((
              epochMinute(trip.depart),
              trip.returnAt == null ? nowMinute : epochMinute(trip.returnAt!),
            )
            case (final start, final end)
            when start < window.end && end > window.start && end > start)
          trip,
    ]..sort((a, b) => a.depart.compareTo(b.depart));
  }
}
