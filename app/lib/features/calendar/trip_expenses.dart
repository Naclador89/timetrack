import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timetrack_core/timetrack_core.dart';

import '../../app/format.dart';
import '../../app/providers.dart';
import '../../widgets/export.dart';
import '../reports/report_documents.dart';
import '../reports/report_preview.dart';

/// The expense summary of [trip] (calculations §13.5), or `null` while it
/// is open.
TripExpenses? expensesOf(WidgetRef ref, Trip trip) {
  final ledger = ref.read(ledgerProvider);
  return tripExpenses(
    trip,
    ledger: ledger,
    rates: ref.read(perDiemRatesProvider),
    meals: ref.read(tripMealsProvider),
    stops: ledger.data.tripStops,
    siteRates: ledger.data.siteAllowances,
    rules: ledger.settings.expenses,
  );
}

/// Opens the expense report of a finished [trip] with its PDF download.
Future<void> openTripExpenses(
  BuildContext context,
  WidgetRef ref,
  Trip trip,
) async {
  final e = expensesOf(ref, trip);
  if (e == null) return;
  final format = ReportFormat(
    context.l10n,
    Localizations.localeOf(context).toLanguageTag(),
    ref.read(zoneProvider),
  );
  final project = ref.read(projectByIdProvider)[trip.projectId];
  final now = ref.read(clockProvider)();
  final first = e.perDiem.first.date;
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ReportPreviewScreen(
        title: tripExpensesTitle(e, format),
        table: tripExpensesTable(e, format),
        figures: tripExpensesFigures(e, format),
        legend: tripExpensesLegend(e, format),
        numericColumns: tripExpensesNumericColumns,
        exports: [
          (
            'PDF',
            () async {
              final bytes = await tripExpensesPdf(
                e,
                format,
                project: project,
                now: now,
              );
              if (!context.mounted) return;
              await exportBytes(
                context,
                bytes,
                'Reisekostenabrechnung_${first}_'
                    '${trip.destination.isEmpty ? trip.country : trip.destination}'
                    '.pdf',
                'application/pdf',
              );
            },
          ),
        ],
      ),
    ),
  );
}

/// Today's cards for trips whose expense claim is still to be submitted
/// (calculations §13.5).
class ClaimCards extends ConsumerWidget {
  /// Creates the cards.
  const ClaimCards({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledger = ref.watch(ledgerProvider);
    final due = claimsDue(
      ledger.data.trips,
      ledger: ledger,
      rules: ledger.settings.expenses,
    );
    if (due.isEmpty) return const SizedBox.shrink();
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        for (final c in due)
          Card(
            color: c.urgent ? scheme.errorContainer : null,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.receipt_long_outlined,
                        color: c.urgent ? scheme.onErrorContainer : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          l.claimTitle(
                            c.trip.destination.isEmpty
                                ? placeLabel(TripPlace(c.trip.country))
                                : c.trip.destination,
                            context.date(c.deadline),
                          ),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => openTripExpenses(context, ref, c.trip),
                        child: Text(l.tripExpenses),
                      ),
                      FilledButton.tonal(
                        onPressed: () => ref.read(repositoryProvider).write(
                          'trips',
                          c.trip.id,
                          {'claimed_on': '${ref.read(todayProvider)}'},
                        ),
                        child: Text(l.markClaimed),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
