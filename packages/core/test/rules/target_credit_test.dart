// spec: calculations.md §7–§9
import 'package:test/test.dart';
import 'package:timetrack_core/timetrack_core.dart';

LocalDate d(String iso) => LocalDate.parse(iso);

final fullTime = WorkSchedule(
  id: 'full',
  validFrom: d('2026-01-01'),
  weekdayMinutes: [480, 480, 480, 480, 480, 0, 0],
  annualVacationDays: 30,
);
final partTime = WorkSchedule(
  id: 'part',
  validFrom: d('2026-07-01'),
  weekdayMinutes: [360, 360, 360, 360, 0, 0, 0],
);

void main() {
  group('§7 target time', () {
    final calendar = TargetCalendar(
      schedules: [partTime, fullTime],
      holidays: HolidayCalendar(FederalState.nw),
      absences: [
        Absence(
          id: 'x',
          date: d('2026-12-24'),
          kind: AbsenceKind.extraHoliday,
          fraction: 0.5,
        ),
        Absence(id: 'v', date: d('2026-12-28'), kind: AbsenceKind.vacation),
      ],
    );

    test('the schedule with the latest valid_from ≤ D applies', () {
      expect(calendar.targetMinutes(d('2026-06-30')), 480);
      expect(calendar.targetMinutes(d('2026-07-01')), 360);
      expect(calendar.scheduleOn(d('2026-07-01'))?.id, 'part');
    });

    test('before the first schedule the target is 0', () {
      expect(calendar.targetMinutes(d('2025-12-31')), 0);
    });

    test('public holidays have target 0', () {
      expect(calendar.scheduledMinutes(d('2026-12-03')), 360);
      expect(calendar.targetMinutes(d('2026-10-01')), 360);
      expect(
        calendar.targetMinutes(d('2027-01-01')),
        0,
      ); // Neujahr (Friday → 0 anyway)
      // Silvester is no holiday, but a half day by default (§6.1).
      expect(calendar.targetMinutes(d('2026-12-31')), 180);
      expect(
        TargetCalendar(
          schedules: [fullTime],
          holidays: HolidayCalendar(FederalState.nw),
        ).targetMinutes(d('2026-12-25')),
        0,
      ); // Friday, holiday
    });

    test('extra_holiday reduces the target; vacation does not', () {
      expect(calendar.targetMinutes(d('2026-12-24')), 180);
      expect(calendar.targetMinutes(d('2026-12-28')), 360);
    });

    test('§6.1 Heiligabend and Silvester are half days; off by setting', () {
      TargetCalendar targets({
        bool half = true,
        List<Absence> off = const [],
      }) => TargetCalendar(
        schedules: [fullTime],
        holidays: HolidayCalendar(
          FederalState.nw,
          options: HolidayOptions(halfDayEves: half),
        ),
        absences: off,
      );
      // Thu 24 and Thu 31 Dec 2026.
      for (final eve in [d('2026-12-24'), d('2026-12-31')]) {
        expect(targets().targetMinutes(eve), 240);
        expect(targets().workShare(eve), 0.5);
        expect(targets(half: false).targetMinutes(eve), 480);
      }
      expect(
        targets().holidays.halfDayOn(d('2026-12-24'))?.name,
        'Heiligabend',
      );
      expect(targets().holidays.halfDayOn(d('2026-12-23')), isNull);
      // A day off on top takes the rest; half a day off is that very half.
      Absence extra(double f) => Absence(
        id: 'x$f',
        date: d('2026-12-24'),
        kind: AbsenceKind.extraHoliday,
        fraction: f,
      );
      expect(targets(off: [extra(1)]).targetMinutes(d('2026-12-24')), 0);
      expect(targets(off: [extra(0.5)]).targetMinutes(d('2026-12-24')), 240);
    });

    test('§10 a day uses at most what is left to work', () {
      final targets = TargetCalendar(
        schedules: [fullTime],
        holidays: HolidayCalendar(FederalState.nw),
        absences: [
          Absence(
            id: 'x',
            date: d('2026-11-04'),
            kind: AbsenceKind.extraHoliday,
            fraction: 0.5,
          ),
        ],
      );
      expect(targets.usedDays(d('2026-11-03'), 1), 1);
      expect(targets.usedDays(d('2026-11-04'), 1), 0.5);
      expect(targets.usedDays(d('2026-12-24'), 1), 0.5);
      expect(targets.usedDays(d('2026-12-24'), 0.5), 0.5);
      expect(targets.usedDays(d('2026-12-25'), 1), 0); // holiday
      expect(targets.usedDays(d('2026-11-08'), 1), 0); // Sunday
    });

    test('weekend and days without schedule minutes are not workdays', () {
      expect(calendar.isWorkday(d('2026-11-07')), isFalse);
      expect(calendar.isWorkday(d('2026-11-06')), isFalse); // part-time Friday
      expect(calendar.isWorkday(d('2026-11-05')), isTrue);
    });
  });

  group('§8 absence credit', () {
    Absence a(AbsenceKind kind, [double f = 1]) =>
        Absence(id: kind.name, date: d('2026-11-04'), kind: kind, fraction: f);

    test('vacation, sick and special leave credit fraction × target', () {
      expect(absenceCredit([a(AbsenceKind.vacation)], 480), 480);
      expect(absenceCredit([a(AbsenceKind.sick, 0.5)], 480), 240);
      expect(absenceCredit([a(AbsenceKind.specialLeave)], 480), 480);
    });

    test('a fraction is a share of the scheduled day, at most T(D)', () {
      // Heiligabend: T = 240 of 480. Half a day of vacation covers it.
      expect(
        absenceCredit([a(AbsenceKind.vacation, 0.5)], 240, scheduled: 480),
        240,
      );
      expect(
        absenceCredit([a(AbsenceKind.vacation)], 240, scheduled: 480),
        240,
      );
      expect(
        absenceCredit([a(AbsenceKind.sick, 0.25)], 240, scheduled: 480),
        120,
      );
    });

    test('comp time gives no credit', () {
      expect(absenceCredit([a(AbsenceKind.compTime)], 480), 0);
    });

    test('several absences add up to at most the target', () {
      expect(
        absenceCredit([a(AbsenceKind.vacation), a(AbsenceKind.sick)], 480),
        480,
      );
      expect(
        absenceCredit([
          a(AbsenceKind.vacation, 0.5),
          a(AbsenceKind.sick, 0.5),
        ], 480),
        480,
      );
    });

    test('wire names round-trip', () {
      for (final kind in AbsenceKind.values) {
        expect(AbsenceKind.parse(kind.wireName), kind);
      }
      expect(AbsenceKind.compTime.wireName, 'comp_time');
    });
  });

  group('§9 travel crediting (examples, T = 480 Mon–Fri)', () {
    int credit(
      TripDayType type, {
      int target = 0,
      required int travel,
      int other = 0,
      bool service = false,
      TravelRules rules = const TravelRules(),
    }) => tripDayCredit(
      type: type,
      target: target,
      effectiveWorked: travel + other,
      travelWorked: travel,
      service: service,
      rules: rules,
    );

    test('day types: holiday first, then weekend, then workday / day off', () {
      expect(
        tripDayType(d('2026-12-25'), isHoliday: true, target: 0),
        TripDayType.holiday,
      );
      expect(
        tripDayType(d('2026-11-08'), isHoliday: false, target: 0),
        TripDayType.sunday,
      );
      expect(
        tripDayType(d('2026-11-07'), isHoliday: false, target: 0),
        TripDayType.saturday,
      );
      expect(
        tripDayType(d('2026-11-04'), isHoliday: false, target: 480),
        TripDayType.workday,
      );
      expect(
        tripDayType(d('2026-11-06'), isHoliday: false, target: 0),
        TripDayType.dayOff,
      );
    });

    // The examples agreed with the user on 2026-11-09 (§9 table).
    test('service trip, workday: exactly the target, however long', () {
      int wed({int travel = 0, int other = 0}) => credit(
        TripDayType.workday,
        target: 480,
        travel: travel,
        other: other,
        service: true,
      );
      expect(wed(travel: 60, other: 120), 480, reason: '2 h on site + 1 h');
      expect(wed(travel: 180), 480, reason: '3 h travel only');
      expect(wed(travel: 120, other: 420), 480, reason: '7 h office + 2 h');
      expect(wed(), 480, reason: 'a trip day without work');
      expect(wed(travel: 180, other: 480), 480);
    });

    test('other trip, workday: the real time, at most 10 h', () {
      int wed({int travel = 0, int other = 0}) => credit(
        TripDayType.workday,
        target: 480,
        travel: travel,
        other: other,
      );
      expect(wed(travel: 60, other: 120), 180);
      expect(wed(travel: 180), 180);
      expect(wed(travel: 120, other: 420), 540);
      expect(wed(), 0);
      expect(wed(travel: 300, other: 420), 600);
    });

    test('Saturday: at most 8 h on a service trip, else at most 10 h', () {
      expect(
        credit(TripDayType.saturday, travel: 120, other: 180, service: true),
        300,
      );
      expect(credit(TripDayType.saturday, travel: 720, service: true), 480);
      expect(
        credit(TripDayType.saturday, travel: 360, other: 360, service: true),
        480,
      );
      expect(credit(TripDayType.saturday, travel: 120, other: 180), 300);
      expect(credit(TripDayType.saturday, travel: 720), 600);
      expect(
        credit(TripDayType.saturday, travel: 360, other: 360),
        600,
        reason: 'the cap covers the whole day',
      );
    });

    test(
      'Sun → nothing credited; travel + on-site are Sunday hours, max 12 h',
      () {
        expect(credit(TripDayType.sunday, travel: 360, service: true), 0);
        expect(credit(TripDayType.sunday, travel: 120, other: 180), 0);
        int sundayHours(
          TripDayType type,
          int worked, [
          TravelRules r = const TravelRules(),
        ]) => tripSundayHours(type: type, effectiveWorked: worked, rules: r);
        expect(sundayHours(TripDayType.sunday, 300), 300);
        expect(sundayHours(TripDayType.sunday, 780), 720);
        expect(sundayHours(TripDayType.saturday, 300), 0);
        expect(sundayHours(TripDayType.workday, 300), 0);
        expect(
          sundayHours(TripDayType.holiday, 300),
          300,
          reason: 'like Sunday',
        );
        expect(
          sundayHours(
            TripDayType.sunday,
            780,
            const TravelRules(sundayCapMinutes: 600),
          ),
          600,
        );
        expect(
          sundayHours(
            TripDayType.sunday,
            300,
            const TravelRules(sunday: TripSundayCredit.workOnly),
          ),
          0,
        );
      },
    );

    test('Sun with work_only: travel 0, on-site work credited', () {
      const rules = TravelRules(sunday: TripSundayCredit.workOnly);
      expect(credit(TripDayType.sunday, travel: 360, rules: rules), 0);
      expect(
        credit(TripDayType.sunday, travel: 120, other: 180, rules: rules),
        180,
      );
    });

    test('holiday like Sunday, day off like Saturday', () {
      expect(credit(TripDayType.holiday, travel: 180, other: 120), 0);
      expect(credit(TripDayType.dayOff, travel: 180), 180);
      expect(credit(TripDayType.dayOff, travel: 720, service: true), 480);
    });

    test('rules are settings', () {
      const rules = TravelRules(
        serviceSaturdayCapMinutes: 540,
        dayCapMinutes: 660,
        holiday: TripDayRule.likeSaturday,
        dayOff: TripDayRule.likeSunday,
      );
      expect(
        credit(TripDayType.workday, target: 480, travel: 720, rules: rules),
        660,
      );
      expect(
        credit(TripDayType.saturday, travel: 720, service: true, rules: rules),
        540,
      );
      expect(credit(TripDayType.holiday, travel: 180, rules: rules), 180);
      expect(credit(TripDayType.dayOff, travel: 180, rules: rules), 0);
    });
  });
}
