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
      expect(calendar.targetMinutes(d('2026-12-31')), 360);
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
      TravelRules rules = const TravelRules(),
    }) => tripDayCredit(
      type: type,
      target: target,
      effectiveWorked: travel + other,
      travelWorked: travel,
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

    test('Wed, 3 h train + 8 h on-site → exactly the target', () {
      expect(
        credit(TripDayType.workday, target: 480, travel: 180, other: 480),
        480,
      );
    });

    test('Wed, only 2 h train → still the full target', () {
      expect(credit(TripDayType.workday, target: 480, travel: 120), 480);
    });

    test('Sat, 12 h train → capped at 11 h', () {
      expect(credit(TripDayType.saturday, travel: 720), 660);
    });

    test('Sat, 4 h train + 3 h on-site → 7 h', () {
      expect(credit(TripDayType.saturday, travel: 240, other: 180), 420);
    });

    test(
      'Sat, 8 h train + 5 h on-site → the cap covers the whole day: 11 h',
      () {
        expect(credit(TripDayType.saturday, travel: 480, other: 300), 660);
      },
    );

    test(
      'Sun → nothing credited; travel + on-site are Sunday hours, max 11 h',
      () {
        expect(credit(TripDayType.sunday, travel: 360), 0);
        expect(credit(TripDayType.sunday, travel: 120, other: 180), 0);
        int sundayHours(
          TripDayType type,
          int worked, [
          TravelRules r = const TravelRules(),
        ]) => tripSundayHours(type: type, effectiveWorked: worked, rules: r);
        expect(sundayHours(TripDayType.sunday, 300), 300);
        expect(sundayHours(TripDayType.sunday, 780), 660);
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
    });

    test('rules are settings', () {
      const rules = TravelRules(
        workday: TripWorkdayCredit.actual,
        saturdayCapMinutes: 600,
        saturdayCapScope: SaturdayCapScope.travelOnly,
        holiday: TripDayRule.likeSaturday,
        dayOff: TripDayRule.likeSunday,
      );
      expect(
        credit(
          TripDayType.workday,
          target: 480,
          travel: 180,
          other: 480,
          rules: rules,
        ),
        660,
      );
      expect(credit(TripDayType.saturday, travel: 720, rules: rules), 600);
      expect(
        credit(TripDayType.saturday, travel: 480, other: 300, rules: rules),
        780,
        reason: 'travel-only scope: work counts on top of the capped travel',
      );
      expect(credit(TripDayType.holiday, travel: 180, rules: rules), 180);
      expect(credit(TripDayType.dayOff, travel: 180, rules: rules), 0);
    });
  });
}
