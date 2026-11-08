import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A small line chart of [values] (e.g. the balance per day) with a zero
/// line, coloured by the last value's sign.
class Sparkline extends StatelessWidget {
  /// Creates the chart.
  const Sparkline({
    super.key,
    required this.values,
    required this.color,
    this.height = 48,
  });

  /// The points, left to right.
  final List<int> values;

  /// Line colour.
  final Color color;

  /// Height.
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    width: double.infinity,
    child: CustomPaint(
      painter: _SparkPainter(
        values,
        color,
        Theme.of(context).colorScheme.outlineVariant,
      ),
    ),
  );
}

class _SparkPainter extends CustomPainter {
  _SparkPainter(this.values, this.color, this.zero);

  final List<int> values;
  final Color color;
  final Color zero;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final lo = math.min(0, values.reduce(math.min)).toDouble();
    final hi = math.max(0, values.reduce(math.max)).toDouble();
    final range = hi - lo == 0 ? 1.0 : hi - lo;
    double y(num v) => size.height - 3 - (v - lo) / range * (size.height - 6);
    double x(int i) => i / (values.length - 1) * size.width;
    canvas.drawLine(
      Offset(0, y(0)),
      Offset(size.width, y(0)),
      Paint()
        ..color = zero
        ..strokeWidth = 1,
    );
    final path = Path()..moveTo(0, y(values.first));
    for (var i = 1; i < values.length; i++) {
      path.lineTo(x(i), y(values[i]));
    }
    final fill = Path.from(path)
      ..lineTo(size.width, y(0))
      ..lineTo(0, y(0))
      ..close();
    canvas
      ..drawPath(fill, Paint()..color = color.withValues(alpha: 0.12))
      ..drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
      )
      ..drawCircle(
        Offset(x(values.length - 1), y(values.last)),
        4,
        Paint()..color = color,
      );
  }

  @override
  bool shouldRepaint(_SparkPainter old) =>
      old.values != values || old.color != color;
}
