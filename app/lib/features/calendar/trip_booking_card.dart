import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timetrack_core/timetrack_core.dart';

import '../../app/format.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../widgets/explain_sheet.dart';
import '../../widgets/interval_dialog.dart';
import '../planner/trip_dialog.dart';

/// Icon of a trip leg.
IconData tripLegIcon(TripLegKind kind) => switch (kind) {
  TripLegKind.outbound => Icons.east,
  TripLegKind.onSite => Icons.place_outlined,
  TripLegKind.inbound => Icons.west,
};

/// The travel record of a business-trip day (calculations.md §9.1): the
/// exact times of the outbound journey, the work at the customer and the
/// way back, as they go into the travel report, kept apart from what the
/// overtime account credits for the day. Replaces project time on trip
/// days (§3, §15). Tap a leg to correct it.
class TripBookingCard extends ConsumerWidget {
  /// Creates the card for [date].
  const TripBookingCard({super.key, required this.date});

  /// The trip day.
  final LocalDate date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ledger = ref.watch(ledgerProvider);
    final zone = ref.watch(zoneProvider);
    final day = ledger.day(date);
    final trip = ledger.tripsOn(date).firstOrNull;
    final project = ref.watch(projectByIdProvider)[day.tripProjectId];
    final legs = tripLegs(ledger, date);
    final sessions = {for (final s in ledger.data.sessions) s.id: s};
    String clock(int minute) =>
        context.time(instantOfEpochMinute(minute), zone);
    String legLabel(TripLegKind k) => switch (k) {
      TripLegKind.outbound => l.legOutbound,
      TripLegKind.onSite => l.legOnSite,
      TripLegKind.inbound => l.legInbound,
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.flight,
                  color: scheme.dayTypeColor(DayType.businessTrip),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.travelRecord, style: theme.textTheme.titleSmall),
                      Text(
                        [
                          if (trip != null && trip.destination.isNotEmpty)
                            trip.destination,
                          project == null
                              ? l.tripNoProject
                              : l.tripBookedTo(project.name),
                        ].join(' · '),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (trip != null)
                  IconButton(
                    tooltip: l.editTrip,
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => showTripDialog(context, trip: trip),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            if (legs.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  l.travelRecordEmpty,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            for (final leg in legs)
              ListTile(
                dense: true,
                contentPadding: const EdgeInsets.only(right: 8),
                leading: Icon(tripLegIcon(leg.kind)),
                title: Text(legLabel(leg.kind)),
                subtitle: Text(
                  sessions[leg.sessionId]?.isOpen ?? false
                      ? '${clock(leg.span.start)} – ${l.running}'
                      : '${clock(leg.span.start)} – ${clock(leg.span.end)}',
                ),
                trailing: Text(
                  formatMinutes(leg.span.length),
                  style: theme.textTheme.titleSmall,
                ),
                onTap: () {
                  final s = sessions[leg.sessionId];
                  if (s == null) return;
                  showIntervalDialog(
                    context,
                    date: date,
                    table: 'work_sessions',
                    id: s.id,
                    start: s.start,
                    end: s.end,
                    location: s.location,
                  );
                },
              ),
            const Divider(),
            Text(
              l.tripTimes(
                formatMinutes(day.work.workedAt(WorkLocation.travel)),
                formatMinutes(day.work.workedAt(WorkLocation.onSite)),
              ),
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            // The account is a separate thing: on a workday it gets the
            // target however long the trip took (§9).
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => showDayExplanation(context, ref, date),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.account_balance_wallet_outlined,
                      size: 18,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l.accountCredits(formatMinutes(day.credited)),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.primary,
                        ),
                      ),
                    ),
                    Icon(Icons.help_outline, size: 16, color: scheme.primary),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
