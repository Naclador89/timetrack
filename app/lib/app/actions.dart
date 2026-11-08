import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timetrack_core/timetrack_core.dart';

import '../features/projects/project_time_dialog.dart';
import '../widgets/motion.dart';
import 'format.dart';
import 'providers.dart';

// The actions behind Today's button, the command palette and the keyboard
// shortcuts, so they all follow the same rules.

/// The locations today's day type allows (calculations §15); office or
/// home office while no type is picked.
List<WorkLocation> allowedLocations(WidgetRef ref) {
  final type = ref.read(ledgerProvider).day(ref.read(todayProvider)).type;
  final allowed = type?.locations ?? const <WorkLocation>[];
  return allowed.isEmpty
      ? const [WorkLocation.office, WorkLocation.home]
      : allowed;
}

/// The location for the next clock-in: the last used one, as far as
/// today's day type allows it (trip days use the trip steps instead).
WorkLocation nextClockInLocation(WidgetRef ref) {
  final allowed = allowedLocations(ref);
  final sessions = ref.read(ledgerDataProvider).sessions;
  final last = sessions.isEmpty
      ? null
      : sessions.reduce((a, b) => a.start.isAfter(b.start) ? a : b).location;
  return allowed.contains(last) ? last! : allowed.first;
}

/// Clocks in at [nextClockInLocation].
Future<void> clockIn(WidgetRef ref) async {
  tapFeedback(strong: true);
  await ref.read(trackerProvider).clockIn(location: nextClockInLocation(ref));
}

/// Clocks out, asks for the project summary and, after travelling, whether
/// the trip has ended.
Future<void> clockOut(BuildContext context, WidgetRef ref) async {
  tapFeedback(strong: true);
  final state = ref.read(trackerStateProvider);
  await withSummaryPrompt(context, ref, ref.read(trackerProvider).clockOut);
  if (!context.mounted) return;
  if (state.trip != null && state.location == WorkLocation.travel) {
    final end = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(c.l10n.endTripQuestion),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(c.l10n.notNow),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(c.l10n.endTrip),
          ),
        ],
      ),
    );
    if (end == true) await ref.read(trackerProvider).endTrip();
  }
}

/// Clocks in or out. On a trip day the steps on Today decide what comes
/// next (calculations §9.1), so this opens Today instead.
Future<void> toggleClock(BuildContext context, WidgetRef ref) async {
  final today = ref.read(todayProvider);
  if (ref.read(ledgerProvider).day(today).type == DayType.businessTrip) {
    GoRouter.of(context).go('/today');
    return;
  }
  ref.read(trackerStateProvider).clockedIn
      ? await clockOut(context, ref)
      : await clockIn(ref);
}

/// Starts or ends a break (only while clocked in).
Future<void> toggleBreak(BuildContext context, WidgetRef ref) async {
  final state = ref.read(trackerStateProvider);
  if (!state.clockedIn) return;
  tapFeedback();
  final tracker = ref.read(trackerProvider);
  state.onBreak
      ? await tracker.endBreak()
      : await withSummaryPrompt(context, ref, tracker.startBreak);
}

/// Opens the booking sheet for today.
Future<void> bookTime(BuildContext context, WidgetRef ref) =>
    showProjectTimeDialog(context, date: ref.read(todayProvider));
