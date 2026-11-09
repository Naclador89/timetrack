// spec: calculations.md §7–§9 (integration of all daily rules)
import 'package:test/test.dart';
import 'package:timetrack_core/timetrack_core.dart';

final berlin = HomeTimeZone();
LocalDate d(String iso) => LocalDate.parse(iso);

DateTime at(String iso, String hhmm) {
  final p = hhmm.split(':');
  return instantOfEpochMinute(
    berlin.daySpan(d(iso)).start + int.parse(p[0]) * 60 + int.parse(p[1]),
  );
}

var _ids = 0;
WorkSession work(
  String date,
  String from,
  String to, [
  WorkLocation loc = WorkLocation.office,
]) => WorkSession(
  id: 's${_ids++}',
  start: at(date, from),
  end: at(date, to),
  location: loc,
);
WorkBreak lunch(String date) => WorkBreak(
  id: 'b${_ids++}',
  start: at(date, '12:00'),
  end: at(date, '12:30'),
);
Absence off(String date, AbsenceKind kind, [double f = 1]) =>
    Absence(id: 'a${_ids++}', date: d(date), kind: kind, fraction: f);

final schedule = WorkSchedule(
  id: 'full',
  validFrom: d('2026-01-01'),
  weekdayMinutes: [480, 480, 480, 480, 480, 0, 0],
);

Ledger ledger(
  LedgerData data, {
  int startingBalance = 0,
  BreakRuleMode mode = BreakRuleMode.warn,
  String now = '2026-12-31',
}) => Ledger(
  data: data,
  zone: berlin,
  holidays: HolidayCalendar(FederalState.nw),
  settings: LedgerSettings(
    balanceStart: d('2026-11-02'),
    startingBalance: startingBalance,
    breakMode: mode,
  ),
  nowMinute: epochMinute(at(now, '23:00')),
);

