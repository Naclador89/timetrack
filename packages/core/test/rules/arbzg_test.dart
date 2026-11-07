// spec: calculations.md §4, §5
import 'package:test/test.dart';
import 'package:timetrack_core/timetrack_core.dart';

int m(String hhmm) {
  final p = hhmm.split(':');
  return int.parse(p[0]) * 60 + int.parse(p[1]);
}

/// Working intervals from `HH:MM-HH:MM` strings on one day (minute 0 = 00:00).
SpanSet work(List<String> ranges) => SpanSet([
  for (final r in ranges) Span(m(r.split('-')[0]), m(r.split('-')[1])),
]);

BreakEvaluation deduct(List<String> ranges) =>
    evaluateBreaks(work(ranges), mode: BreakRuleMode.deduct);

void main() {
  group('§4 required break', () {
    test('thresholds: 0 up to 6 h, 30 up to 9 h, 45 above', () {
      expect(requiredBreakMinutes(360), 0);
      expect(requiredBreakMinutes(361), 30);
      expect(requiredBreakMinutes(540), 30);
      expect(requiredBreakMinutes(541), 45);
    });

    test('§4 ArbZG: 6:01 h without break → 30 min missing', () {
      final result = evaluateBreaks(work(['08:00-14:01']));
      expect(result.worked, 361);
      expect(result.missingBreak, 30);
      expect(result.effectiveWorked, 361); // warn mode deducts nothing
    });

    test('gaps under 15 min don\'t count; two 15-min breaks do', () {
      expect(
        evaluateBreaks(work(['08:00-11:00', '11:10-15:00'])).countableBreak,
        0,
      );
      final twoBreaks = evaluateBreaks(
        work(['08:00-11:00', '11:15-13:00', '13:15-16:00']),
      );
      expect(twoBreaks.countableBreak, 30);
      expect(twoBreaks.missingBreak, 0);
    });

    test('time between clock-out and clock-in counts as a break', () {
      // Same SpanSet whether the gap came from a break or two sessions.
      expect(
        evaluateBreaks(work(['08:00-12:00', '12:30-17:00'])).missingBreak,
        0,
      );
    });
  });

  group('§4 deduct mode (examples table)', () {
    test('6:00, no break → nothing deducted', () {
      expect(deduct(['08:00-14:00']).effectiveWorked, 360);
    });
    test('6:10, no break → 10 deducted → 6:00', () {
      expect(deduct(['08:00-14:10']).deduction, 10);
    });
    test('8:00 with 15 min break → 15 deducted → 7:45', () {
      final r = deduct(['08:00-12:00', '12:15-16:15']);
      expect((r.worked, r.deduction, r.effectiveWorked), (480, 15, 465));
    });
    test('9:10, no break → 30 deducted → 8:40', () {
      final r = deduct(['07:00-16:10']);
      expect((r.worked, r.deduction, r.effectiveWorked), (550, 30, 520));
    });
    test('9:30 with 30 min break → 15 deducted → 9:15', () {
      final r = deduct(['07:00-12:00', '12:30-17:00']);
      expect((r.worked, r.deduction, r.effectiveWorked), (570, 15, 555));
    });
  });

  group('§4 continuous work', () {
    test('more than 6 h in one stretch → warning', () {
      expect(
        evaluateBreaks(work(['08:00-14:30'])).workOver6hWithoutBreak,
        isTrue,
      );
    });
    test('a 15-min break splits the stretch', () {
      final r = evaluateBreaks(work(['08:00-11:00', '11:15-14:30']));
      expect(r.workOver6hWithoutBreak, isFalse);
      expect(r.longestStretch, 195);
    });
    test('short gaps don\'t split a stretch, and aren\'t counted as work', () {
      final r = evaluateBreaks(work(['08:00-11:00', '11:10-14:20']));
      expect(r.longestStretch, 370);
      expect(r.workOver6hWithoutBreak, isTrue);
    });
  });

  group('§5 other warnings', () {
    List<ArbzgWarningKind> kinds(
      SpanSet w, {
      SpanSet prev = SpanSet.empty,
      bool sunday = false,
    }) => [
      for (final x in arbzgWarnings(
        working: w,
        breaks: evaluateBreaks(w),
        previousDay: prev,
        isSundayOrHoliday: sunday,
      ))
        x.kind,
    ];

    test('a normal day has no warnings', () {
      expect(kinds(work(['08:00-12:00', '12:30-16:30'])), isEmpty);
    });

    test('§3 ArbZG: more than 10 h → over10h', () {
      expect(
        kinds(work(['07:00-12:00', '12:45-18:46'])),
        contains(ArbzgWarningKind.over10h),
      );
    });

    test('§5 ArbZG: rest under 11 h since the previous day', () {
      final yesterday = SpanSet([Span(m('14:00') - 1440, m('22:00') - 1440)]);
      final warnings = arbzgWarnings(
        working: work(['08:00-12:00']),
        breaks: evaluateBreaks(work(['08:00-12:00'])),
        previousDay: yesterday,
      );
      expect(warnings, [
        const ArbzgWarning(ArbzgWarningKind.restUnder11h, 600),
      ]);
      final restedEnough = SpanSet([
        Span(m('14:00') - 1440, m('21:00') - 1440),
      ]);
      expect(kinds(work(['08:00-12:00']), prev: restedEnough), isEmpty);
    });

    test('§9 ArbZG: work on Sundays or holidays is reported', () {
      expect(kinds(work(['10:00-12:00']), sunday: true), [
        ArbzgWarningKind.sundayOrHolidayWork,
      ]);
    });

    test('a day without work has no warnings', () {
      expect(kinds(SpanSet.empty, sunday: true), isEmpty);
    });
  });
}
