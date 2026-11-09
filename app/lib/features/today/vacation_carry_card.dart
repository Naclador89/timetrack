import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timetrack_core/timetrack_core.dart';

import '../../app/format.dart';
import '../../app/providers.dart';

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
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(text),
    ),
  );
}
