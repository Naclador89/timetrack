// spec: calculations.md §6
import 'package:test/test.dart';
import 'package:timetrack_core/timetrack_core.dart';

LocalDate d(String iso) => LocalDate.parse(iso);

Set<String> namesOn(int year, FederalState state, {HolidayOptions? options}) =>
    publicHolidays(
      year,
      state,
      options: options ?? const HolidayOptions(),
    ).map((h) => '${h.date} ${h.name}').toSet();

void main() {
  test('§6 Easter Sunday matches known dates', () {
    const known = {
      2000: '2000-04-23',
      2008: '2008-03-23',
      2011: '2011-04-24',
      2019: '2019-04-21',
      2024: '2024-03-31',
      2025: '2025-04-20',
      2026: '2026-04-05',
      2027: '2027-03-28',
      2028: '2028-04-16',
      2038: '2038-04-25',
    };
    known.forEach(
      (year, date) => expect(easterSunday(year), d(date), reason: '$year'),
    );
  });

  test(
    '§6 nationwide holidays 2026 (checked against the official calendar)',
    () {
      expect(namesOn(2026, FederalState.hh), {
        '2026-01-01 Neujahr',
        '2026-04-03 Karfreitag',
        '2026-04-06 Ostermontag',
        '2026-05-01 Tag der Arbeit',
        '2026-05-14 Christi Himmelfahrt',
        '2026-05-25 Pfingstmontag',
        '2026-10-03 Tag der Deutschen Einheit',
        '2026-10-31 Reformationstag',
        '2026-12-25 1. Weihnachtstag',
        '2026-12-26 2. Weihnachtstag',
      });
    },
  );

  test('§6 number of holidays per state in 2026', () {
    const expected = {
      FederalState.bw: 12,
      FederalState.by: 13,
      FederalState.be: 10,
      FederalState.bb: 12,
      FederalState.hb: 10,
      FederalState.hh: 10,
      FederalState.he: 10,
      FederalState.mv: 11,
      FederalState.ni: 10,
      FederalState.nw: 11,
      FederalState.rp: 11,
      FederalState.sl: 12,
      FederalState.sn: 11,
      FederalState.st: 11,
      FederalState.sh: 10,
      FederalState.th: 11,
    };
    for (final state in FederalState.values) {
      expect(
        publicHolidays(2026, state),
        hasLength(expected[state]),
        reason: state.code,
      );
    }
  });

  test('§6 Easter-based holidays 2027', () {
    final by = namesOn(2027, FederalState.by);
    expect(
      by,
      containsAll(['2027-03-26 Karfreitag', '2027-03-29 Ostermontag']),
    );
    expect(
      by,
      containsAll([
        '2027-05-06 Christi Himmelfahrt',
        '2027-05-17 Pfingstmontag',
      ]),
    );
    expect(by, contains('2027-05-27 Fronleichnam'));
    expect(
      namesOn(2027, FederalState.bb),
      containsAll(['2027-03-28 Ostersonntag', '2027-05-16 Pfingstsonntag']),
    );
  });

  test('§6 Buß- und Bettag only in Saxony, Wednesday before 23 Nov', () {
    expect(
      namesOn(2026, FederalState.sn),
      contains('2026-11-18 Buß- und Bettag'),
    );
    expect(
      namesOn(2027, FederalState.sn),
      contains('2027-11-17 Buß- und Bettag'),
    );
    // 22 Nov 2028 is itself a Wednesday.
    expect(
      namesOn(2028, FederalState.sn),
      contains('2028-11-22 Buß- und Bettag'),
    );
    expect(
      namesOn(2026, FederalState.by).any((n) => n.contains('Buß')),
      isFalse,
    );
  });

  test('§6 holidays introduced later apply only from their first year', () {
    bool has(int year, FederalState s, String name) =>
        namesOn(year, s).any((n) => n.endsWith(name));
    expect(has(2018, FederalState.be, 'Frauentag'), isFalse);
    expect(has(2019, FederalState.be, 'Frauentag'), isTrue);
    expect(has(2022, FederalState.mv, 'Frauentag'), isFalse);
    expect(has(2023, FederalState.mv, 'Frauentag'), isTrue);
    expect(has(2018, FederalState.th, 'Weltkindertag'), isFalse);
    expect(has(2019, FederalState.th, 'Weltkindertag'), isTrue);
    expect(has(2016, FederalState.ni, 'Reformationstag'), isFalse);
    expect(has(2018, FederalState.ni, 'Reformationstag'), isTrue);
  });

  test('§6 one-off holidays: Reformationstag 2017 everywhere, 8 May in Berlin 2020/2025', () {
    for (final state in FederalState.values) {
      expect(
        namesOn(2017, state),
        contains('2017-10-31 Reformationstag'),
        reason: state.code,
      );
    }
    expect(
      namesOn(2025, FederalState.be),
      contains('2025-05-08 Tag der Befreiung'),
    );
    expect(
      namesOn(2026, FederalState.be).any((n) => n.contains('Befreiung')),
      isFalse,
    );
  });

  test('§6 Mariä Himmelfahrt in Bavaria depends on the setting', () {
    expect(
      namesOn(2026, FederalState.by),
      contains('2026-08-15 Mariä Himmelfahrt'),
    );
    expect(
      namesOn(
        2026,
        FederalState.by,
        options: const HolidayOptions(bavariaAssumptionDay: false),
      ),
      isNot(contains('2026-08-15 Mariä Himmelfahrt')),
    );
    expect(
      namesOn(2026, FederalState.sl),
      contains('2026-08-15 Mariä Himmelfahrt'),
    );
  });

  test('§6 years before 1995 are rejected', () {
    expect(() => publicHolidays(1994, FederalState.by), throwsArgumentError);
  });

  test('HolidayCalendar looks up dates across years', () {
    final calendar = HolidayCalendar(FederalState.nw);
    expect(calendar.holidayOn(d('2026-11-01'))?.name, 'Allerheiligen');
    expect(calendar.isHoliday(d('2026-11-02')), isFalse);
    expect(calendar.isHoliday(d('2027-01-01')), isTrue);
  });

  test('FederalState parses codes in any case', () {
    expect(FederalState.parse('BY'), FederalState.by);
    expect(FederalState.parse('nw').code, 'NW');
    expect(() => FederalState.parse('XX'), throwsArgumentError);
  });
}
