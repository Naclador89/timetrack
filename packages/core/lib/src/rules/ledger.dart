import '../model/attendance.dart';
import '../model/day_type.dart';
import '../model/planning.dart';
import '../time/home_time_zone.dart';
import '../time/local_date.dart';
import '../time/span.dart';
import 'arbzg.dart';
import 'credit.dart';
import 'day_work.dart';
import 'holidays.dart';
import 'target.dart';
import 'trip_expenses.dart';

/// Settings that affect the daily calculation.
final class LedgerSettings {
  /// Creates ledger settings.
  const LedgerSettings({
    required this.balanceStart,
    this.startingBalance = 0,
    this.breakMode = BreakRuleMode.warn,
    this.travel = const TravelRules(),
    this.expenses = const ExpenseRules(),
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

  /// The employer's expense rules (§13.2–§13.5).
  final ExpenseRules expenses;
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
    this.tripStops = const [],
    this.siteAllowances = const [],
    this.dayChoices = const {},
  });

  /// Places of trips from a date on (§13.1).
  final List<TripStop> tripStops;

  /// The employer's site allowance rates (§13.4).
  final List<SiteAllowanceRate> siteAllowances;

  /// Day types picked by the user for office and home-office days
  /// (`days` table, data-model §12). Other types come from trips and
  /// absences (§15).
  final Map<LocalDate, DayType> dayChoices;

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
    this.specialHolidayHours = 0,
    this.nightHours = 0,
    this.tripProjectId,
    this.type,
    this.creditRule,
    this.serviceTrip = false,
    this.absenceCredit = 0,
    this.scheduled = 0,
    this.halfDay = false,
  });

  /// Whether a service trip touches this day (§9).
  final bool serviceTrip;

  /// Whether this day earns the flat supplement of a service trip: a day of
  /// a service trip that is no Sunday and no public holiday (§9, "35 % days").
  bool get servicePayDay =>
      serviceTrip &&
      tripDayType != TripDayType.sunday &&
      tripDayType != TripDayType.holiday;

  /// The §9 rule the credited time follows (trip days, Saturdays, Sundays
  /// and holidays), or `null` when the effective worked time counts as is.
  final TripDayType? creditRule;

  /// The day type (§15), or `null` for a day without work, trip, absence
  /// or choice.
  final DayType? type;

  /// The evaluated day.
  final LocalDate date;

  /// Attendance and project time (§2, §3).
  final DayWork work;

  /// Break check and effective worked time (§4).
  final BreakEvaluation breaks;

  /// Target `T(D)` (§7).
  final int target;

  /// `T_sched(D)`: the schedule's minutes for the weekday, before holidays,
  /// half days and absences (§7).
  final int scheduled;

  /// Whether D is Heiligabend or Silvester counted as a half day (§6.1).
  final bool halfDay;

  /// Credited time `Cr(D)` including absence credit (§8, §9).
  final int credited;

  /// The part of [credited] from vacation, sick and special-leave absences
  /// (§8).
  final int absenceCredit;

  /// Sunday and holiday hours for HR (§9): reported separately, not part of
  /// [credited] or the balance.
  final int sundayHours;

  /// Sunday hours of a special holiday (§21.1), reported instead of
  /// [sundayHours].
  final int specialHolidayHours;

  /// Night hours (§21.2): work in a night of at least 2 h, the part on this
  /// day. Left out of [credited] with [NightWorkCredit.exclude].
  final int nightHours;

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
    final trips = tripsOn(date);
    final tripType = trips.isEmpty ? null : type;
    final service = trips.any((t) => t.service);
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
    final night = nightHours(date);
    // §21.2: excluded night hours are no basis for the credit.
    final basis = settings.travel.night == NightWorkCredit.exclude
        ? (breaks.effectiveWorked - night).clamp(0, breaks.effectiveWorked)
        : breaks.effectiveWorked;
    final sundayHours = ruleType == null
        ? 0
        : tripSundayHours(
            type: ruleType,
            effectiveWorked: breaks.effectiveWorked,
            rules: settings.travel,
          );
    final special = settings.travel.isSpecialDay(date);
    final base = ruleType == null
        ? basis
        : tripDayCredit(
            type: ruleType,
            target: target,
            effectiveWorked: basis,
            travelWorked: work.workedAt(WorkLocation.travel),
            service: service,
            rules: settings.travel,
          );
    final scheduled = targets.scheduledMinutes(date);
    final absence = absenceCredit(absences, target, scheduled: scheduled);
    return DayResult(
      date: date,
      work: work,
      breaks: breaks,
      target: target,
      scheduled: scheduled,
      halfDay: holidays.isHalfDay(date),
      credited: base + absence,
      absenceCredit: absence,
      tripDayType: tripType,
      creditRule: ruleType,
      serviceTrip: service,
      type: _dayType(date, work, absences, isTripDay: tripType != null),
      tripProjectId: trips.map((t) => t.projectId).nonNulls.firstOrNull,
      sundayHours: special ? 0 : sundayHours,
      specialHolidayHours: special ? sundayHours : 0,
      nightHours: night,
      absences: absences,
      warnings: arbzgWarnings(
        working: work.working,
        breaks: breaks,
        previousDay: _dayWork(date.addDays(-1)).working,
        isSundayOrHoliday: isHoliday || date.weekday == DateTime.sunday,
      ),
    );
  });

  /// Night hours of [date] (§21.2): the parts of the nights of the day
  /// before and of [date] that hold at least 2 h of work.
  int nightHours(LocalDate date) {
    int part(LocalDate day, LocalDate night) =>
        _dayWork(day).working.intersect(SpanSet([_night(night)])).length;
    int counting(LocalDate night, LocalDate day) {
      final total = part(night, night) + part(night.addDays(1), night);
      return total >= _nightWorkMin ? part(day, night) : 0;
    }

    final yesterday = date.addDays(-1);
    return counting(yesterday, date) + counting(date, date);
  }

  /// At least this much work makes a night count (§21.2).
  static const _nightWorkMin = 120;

  /// The night from [date] 23:00 to the next day 06:00, local (§21.2).
  Span _night(LocalDate date) => Span(
    epochMinute(zone.instantAt(date, 23, 0)),
    epochMinute(zone.instantAt(date.addDays(1), 6, 0)),
  );

  /// Whether [date] counts in the overtime balance (on or after the balance
  /// start, §8). Earlier days show no target or difference.
  bool inBalance(LocalDate date) => !date.isBefore(settings.balanceStart);

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

  /// The balance month by month from the balance start through [date],
  /// oldest first, in one pass (§8): each month's change and its closing
  /// balance. The month of the balance start opens with the starting
  /// balance; the last month ends on [date].
  List<MonthBalance> monthlyBalances(LocalDate date) {
    final months = <MonthBalance>[];
    var balance = settings.startingBalance, opening = balance;
    LocalDate? month;
    for (var d = settings.balanceStart; !d.isAfter(date); d = d.addDays(1)) {
      if (month != null && d.startOfMonth != month) {
        months.add(MonthBalance(month, balance - opening, balance));
        opening = balance;
      }
      month = d.startOfMonth;
      balance += day(d).delta;
    }
    if (month != null) {
      months.add(MonthBalance(month, balance - opening, balance));
    }
    return months;
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
  /// §15: a full-day absence, else a trip, else the user's choice, else the
  /// main location of the work, else a part-day absence.
  DayType? _dayType(
    LocalDate date,
    DayWork work,
    List<Absence> absences, {
    required bool isTripDay,
  }) {
    DayType? absenceType({required bool fullDay}) {
      for (final a in absences) {
        final type = DayType.ofAbsence(a.kind);
        if (type != null && (!fullDay || a.fraction >= 1)) return type;
      }
      return null;
    }

    final full = absenceType(fullDay: true);
    if (full != null) return full;
    if (isTripDay) return DayType.businessTrip;
    final choice = data.dayChoices[date];
    if (choice != null) return choice;
    if (work.worked > 0) {
      final home = work.workedAt(WorkLocation.home);
      return home * 2 > work.worked ? DayType.home : DayType.office;
    }
    return absenceType(fullDay: false);
  }

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

/// One month of the overtime balance (calculations.md §8).
final class MonthBalance {
  /// Creates a month's entry.
  const MonthBalance(this.month, this.change, this.closing);

  /// The first day of the month.
  final LocalDate month;

  /// Σ Δ over the month's counted days.
  final int change;

  /// The balance at the end of the month's last counted day.
  final int closing;
}
