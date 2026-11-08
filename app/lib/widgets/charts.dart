import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:timetrack_core/timetrack_core.dart';

/// One slice of a [DonutChart].
typedef Slice = ({String label, int value, Color color});

/// A donut with its legend (hours per project).
class DonutChart extends StatelessWidget {
  /// Creates the chart; [center] goes in the hole.
  const DonutChart({
    super.key,
    required this.slices,
    required this.center,
    required this.format,
    this.size = 140,
  });

  /// The slices, largest first.
  final List<Slice> slices;

  /// In the middle.
  final Widget center;

  /// Formats a slice value for the legend.
  final String Function(int value) format;

  /// Diameter.
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chart = TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => CustomPaint(
        painter: _DonutPainter(
          slices,
          t,
          theme.colorScheme.surfaceContainerHighest,
        ),
        child: SizedBox.square(
          dimension: size,
          child: Center(child: child),
        ),
      ),
      child: center,
    );
    final legend = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final s in slices.take(6))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Icon(Icons.circle, size: 10, color: s.color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    s.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                Text(format(s.value), style: theme.textTheme.bodySmall),
              ],
            ),
          ),
      ],
    );
    return Row(
      children: [
        chart,
        const SizedBox(width: 16),
        Expanded(child: legend),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter(this.slices, this.progress, this.track);

  final List<Slice> slices;
  final double progress;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 18.0;
    final arc = (Offset.zero & size).deflate(stroke / 2);
    final total = slices.fold(0, (a, s) => a + s.value);
    Paint p(Color c) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawArc(arc, 0, 2 * math.pi, false, p(track));
    if (total == 0) return;
    var start = -math.pi / 2;
    const gap = 0.03;
    for (final s in slices) {
      final sweep = 2 * math.pi * s.value / total * progress;
      if (sweep > gap * 2) {
        canvas.drawArc(arc, start + gap / 2, sweep - gap, false, p(s.color));
      }
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.progress != progress || old.slices != slices;
}

/// Columns per week: credited against target (a marker line).
class WeekBars extends StatelessWidget {
  /// Creates the chart from `(label, credited, target)`.
  const WeekBars({super.key, required this.weeks, this.height = 120});

  /// The weeks.
  final List<(String, int, int)> weeks;

  /// Height of the plot.
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final max = weeks.fold(1, (a, w) => math.max(a, math.max(w.$2, w.$3)));
    return SizedBox(
      height: height + 36,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final (label, credited, target) in weeks)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    SizedBox(
                      height: height,
                      width: 40,
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.bottomCenter,
                        children: [
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: credited / max * 0.85),
                            duration: const Duration(milliseconds: 600),
                            curve: Curves.easeOutCubic,
                            builder: (_, f, _) => FractionallySizedBox(
                              heightFactor: f,
                              widthFactor: 1,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: credited >= target
                                      ? scheme.primary
                                      : scheme.primary.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ),
                          ),
                          if (target > 0)
                            Positioned(
                              bottom: height * target / max * 0.85 - 1,
                              child: Container(
                                width: 52,
                                height: 2,
                                color: scheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Narrow columns shrink the labels instead of wrapping.
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(label, style: theme.textTheme.labelSmall),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        formatMinutes(credited),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
