import 'package:test/test.dart';
import 'package:timetrack_core/timetrack_core.dart';

/// Shorthand: a span from hours/minutes on an arbitrary day (minute 0 = 00:00).
Span s(String from, String to) => Span(_m(from), _m(to));
int _m(String hhmm) {
  final p = hhmm.split(':');
  return int.parse(p[0]) * 60 + int.parse(p[1]);
}

void main() {
  group('Span', () {
    test('rejects end before start', () {
      expect(() => Span(10, 9), throwsArgumentError);
    });

    test(
      'truncates instants to the full minute (spec: calculations.md §1)',
      () {
        final span = Span.fromInstants(
          DateTime.utc(2026, 11, 7, 8, 0, 59),
          DateTime.utc(2026, 11, 7, 9, 30, 1),
        );
        expect(span.length, 90);
        expect(instantOfEpochMinute(span.start), DateTime.utc(2026, 11, 7, 8));
      },
    );

    test('intersect', () {
      expect(
        s('08:00', '12:00').intersect(s('11:00', '13:00')),
        s('11:00', '12:00'),
      );
      expect(s('08:00', '12:00').intersect(s('12:00', '13:00')), isNull);
    });
  });

  group('SpanSet (spec: calculations.md §2)', () {
    test('merges overlapping, touching and duplicate spans', () {
      final set = SpanSet([
        s('11:30', '17:00'),
        s('08:00', '12:00'),
        s('08:00', '12:00'),
        s('17:00', '18:00'),
        s('20:00', '20:00'),
      ]);
      expect(set.spans, [s('08:00', '18:00')]);
      expect(set.length, 600);
    });

    test('example §2: two overlapping sessions minus one break → 510 min', () {
      final sessions = SpanSet([s('08:00', '12:00'), s('11:30', '17:00')]);
      final breaks = SpanSet([s('12:00', '12:30')]);
      expect(sessions.subtract(breaks).length, 510);
    });

    test(
      'subtract handles cuts at edges, inside and spanning several spans',
      () {
        final base = SpanSet([s('08:00', '10:00'), s('11:00', '13:00')]);
        expect(
          base
              .subtract(
                SpanSet([
                  s('07:00', '08:30'),
                  s('09:00', '09:15'),
                  s('09:45', '11:30'),
                ]),
              )
              .spans,
          [s('08:30', '09:00'), s('09:15', '09:45'), s('11:30', '13:00')],
        );
        expect(base.subtract(SpanSet.empty).spans, base.spans);
        expect(base.subtract(SpanSet([s('00:00', '23:59')])).isEmpty, isTrue);
      },
    );

    test('intersect and union', () {
      final a = SpanSet([s('08:00', '10:00'), s('11:00', '13:00')]);
      final b = SpanSet([s('09:00', '11:30'), s('12:30', '14:00')]);
      expect(a.intersect(b).spans, [
        s('09:00', '10:00'),
        s('11:00', '11:30'),
        s('12:30', '13:00'),
      ]);
      expect(a.union(b).spans, [s('08:00', '14:00')]);
    });

    test('clip to a window, e.g. a calendar day', () {
      final night = SpanSet([s('22:00', '23:59'), s('00:00', '06:00')]);
      expect(night.clip(s('00:00', '12:00')).spans, [s('00:00', '06:00')]);
    });

    test('gaps between spans', () {
      final set = SpanSet([
        s('08:00', '12:00'),
        s('12:30', '15:00'),
        s('15:10', '17:00'),
      ]);
      expect(set.gaps, [s('12:00', '12:30'), s('15:00', '15:10')]);
      expect(SpanSet.empty.gaps, isEmpty);
    });
  });
}
