import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timetrack_core/timetrack_core.dart';

import '../../app/format.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../widgets/undo.dart';
import '../planner/trip_dialog.dart';

/// The day's type as one chip ("🏠 Homeoffice ▾"); tap to pick another
/// from a sheet (calculations.md §15). Used in the day editor and on Today.
class DayTypeChip extends ConsumerWidget {
  /// Creates the chip for [date]. On Today ([startsNow]), a new business
  /// trip departs now and stays open.
  const DayTypeChip({super.key, required this.date, this.startsNow = false});

  /// The day.
  final LocalDate date;

  /// Whether a new trip starts now (Today) instead of covering the day.
  final bool startsNow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final current = ref.watch(ledgerProvider).day(date).type;
    final color = current == null ? null : scheme.dayTypeColor(current);
    return ActionChip(
      avatar: Icon(
        current == null ? Icons.event_note_outlined : dayTypeIcon(current),
        size: 18,
        color: color,
      ),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(current == null ? l.chooseDayType : dayTypeLabel(l, current)),
          const SizedBox(width: 4),
          const Icon(Icons.expand_more, size: 18),
        ],
      ),
      side: color == null ? null : BorderSide(color: color),
      onPressed: () async {
        final picked = await showDayTypeSheet(context, current);
        if (picked == null || !context.mounted) return;
        final (type,) = picked;
        if (type == null) {
          await removeDayType(context, ref, date);
        } else {
          await pickDayType(context, ref, date, type, startsNow: startsNow);
        }
      },
    );
  }
}

/// The nine day types in a sheet; returns the one tapped, `(null,)` for
/// "remove" (only offered while [current] is set), `null` if dismissed.
Future<(DayType?,)?> showDayTypeSheet(BuildContext context, DayType? current) =>
    showModalBottomSheet<(DayType?,)>(
      context: context,
      builder: (c) {
        final l = c.l10n;
        final scheme = Theme.of(c).colorScheme;
        Widget tile(DayType t) {
          final selected = t == current;
          final color = scheme.dayTypeColor(t);
          return InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => Navigator.pop(c, (t,)),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: selected
                    ? color.withValues(alpha: 0.18)
                    : scheme.surfaceContainerHigh,
                border: Border.all(
                  color: selected ? color : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(dayTypeIcon(t), color: color),
                  const SizedBox(height: 6),
                  Text(
                    dayTypeLabel(l, t),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: Theme.of(c).textTheme.labelMedium,
                  ),
                ],
              ),
            ),
          );
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.dayType, style: Theme.of(c).textTheme.titleLarge),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1.5,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [for (final t in DayType.values) tile(t)],
                ),
                if (current != null) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => Navigator.pop(c, (null,)),
                      icon: const Icon(Icons.clear),
                      label: Text(l.removeDayType),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );

/// Removes the day type of [date] (calculations.md §15) with undo. A day
/// inside a trip stays a business trip: the user is sent to the trip.
Future<void> removeDayType(
  BuildContext context,
  WidgetRef ref,
  LocalDate date,
) async {
  final l = context.l10n;
  final trip = ref.read(ledgerProvider).tripsOn(date).firstOrNull;
  final deleted = await clearDayType(ref.read(repositoryProvider), date);
  if (!context.mounted) return;
  if (deleted.isNotEmpty) {
    offerUndoDelete(context, ref, deleted, l.dayTypeRemoved);
    return;
  }
  if (trip == null) return;
  final edit = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      content: Text(
        l.tripDayRemove(
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
