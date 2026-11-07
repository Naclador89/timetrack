// spec: calculations.md §10, §11
import 'package:test/test.dart';
import 'package:timetrack_core/timetrack_core.dart';

final berlin = HomeTimeZone();
LocalDate d(String iso) => LocalDate.parse(iso);

DateTime at(LocalDate date, String hhmm) {
  final p = hhmm.split(':');
  return instantOfEpochMinute(
    berlin.daySpan(date).start + int.parse(p[0]) * 60 + int.parse(p[1]),
  );
}

var _ids = 0;
WorkSession work(
  LocalDate date,
  WorkLocation loc, [
  String from = '08:00',
  String to = '16:00',
]) => WorkSession(
  id: 's${_ids++}',
  start: at(date, from),
  end: at(date, to),
  location: loc,
);
Absence off(String date, AbsenceKind kind, [double f = 1]) =>
    Absence(id: 'a${_ids++}', date: d(date), kind: kind, fraction: f);

final schedule = WorkSchedule(
  id: 'full',
  validFrom: d('2026-01-01'),
  weekdayMinutes: [480, 480, 480, 480, 480, 0, 0],
  annualVacationDays: 30,
);

Ledger ledgerFor(LedgerData data, String today) => Ledger(
  data: data,
  zone: berlin,
  holidays: HolidayCalendar(FederalState.nw),
  settings: LedgerSettings(balanceStart: d('2026-01-01')),
  nowMinute: epochMinute(at(d(today), '20:00')),
);

/// November 2026 (NW): 21 workdays. Up to Thu 12 Nov: worked 8 of the 9
/// workdays (sick on Tue 3 Nov), 5 of them at home.
LedgerData november() {
  const home = [
    '2026-11-02',
    '2026-11-04',
    '2026-11-06',
    '2026-11-10',
    '2026-11-12',
  ];
  const office = ['2026-11-05', '2026-11-09', '2026-11-11'];
  return LedgerData(
    schedules: [schedule],
    sessions: [
      for (final x in home) work(d(x), WorkLocation.home),
      for (final x in office) work(d(x), WorkLocation.office),
    ],
    absences: [off('2026-11-03', AbsenceKind.sick)],
  );
}

