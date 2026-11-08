import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:timetrack_core/timetrack_core.dart';

/// A duration (`h:mm`) that counts to its new value instead of jumping.
class AnimatedMinutes extends StatelessWidget {
  /// Creates the text for [minutes].
  const AnimatedMinutes(this.minutes, {super.key, this.style, this.signed});

  /// The value.
  final int minutes;

  /// Text style.
  final TextStyle? style;

  /// Colour by sign (balances) using this function.
  final Color Function(int minutes)? signed;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(end: minutes.toDouble()),
    duration: const Duration(milliseconds: 600),
    curve: Curves.easeOutCubic,
    builder: (context, value, _) {
      final m = value.round();
      return Text(
        formatMinutes(m),
        style: signed == null ? style : style?.copyWith(color: signed!(m)),
      );
    },
  );
}

/// A short tap on the phone for clock-in, clock-out and breaks.
void tapFeedback({bool strong = false}) =>
    strong ? HapticFeedback.mediumImpact() : HapticFeedback.selectionClick();

/// A ring that fills with [value] of [total] and starts a second, brighter
/// lap for overtime.
class ProgressRing extends StatelessWidget {
  /// Creates the ring.
  const ProgressRing({
    super.key,
    required this.value,
    required this.total,
    required this.child,
    this.size = 200,
    this.color,
    this.overColor,
  });

  /// Done so far (minutes).
  final int value;

  /// The goal (minutes); 0 shows a full ring once anything is done.
  final int total;

  /// In the middle.
  final Widget child;

  /// Diameter.
  final double size;

  /// Colour of the first lap.
  final Color? color;

  /// Colour of the overtime lap.
  final Color? overColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fraction = total <= 0 ? (value > 0 ? 1.0 : 0.0) : value / total;
    return TweenAnimationBuilder<double>(
      tween: Tween(end: fraction),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      builder: (context, f, child) => CustomPaint(
        painter: _RingPainter(
          fraction: f,
          track: scheme.surfaceContainerHighest,
          color: color ?? scheme.primary,
          over: overColor ?? scheme.tertiary,
        ),
        child: SizedBox.square(
          dimension: size,
          child: Center(child: child),
        ),
      ),
      child: child,
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.fraction,
    required this.track,
    required this.color,
    required this.over,
  });

  final double fraction;
  final Color track;
  final Color color;
  final Color over;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 14.0;
    final rect = Offset.zero & size;
    final arc = rect.deflate(stroke / 2);
    Paint p(Color c) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    const start = -3.14159265 / 2;
    const full = 2 * 3.14159265;
    canvas.drawArc(arc, 0, full, false, p(track));
    final first = fraction.clamp(0.0, 1.0);
    if (first > 0) canvas.drawArc(arc, start, full * first, false, p(color));
    final extra = (fraction - 1).clamp(0.0, 1.0);
    if (extra > 0) canvas.drawArc(arc, start, full * extra, false, p(over));
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction || old.color != color || old.track != track;
}
