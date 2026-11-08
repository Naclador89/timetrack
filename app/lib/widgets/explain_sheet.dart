import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timetrack_core/timetrack_core.dart';

import '../app/format.dart';
import '../app/providers.dart';
import '../app/theme.dart';

/// Shows how the day's credited time, target and difference came about
/// (calculations.md §16), opened by tapping a day's numbers.
Future<void> showDayExplanation(
  BuildContext context,
  WidgetRef ref,
  LocalDate date,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (_) => _ExplainSheet(date: date),
);

class _ExplainSheet extends ConsumerWidget {
  const _ExplainSheet({required this.date});

  final LocalDate date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final holidays = ref.watch(holidaysProvider);
    final day = ref.watch(ledgerProvider).day(date);
    final e = explainDay(day, isHoliday: holidays.isHoliday(date));
    final holiday = holidays.holidayOn(date)?.name;
    String m(int v) => formatMinutes(v);

    final ruleText = switch (e.rule) {
      null => null,
      TripDayType.workday => l.explainTripWorkday(m(e.ruleCredit)),
      TripDayType.saturday =>
        e.notCounted > 0
            ? l.explainSaturdayCapped(m(e.ruleCredit), m(e.notCounted))
            : l.explainSaturday,
      TripDayType.sunday || TripDayType.holiday || TripDayType.dayOff =>
        e.notCounted > 0
            ? l.explainSundayNotCounted(m(e.notCounted))
            : l.explainSundayCounted,
    };
    final targetText = switch (e.targetReason) {
      TargetReason.schedule => l.explainTargetSchedule,
      TargetReason.holiday => l.explainTargetHoliday(holiday ?? ''),
      TargetReason.reduced => l.explainTargetReduced,
      TargetReason.dayOff => l.explainTargetDayOff,
    };

    Widget row(String label, String value, {String? hint, Color? color}) =>
        ListTile(
          dense: true,
          title: Text(label),
          subtitle: hint == null ? null : Text(hint),
          trailing: Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        );

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                l.explainTitle(context.longDate(date)),
                style: theme.textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: 8),
            row(l.worked, m(e.worked)),
            if (e.breakDeduction > 0)
              row(
                l.explainBreakDeducted,
                '− ${m(e.breakDeduction)}',
                hint: l.explainBreakDeductedHint,
              ),
            if (ruleText != null)
              row(l.explainRule, m(e.ruleCredit), hint: ruleText),
            if (e.absenceCredit > 0)
              row(
                l.explainAbsenceCredit,
                '+ ${m(e.absenceCredit)}',
                hint: e.absenceKinds.map(context.absenceName).join(', '),
              ),
            const Divider(),
            row(l.credited, m(e.credited)),
            row(l.target, m(e.target), hint: targetText),
            const Divider(),
            row(
              l.difference,
              m(e.delta),
              color: theme.colorScheme.deltaColor(e.delta),
              hint: e.delta == 0
                  ? l.explainDeltaZero
                  : e.delta > 0
                  ? l.explainDeltaPlus
                  : l.explainDeltaMinus,
            ),
            if (e.sundayHours > 0)
              row(l.sundayHours, m(e.sundayHours), hint: l.explainSundayHours),
          ],
        ),
      ),
    );
  }
}
