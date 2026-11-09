import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timetrack_core/timetrack_core.dart';

import '../../app/format.dart';
import '../../app/providers.dart';

/// The year-end balance still to settle (calculations §20.2); `null` when off
/// or nothing is open.
final balanceCarryProvider = Provider<BalanceCarryOver?>((ref) {
  final months = ref.watch(settingsProvider).balanceCarryDeadlineMonths;
  return balanceCarryOver(ref.watch(ledgerProvider), months: months);
});

/// The key that hides the card after the deadline (in `dismissed_notices`).
String balanceCarryKey(BalanceCarryOver c) => '${c.deadline}/balanceCarry';

/// Carried-over vacation not yet taken or planned (calculations §10.2).
final vacationCarryProvider = Provider<({double open, LocalDate deadline})?>((
  ref,
) {
  final settings = ref.watch(settingsProvider);
  final today = ref.watch(todayProvider);
  return vacationCarryLeft(
    carryOver: settings.number(SettingKeys.vacationCarryOver(today.year)) ?? 0,
    months: settings.vacationCarryDeadlineMonths,
    targets: ref.watch(ledgerProvider).targets,
    absences: ref.watch(ledgerDataProvider).absences,
    today: today,
  );
});

/// "Übertrag 31.12.: +42:00 – noch 30:00 bis 31.3. abbauen" (§20.2).
class BalanceCarryCard extends ConsumerWidget {
  /// Creates the card.
  const BalanceCarryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(balanceCarryProvider);
    if (c == null) return const SizedBox.shrink();
    final key = balanceCarryKey(c);
    if (c.expired && ref.watch(dismissedNoticesProvider).contains(key)) {
      return const SizedBox.shrink();
    }
    final l = context.l10n;
    final open = formatMinutes(c.open.abs());
    final deadline = context.date(c.deadline);
    final text = c.expired
        ? l.carryExpired(deadline, open)
        : c.open > 0
        ? l.carryReduce(open, deadline)
        : l.carryWorkOff(open, deadline);
    return _CarryCard(
      icon: Icons.history_toggle_off,
      title: l.carryTitle('${c.year - 1}', signedBalance(c.carry)),
      text: text,
      warn: c.expired,
      onDismiss: c.expired
          ? () => ref.read(repositoryProvider).write('dismissed_notices', key, {
              'date': '${c.deadline}',
              'deleted': false,
            })
          : null,
    );
  }
}

/// "Resturlaub aus 2026: noch 3 Tage bis 31.3. verplanen" (§10.2).
class VacationCarryCard extends ConsumerWidget {
  /// Creates the card.
  const VacationCarryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final left = ref.watch(vacationCarryProvider);
    if (left == null) return const SizedBox.shrink();
    final l = context.l10n;
    return _CarryCard(
      icon: Icons.beach_access_outlined,
      title: l.vacationCarryTitle('${left.deadline.year - 1}'),
      text: l.vacationCarryText(
        context.days(left.open),
        context.date(left.deadline),
      ),
    );
  }
}

class _CarryCard extends StatelessWidget {
  const _CarryCard({
    required this.icon,
    required this.title,
    required this.text,
    this.warn = false,
    this.onDismiss,
  });

  final IconData icon;
  final String title;
  final String text;
  final bool warn;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: warn ? scheme.errorContainer : null,
      child: ListTile(
        leading: Icon(icon, color: warn ? scheme.onErrorContainer : null),
        title: Text(title),
        subtitle: Text(text),
        trailing: onDismiss == null
            ? null
            : IconButton(
                icon: const Icon(Icons.close),
                tooltip: context.l10n.hideNotice,
                onPressed: onDismiss,
              ),
      ),
    );
  }
}