void main() {
  test('§8 a week: overtime, minus hours, vacation, comp time → balance', () {
    final l = ledger(
      LedgerData(
        schedules: [schedule],
        sessions: [
          work('2026-11-02', '08:00', '17:00'), // 510 → +30
          work('2026-11-03', '08:00', '15:30'), // 420 → −60
          work('2026-11-06', '08:00', '16:30'), // 480 → 0
        ],
        breaks: [lunch('2026-11-02'), lunch('2026-11-03'), lunch('2026-11-06')],
        absences: [
          off('2026-11-04', AbsenceKind.vacation),
          off('2026-11-05', AbsenceKind.compTime),
        ],
      ),
      startingBalance: 120,
    );
    expect(
      [for (var i = 2; i <= 8; i++) l.day(d('2026-11-0$i')).delta],
      [30, -60, 0, -480, 0, 0, 0],
    );
    expect(l.balanceAtEndOf(d('2026-11-06')), 120 + 30 - 60 - 480);
    expect(l.balanceAtEndOf(d('2026-11-08')), -390);
    expect(
      l.balanceAtEndOf(d('2026-11-01')),
      120,
      reason: 'before the balance start',
    );
  });

  test('§8 half a vacation day plus 4 h of work → no difference', () {
    final l = ledger(
      LedgerData(
        schedules: [schedule],
        sessions: [work('2026-11-04', '08:00', '12:00')],
        absences: [off('2026-11-04', AbsenceKind.vacation, 0.5)],
      ),
    );
    expect(l.day(d('2026-11-04')).credited, 480);
  });

  test('§4 deduct mode lowers credited time and balance', () {
    final data = LedgerData(
      schedules: [schedule],
      sessions: [work('2026-11-04', '08:00', '14:10')],
    );
    expect(ledger(data).day(d('2026-11-04')).credited, 370);
    expect(
      ledger(data, mode: BreakRuleMode.deduct).day(d('2026-11-04')).credited,
      360,
    );
  });

  test('§4/§5 warnings use the actual times', () {
    final l = ledger(
      LedgerData(
        schedules: [schedule],
        sessions: [work('2026-11-04', '07:00', '18:00')],
      ),
    );
    final kinds = l.day(d('2026-11-04')).warnings.map((w) => w.kind);
    expect(
      kinds,
      containsAll([
        ArbzgWarningKind.breakMissing,
        ArbzgWarningKind.over10h,
        ArbzgWarningKind.workOver6hWithoutBreak,
      ]),
    );
  });

  test('§9 a trip from Friday to Monday: each day credited by its type', () {
    final l = ledger(
      LedgerData(
        schedules: [schedule],
        trips: [
          Trip(
            id: 't',
            depart: at('2026-11-13', '13:00'),
            returnAt: at('2026-11-16', '21:00'),
          ),
        ],
        sessions: [
          work('2026-11-13', '08:00', '13:00'), // office before leaving
          work('2026-11-13', '13:00', '19:00', WorkLocation.travel),
          work('2026-11-14', '09:00', '17:00', WorkLocation.onSite),
          work('2026-11-15', '15:00', '21:00', WorkLocation.travel),
          work('2026-11-16', '08:00', '17:00', WorkLocation.onSite),
          work('2026-11-16', '17:00', '21:00', WorkLocation.travel),
        ],
      ),
    );
    final fri = l.day(d('2026-11-13')), sat = l.day(d('2026-11-14'));
    final sun = l.day(d('2026-11-15')), mon = l.day(d('2026-11-16'));
    expect(
      [fri.tripDayType, sat.tripDayType, sun.tripDayType, mon.tripDayType],
      [
        TripDayType.workday,
        TripDayType.saturday,
        TripDayType.sunday,
        TripDayType.workday,
      ],
    );
    expect(
      [fri.credited, sat.credited, sun.credited, mon.credited],
      [480, 480, 0, 480],
    );
    expect(
      [fri.sundayHours, sat.sundayHours, sun.sundayHours, mon.sundayHours],
      [0, 0, 360, 0],
      reason: 'Sunday hours for HR, not in the balance',
    );
    expect(fri.work.worked, 660, reason: 'actual times are kept');
    expect([fri, sat, sun, mon].map((x) => x.servicePayDay), [
      true,
      true,
      false,
      true,
    ], reason: '35 % days: Mon–Sat of a service trip');
    expect(l.day(d('2026-11-17')).isTripDay, isFalse);
  });

  test('§9 another trip (fair, training): the real time, at most 10 h', () {
    final l = ledger(
      LedgerData(
        schedules: [schedule],
        trips: [
          Trip(
            id: 't',
            depart: at('2026-11-13', '13:00'),
            returnAt: at('2026-11-14', '20:00'),
            service: false,
          ),
        ],
        sessions: [
          work('2026-11-13', '08:00', '13:00'),
          work('2026-11-13', '13:00', '15:00', WorkLocation.travel),
          work('2026-11-14', '07:00', '20:00', WorkLocation.travel),
        ],
      ),
    );
    final fri = l.day(d('2026-11-13')), sat = l.day(d('2026-11-14'));
    expect(fri.credited, fri.breaks.effectiveWorked);
    expect(fri.credited, 420, reason: '5 h office + 2 h travel');
    expect(sat.credited, 600);
    expect([fri.servicePayDay, sat.servicePayDay], [false, false]);
  });

  test('§9 weekends and holidays follow their rule without a trip too', () {
    final l = ledger(
      LedgerData(
        schedules: [schedule],
        sessions: [
          work('2026-11-07', '06:00', '19:00'), // Sat, 13 h
          work('2026-11-08', '09:00', '14:00'), // Sun, 5 h
          work(
            '2026-12-25',
            '08:00',
            '20:30',
          ), // 1. Weihnachtstag (Fri), 12.5 h
          work('2026-11-05', '07:00', '19:00'), // Thu, 12 h, no trip
        ],
      ),
    );
    final sat = l.day(d('2026-11-07')), sun = l.day(d('2026-11-08'));
    final hol = l.day(d('2026-12-25')), thu = l.day(d('2026-11-05'));
    expect(
      [sat.isTripDay, sun.isTripDay, hol.isTripDay],
      [false, false, false],
    );
    expect((sat.credited, sat.sundayHours), (600, 0), reason: 'max 10 h');
    expect((sun.credited, sun.sundayHours), (0, 300));
    expect((hol.credited, hol.sundayHours), (0, 720), reason: 'like Sunday');
    expect(
      (thu.credited, thu.sundayHours),
      (thu.breaks.effectiveWorked, 0),
      reason: 'workday without a trip: the actual time counts',
    );
  });

  test('§9 an open trip touches every day up to now', () {
    final l = ledger(
      LedgerData(
        schedules: [schedule],
        trips: [Trip(id: 't', depart: at('2026-11-12', '06:00'))],
      ),
      now: '2026-11-13',
    );
    expect(l.day(d('2026-11-13')).isTripDay, isTrue);
    expect(l.day(d('2026-11-14')).isTripDay, isFalse);
  });

  test('today is evaluated up to now', () {
    final l = ledger(
      LedgerData(
        schedules: [schedule],
        sessions: [
          WorkSession(
            id: 'o',
            start: at('2026-11-04', '08:00'),
            location: WorkLocation.home,
          ),
        ],
      ),
      now: '2026-11-04',
    );
    expect(l.today, d('2026-11-04'));
    expect(l.day(d('2026-11-04')).work.worked, 900); // until 23:00
  });
}
