import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:timetrack_core/timetrack_core.dart';

import '../app/theme.dart';

/// Today as an open arc from the first clock-in to the 10-hour limit
/// (navigation.md "Today"): worked time, breaks and gaps in between, a tick
/// where the target is (or will be) reached and a dot for now.
///
/// All instants are minutes since the epoch.
class DayArc extends StatelessWidget {
  /// Creates the arc.
  const DayArc({
    super.key,
    required this.working,
    required this.start,
    required this.end,
    required this.child,
    this.targetAt,
    this.now,
    this.color,
    this.startLabel,
    this.endLabel,
    this.size = 220,
  });

  /// The worked spans of the day.
  final List<Span> working;

  /// Where the scale starts: the first clock-in.
  final int start;

  /// Where the scale ends: the 10-hour limit.
  final int end;

  /// Where the target is reached, or `null` without a target.
  final int? targetAt;

  /// The current minute while clocked in, else `null`.
  final int? now;

  /// Colour of the worked spans.
  final Color? color;

  /// Under the start of the arc (the clock-in time).
  final String? startLabel;

  /// Under the end of the arc (when 10 hours are reached).
  final String? endLabel;

  /// Width of the arc.
  final double size;

  /// In the middle.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final reduced = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: reduced ? 1 : 0, end: 1),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      builder: (context, reveal, child) => CustomPaint(
        painter: _ArcPainter(
          working: working,
          start: start,
          end: end,
          targetAt: targetAt,
          now: now,
          reveal: reveal,
          track: scheme.surfaceContainerHighest,
          gap: scheme.tertiary,
          color: color ?? scheme.primary,
          tick: scheme.onSurface,
          surface: scheme.surfaceContainerLow,
        ),
        child: child,
      ),
      child: SizedBox(
        width: size,
        height: size * 0.86,
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.only(top: size * 0.08),
                child: Center(child: child),
              ),
            ),
            for (final (label, alignment) in [
              (startLabel, Alignment.bottomLeft),
              (endLabel, Alignment.bottomRight),
            ])
              if (label != null)
                Align(
                  alignment: alignment,
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  _ArcPainter({
    required this.working,
    required this.start,
    required this.end,
    required this.targetAt,
    required this.now,
    required this.reveal,
    required this.track,
    required this.gap,
    required this.color,
    required this.tick,
    required this.surface,
  });

  final List<Span> working;
  final int start, end;
  final int? targetAt, now;
  final double reveal;
  final Color track, gap, color, tick, surface;

  // 240°, open at the bottom.
  static const _from = math.pi * 5 / 6;
  static const _sweep = math.pi * 4 / 3;
  static const _stroke = 14.0;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.width / 2 - _stroke;
    final centre = Offset(size.width / 2, size.width / 2);
    final rect = Rect.fromCircle(center: centre, radius: radius);
    final length = math.max(1, end - start);
    // The reveal draws the day from its start, once on mount.
    final visibleEnd = start + (length * reveal).round();
    double angle(int minute) =>
        _from + _sweep * ((minute - start) / length).clamp(0.0, 1.0);
    Paint stroke(Color c, {StrokeCap cap = StrokeCap.round}) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeCap = cap;
    void segment(int from, int to, Paint p) {
      final b = math.min(to, visibleEnd);
      if (b <= from) return;
      canvas.drawArc(rect, angle(from), angle(b) - angle(from), false, p);
    }

    canvas.drawArc(rect, _from, _sweep, false, stroke(track));
    if (working.isEmpty) return;
    // Breaks and gaps between the first start and the last end (or now).
    final last = now ?? working.last.end;
    segment(
      working.first.start,
      last,
      stroke(gap, cap: StrokeCap.butt)..strokeWidth = _stroke / 3,
    );
    for (final s in working) {
      segment(s.start, s.end, stroke(color));
    }
    if (targetAt case final t? when t <= end) {
      final a = angle(t);
      final dir = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(
        centre + dir * (radius - _stroke),
        centre + dir * (radius + _stroke),
        Paint()
          ..color = tick
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
    }
    if (now case final n? when reveal >= 1) {
      final a = angle(n);
      final p = centre + Offset(math.cos(a), math.sin(a)) * radius;
      canvas.drawCircle(p, _stroke / 2 + 3, Paint()..color = surface);
      canvas.drawCircle(p, _stroke / 2, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.reveal != reveal ||
      old.start != start ||
      old.end != end ||
      old.targetAt != targetAt ||
      old.now != now ||
      old.color != color ||
      old.track != track ||
      !_sameSpans(old.working, working);

  static bool _sameSpans(List<Span> a, List<Span> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].start != b[i].start || a[i].end != b[i].end) return false;
    }
    return true;
  }
}

/// The scale and markers of [day] (today) for a [DayArc], or `null` when
/// nothing is worked yet (navigation.md "Today").
({int start, int end, int? targetAt, int? now})? dayArcScale(
  DayResult day, {
  required int nowMinute,
  required bool clockedIn,
  int runningBreak = 0,
}) {
  final spans = day.work.working.spans;
  if (spans.isEmpty) return null;
  final start = spans.first.start;
  final last = clockedIn ? nowMinute : spans.last.end;
  final gaps = (last - start) - day.work.worked;
  final forecast = clockedIn
      ? dayForecast(
          day,
          now: instantOfEpochMinute(nowMinute),
          runningBreak: runningBreak,
        )
      : null;
  final limit = forecast?.limitAt;
  final end = math.max(
    last,
    limit != null ? epochMinute(limit) : start + 600 + gaps,
  );
  int? targetAt;
  if (day.target > 0 && !day.isTripDay) {
    if (forecast?.targetAt case final t?) {
      targetAt = epochMinute(t);
    } else {
      // Reached already: the minute the worked time got there. Not reached
      // and clocked out: where it would be at that pace.
      var sum = 0;
      for (final s in spans) {
        if (sum + s.length >= day.target) {
          targetAt = s.start + (day.target - sum);
          break;
        }
        sum += s.length;
      }
      targetAt ??= last + (day.target - sum);
    }
  }
  return (
    start: start,
    end: end,
    targetAt: targetAt,
    now: clockedIn ? nowMinute : null,
  );
}

/// The colour of today's worked time: [SemanticColors.positive] once the
/// target is reached.
Color dayArcColor(ColorScheme scheme, DayResult day, Color base) =>
    day.target > 0 && day.breaks.effectiveWorked >= day.target
    ? scheme.positive
    : base;
