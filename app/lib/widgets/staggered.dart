import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// The app's entrance motion: cards fade in and rise a little, one after
/// the other (docs/specs/navigation.md, "Motion").
extension StaggerIn on List<Widget> {
  /// Wraps each widget in its entrance animation, [step] apart. It plays
  /// once, when a card first appears; rebuilds (the ticking clock, a sync)
  /// keep it still. With reduced motion the cards simply are there.
  List<Widget> staggered(
    BuildContext context, {
    Duration step = const Duration(milliseconds: 50),
  }) {
    if (MediaQuery.disableAnimationsOf(context)) return this;
    final seen = <Type, int>{};
    return [
      for (final (i, w) in indexed)
        w
            .animate(
              // A card that appears later (a notice above the others) gets
              // its own animation instead of taking over a neighbour's.
              key: ValueKey(
                w.key ??
                    (
                      w.runtimeType,
                      seen.update(
                        w.runtimeType,
                        (n) => n + 1,
                        ifAbsent: () => 0,
                      ),
                    ),
              ),
              delay: step * i.clamp(0, 8),
            )
            .fadeIn(duration: 250.ms, curve: Curves.easeOutCubic)
            .slideY(
              begin: 0.08,
              end: 0,
              duration: 250.ms,
              curve: Curves.easeOutCubic,
            ),
    ];
  }
}
