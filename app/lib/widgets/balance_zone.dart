import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timetrack_core/timetrack_core.dart';

import '../app/format.dart';
import '../app/providers.dart';
import '../app/theme.dart';

/// A dot in the colour of [balance]'s zone (calculations §20.1); nothing
/// while no limit is set.
class BalanceZoneDot extends ConsumerWidget {
  /// Creates the dot.
  const BalanceZoneDot(this.balance, {super.key, this.size = 10});

  /// The balance in minutes.
  final int balance;

  /// Diameter.
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zone = balanceZone(
      balance,
      ref.watch(settingsProvider).balanceLimits,
    );
    if (zone == null) return const SizedBox.shrink();
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final (color, label) = switch (zone) {
      BalanceZone.green => (scheme.positive, l.zoneGreen),
      BalanceZone.yellow => (scheme.warning, l.zoneYellow),
      BalanceZone.red => (scheme.error, l.zoneRed),
      BalanceZone.overLimit => (scheme.error, l.zoneOverLimit),
    };
    return Tooltip(
      message: label,
      child: Semantics(
        label: label,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            // Over the limit: a ring around the red dot.
            border: zone == BalanceZone.overLimit
                ? Border.all(color: scheme.onSurface, width: 2)
                : null,
          ),
        ),
      ),
    );
  }
}
