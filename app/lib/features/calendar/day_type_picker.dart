import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timetrack_core/timetrack_core.dart';

import '../../app/format.dart';
import '../../app/providers.dart';
import 'trips_screen.dart';

/// The nine day types as buttons (calculations.md §15), used in the day
/// editor and on Today.
class DayTypePicker extends ConsumerWidget {
  /// Creates the picker for [date]. On Today ([startsNow]), a new business
  /// trip departs now and stays open.
  const DayTypePicker({super.key, required this.date, this.startsNow = false});

  /// The day.
  final LocalDate date;

  /// Whether a new trip starts now (Today) instead of covering the day.
  final bool startsNow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final current = ref.watch(ledgerProvider).day(date).type;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final type in DayType.values)
          ChoiceChip(
            showCheckmark: false,
            avatar: Icon(dayTypeIcon(type), size: 18),
            label: Text(dayTypeLabel(l, type)),
            selected: current == type,
            onSelected: (_) =>
                pickDayType(context, ref, date, type, startsNow: startsNow),
          ),
      ],
    );
  }
}

/// Sets [type] for [date]. A business trip is created (or kept) through the
/// trip dialog; a day inside a trip can only become office or home office
/// after the trip is changed, so the user is sent to the trip instead.
Future<void> pickDayType(
  BuildContext context,
  WidgetRef ref,
  LocalDate date,
  DayType type, {
  bool startsNow = false,
}) async {
  final ledger = ref.read(ledgerProvider);
  final day = ledger.day(date);
  if (day.type == type) return;
  final repo = ref.read(repositoryProvider);
  final zone = ref.read(zoneProvider);
  final trip = ledger.tripsOn(date).firstOrNull;

  if (type == DayType.businessTrip && trip == null) {
    final spans = day.work.working.spans;
    int? local(int epochMinute) {
      final t = zone.toLocal(
        DateTime.fromMillisecondsSinceEpoch(epochMinute * 60000, isUtc: true),
      );
      return t.hour * 60 + t.minute;
    }

    final now = zone.toLocal(ref.read(clockProvider)());
    final saved = await showTripDialog(
      context,
      date: date,
      departMinutes: startsNow
          ? now.hour * 60 + now.minute
          : spans.isEmpty
          ? null
          : local(spans.first.start),
      returnMinutes: spans.isEmpty ? null : local(spans.last.end),
      openEnded: startsNow,
    );
    if (!saved) return;
  } else if (type.isWork && type != DayType.businessTrip && trip != null) {
    if (!context.mounted) return;
    final l = context.l10n;
    final edit = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        content: Text(
          l.tripDayLocked(
            trip.destination.isEmpty ? l.tripDay : trip.destination,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(l.editTrip),
          ),
        ],
      ),
    );
    if (edit == true && context.mounted) {
      await showTripDialog(context, trip: trip);
    }
    return;
  }
  await setDayType(repo, date, type, zone: zone);
}
