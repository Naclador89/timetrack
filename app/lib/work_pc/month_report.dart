import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:timetrack_core/timetrack_core.dart';

import '../app/format.dart';
import '../app/providers.dart';
import 'work_pc.dart';

/// `local_values` key: remind to report the overtime balance after a change
/// of month (work-pc.md §4); `false` switches it off.
const monthReportReminderKey = 'month_report_reminder';

/// `local_values` key: the last month reported, `YYYY-MM`.
const monthReportDoneKey = 'month_report_done';

/// `local_values` key: the month the notification was shown for.
const monthReportNotifiedKey = 'month_report_notified';

/// Whether the monthly reminder is on (default on).
final monthReportReminderProvider = FutureProvider<bool>((ref) async {
  final raw = await ref
      .watch(storeProvider)
      .transaction((tx) => tx.localValue(monthReportReminderKey));
  return raw != 'false';
});

final _monthReportDoneProvider = FutureProvider<String?>(
  (ref) => ref
      .watch(storeProvider)
      .transaction((tx) => tx.localValue(monthReportDoneKey)),
);

/// The month to report and its closing balance, or `null`: only on the work
/// PC (Windows) with the reminder on (work-pc.md §4).
final monthReportProvider = Provider<({LocalDate month, int balance})?>((ref) {
  if (ref.watch(workPcPlatformProvider) == null) return null;
  if (!(ref.watch(monthReportReminderProvider).value ?? false)) return null;
  final done = ref.watch(_monthReportDoneProvider);
  if (!done.hasValue) return null;
  final ledger = ref.watch(ledgerProvider);
  final month = monthReportDue(
    today: ref.watch(todayProvider),
    balanceStart: ledger.settings.balanceStart,
    done: done.value,
  );
  if (month == null) return null;
  final end = month.addDays(31).startOfMonth.addDays(-1);
  return (month: month, balance: ledger.balanceAtEndOf(end));
});

/// The reminder's title and text for [month] (also the notification).
({String title, String text}) monthReportTexts(
  BuildContext context,
  LocalDate month,
  int balance,
) {
  final l = context.l10n;
  final locale = Localizations.localeOf(context).toLanguageTag();
  final name = DateFormat.MMMM(locale)
      .format(DateTime(month.year, month.month));
  final end = month.addDays(31).startOfMonth.addDays(-1);
  return (
    title: l.monthReportTitle(name),
    text: l.monthReportText(context.date(end), signedBalance(balance)),
  );
}

/// Marks [month] as reported.
Future<void> markMonthReported(WidgetRef ref, LocalDate month) async {
  await ref
      .read(storeProvider)
      .transaction(
        (tx) => tx.setLocalValue(monthReportDoneKey, monthKey(month)),
      );
  ref.invalidate(_monthReportDoneProvider);
}

/// The card on Today while a month is to be reported (work-pc.md §4).
class MonthReportCard extends ConsumerWidget {
  /// Creates the card.
  const MonthReportCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final due = ref.watch(monthReportProvider);
    if (due == null) return const SizedBox.shrink();
    final l = context.l10n;
    final texts = monthReportTexts(context, due.month, due.balance);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.outbox_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    texts.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 36),
              child: Text(texts.text),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.copy, size: 18),
                  label: Text(l.copy),
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    await Clipboard.setData(
                      ClipboardData(text: signedBalance(due.balance)),
                    );
                    messenger.showSnackBar(SnackBar(content: Text(l.copied)));
                  },
                ),
                FilledButton.tonal(
                  onPressed: () => markMonthReported(ref, due.month),
                  child: Text(l.done),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
