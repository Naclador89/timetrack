import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timetrack_core/timetrack_core.dart';

import '../../app/format.dart';
import '../../app/providers.dart';
import 'trips_screen.dart';

/// Replaces the project times on business-trip days: travel and on-site
/// time of the day and the project they are booked to (calculations.md §3,
/// §15). Tap edits the trip.
class TripBookingCard extends ConsumerWidget {
  /// Creates the card for [date].
  const TripBookingCard({super.key, required this.date});

  /// The trip day.
  final LocalDate date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final ledger = ref.watch(ledgerProvider);
    final day = ledger.day(date);
    final trip = ledger.tripsOn(date).firstOrNull;
    final project = ref.watch(projectByIdProvider)[day.tripProjectId];
    return Card(
      child: ListTile(
        leading: const Icon(Icons.flight),
        title: Text(
          l.tripTimes(
            formatMinutes(day.work.workedAt(WorkLocation.travel)),
            formatMinutes(day.work.workedAt(WorkLocation.onSite)),
          ),
        ),
        subtitle: Text(
          [
            if (trip != null && trip.destination.isNotEmpty) trip.destination,
            project == null ? l.tripNoProject : l.tripBookedTo(project.name),
          ].join(' · '),
        ),
        trailing: const Icon(Icons.edit_outlined),
        onTap: trip == null ? null : () => showTripDialog(context, trip: trip),
      ),
    );
  }
}