void main() {
  group('§10 vacation account', () {
    final targets = TargetCalendar(
      schedules: [schedule],
      holidays: HolidayCalendar(FederalState.nw),
    );
    VacationAccount account(
      List<Absence> absences, {
      double? override,
      double carry = 0,
    }) => vacationAccount(
      year: 2026,
      targets: targets,
      schedules: [schedule],
      absences: absences,
      today: d('2026-11-07'),
      entitlementOverride: override,
      carryOver: carry,
    );

    test('taken up to today, planned after, only on workdays', () {
      final a = account([
        off('2026-08-03', AbsenceKind.vacation),
        off('2026-08-04', AbsenceKind.vacation, 0.5),
        off('2026-08-08', AbsenceKind.vacation), // Saturday: doesn't count
        off('2026-12-25', AbsenceKind.vacation), // holiday: doesn't count
        off('2026-12-28', AbsenceKind.vacation),
        off('2026-12-29', AbsenceKind.sick), // not vacation
        off('2025-12-29', AbsenceKind.vacation), // other year
      ], carry: 2);
      expect(
        (a.entitlement, a.carryOver, a.taken, a.planned),
        (30.0, 2.0, 1.5, 1.0),
      );
      expect(a.remaining, 29.5);
    });

    test(
      'entitlement: override wins; first schedule of the year if none on 1 Jan',
      () {
        expect(account([], override: 5).entitlement, 5);
        final lateStart = WorkSchedule(
          id: 'l',
          validFrom: d('2026-11-01'),
          weekdayMinutes: [480, 480, 480, 480, 480, 0, 0],
          annualVacationDays: 28,
        );
        final a = vacationAccount(
          year: 2026,
          targets: TargetCalendar(
            schedules: [lateStart],
            holidays: HolidayCalendar(FederalState.nw),
          ),
          schedules: [lateStart],
          absences: const [],
          today: d('2026-11-07'),
        );
        expect(a.entitlement, 28);
      },
    );
  });

  group('§11.1 home-office value of a day', () {
    DayResult dayWith(
      List<WorkSession> sessions, {
      List<Trip> trips = const [],
    }) => ledgerFor(
      LedgerData(schedules: [schedule], sessions: sessions, trips: trips),
      '2026-11-30',
    ).day(d('2026-11-04'));
    final wed = d('2026-11-04');

    test('majority: more than half at home; exactly half is 0', () {
      final mostlyHome = dayWith([
        work(wed, WorkLocation.home, '08:00', '13:00'),
        work(wed, WorkLocation.office, '13:00', '16:00'),
      ]);
      final half = dayWith([
        work(wed, WorkLocation.home, '08:00', '12:00'),
        work(wed, WorkLocation.office, '12:00', '16:00'),
      ]);
      expect(homeOfficeValue(mostlyHome, HomeOfficeDayRule.majority), 1);
      expect(homeOfficeValue(half, HomeOfficeDayRule.majority), 0);
      expect(homeOfficeValue(half, HomeOfficeDayRule.any), 1);
      expect(homeOfficeValue(half, HomeOfficeDayRule.proportional), 0.5);
    });

    test('trip days and days without work are never home-office days', () {
      final trip = Trip(
        id: 't',
        depart: at(wed, '12:00'),
        returnAt: at(wed, '20:00'),
      );
      expect(
        homeOfficeValue(
          dayWith([work(wed, WorkLocation.home)], trips: [trip]),
          HomeOfficeDayRule.any,
        ),
        0,
      );
      expect(homeOfficeValue(dayWith([]), HomeOfficeDayRule.any), 0);
    });
  });

  group('§11.2/§11.3 quota and forecast', () {
    final ledger = ledgerFor(november(), '2026-11-12');
    final monthly = HomeOfficeRule(
      id: 'm',
      validFrom: _jan1,
      period: QuotaPeriod.month,
      maxPercent: 40,
    );

    test(
      'spec example: 40 %/month, 8 worked (5 home), 12 workdays left → 3 left',
      () {
        final q = evaluateQuota(ledger, monthly);
        expect((q.used, q.base, q.allowedTotal, q.left), (5.0, 8.0, 8, 3.0));
        expect(q.share, 0.625);
        expect(q.nextDayExceeds, isFalse);
      },
    );

    test('basis scheduled: whole month minus absences', () {
      final rule = HomeOfficeRule(
        id: 's',
        validFrom: _jan1,
        period: QuotaPeriod.month,
        maxPercent: 40,
        basis: QuotaBasis.scheduled,
      );
      final q = evaluateQuota(ledger, rule);
      expect((q.base, q.allowedTotal, q.left), (20.0, 8, 3.0));
      expect(q.share, 0.25);
    });

    test('weekly rule: week of 9–15 Nov, 2 of 4 days at home, limit 50 %', () {
      final weekly = HomeOfficeRule(
        id: 'w',
        validFrom: _jan1,
        period: QuotaPeriod.week,
        maxPercent: 50,
      );
      final q = evaluateQuota(ledger, weekly);
      expect((q.start, q.end), (d('2026-11-09'), d('2026-11-15')));
      // 4 worked + 1 workday left (Fri 13) → floor(50 % × 5) = 2, already used.
      expect((q.used, q.allowedTotal, q.left), (2.0, 2, 0.0));
      expect(q.nextDayExceeds, isTrue, reason: '§11.4 warning');
    });

    test('unit hours: minutes at home vs minutes worked', () {
      final hours = HomeOfficeRule(
        id: 'h',
        validFrom: _jan1,
        period: QuotaPeriod.month,
        unit: QuotaUnit.hours,
        maxPercent: 40,
      );
      final q = evaluateQuota(ledger, hours);
      expect((q.used, q.base), (5 * 480.0, 8 * 480.0));
      expect(q.allowedTotal, 1536);
    });

    test(
      'the version valid on the first day of the period applies to all of it',
      () {
        final versions = [
          HomeOfficeRule(
            id: 'v1',
            validFrom: _jan1,
            period: QuotaPeriod.month,
            maxPercent: 50,
          ),
          HomeOfficeRule(
            id: 'v2',
            validFrom: d('2026-11-15'),
            period: QuotaPeriod.month,
            maxPercent: 40,
          ),
          HomeOfficeRule(
            id: 'wk',
            validFrom: _jan1,
            period: QuotaPeriod.week,
            maxPercent: 60,
          ),
        ];
        expect(
          ruleForPeriod(
            versions,
            period: QuotaPeriod.month,
            unit: QuotaUnit.days,
            periodStart: d('2026-11-01'),
          )?.id,
          'v1',
        );
        expect(
          ruleForPeriod(
            versions,
            period: QuotaPeriod.month,
            unit: QuotaUnit.days,
            periodStart: d('2026-12-01'),
          )?.id,
          'v2',
        );
        expect(
          ruleForPeriod(
            versions,
            period: QuotaPeriod.week,
            unit: QuotaUnit.hours,
            periodStart: d('2026-12-01'),
          ),
          isNull,
        );
      },
    );

    test('periods: weeks can span two months; month ends are exact', () {
      expect(periodAround(d('2026-12-02'), QuotaPeriod.week), (
        d('2026-11-30'),
        d('2026-12-06'),
      ));
      expect(periodAround(d('2028-02-10'), QuotaPeriod.month), (
        d('2028-02-01'),
        d('2028-02-29'),
      ));
      expect(periodAround(d('2026-12-31'), QuotaPeriod.month), (
        d('2026-12-01'),
        d('2026-12-31'),
      ));
    });
  });

  test('§11.5 yearly count of home-office days', () {
    expect(homeOfficeDaysInYear(ledgerFor(november(), '2026-11-12'), 2026), 5);
  });
}

final _jan1 = LocalDate(2026, 1, 1);
