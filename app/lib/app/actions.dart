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

/// Asks when [action] happened, the current time preselected (calculations
/// §19); [title] heads the picker. Returns now without asking if the setting
/// is off, `null` if cancelled or the time isn't possible (a snack bar says
/// why).
Future<DateTime?> askStampTime(
  BuildContext context,
  WidgetRef ref,
  StampAction action,
  String title,
) async {
  final now = ref.read(clockProvider)();
  if (!ref.read(askStampTimeProvider)) return now;
  final zone = ref.read(zoneProvider);
  final local = zone.toLocal(now);
  final picked = await showTimePicker(
    context: context,
    initialTime: TimeOfDay(hour: local.hour, minute: local.minute),
    helpText: title,
  );
  if (picked == null || !context.mounted) return null;
  final earliest = await ref.read(trackerProvider).earliestAt(action);
  final at = stampInstant(
    zone,
    now,
    picked.hour,
    picked.minute,
    earliest: earliest,
  );
  final tooEarly =
      earliest != null && isoMinute(at).compareTo(isoMinute(earliest)) < 0;
  if (!tooEarly && isoMinute(at).compareTo(isoMinute(now)) <= 0) return at;
  if (!context.mounted) return null;
  final l = context.l10n;
  String when(DateTime instant) {
    final time = context.time(instant, zone);
    final day = zone.dateOf(instant);
    final today = zone.dateOf(now);
    if (day == today) return time;
    if (day == today.addDays(-1)) return l.yesterdayAt(time);
    return '${context.shortDate(day)} $time';
  }

  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    SnackBar(
      content: Text(
        earliest == null
            ? l.stampTimeFuture
            : l.forgottenTimeInvalid(when(earliest)),
      ),
    ),
  );
  return null;
}

/// Clocks in at [nextClockInLocation], at the time the user confirms.
Future<void> clockIn(BuildContext context, WidgetRef ref) async {
  tapFeedback(strong: true);
  final location = nextClockInLocation(ref);
  final at = await askStampTime(
    context,
    ref,
    StampAction.clockIn,
    context.l10n.clockIn,
  );
  if (at == null) return;
  await ref.read(trackerProvider).clockIn(location: location, at: at);
}

/// Clocks out at the time the user confirms, asks for the project summary
/// and, after travelling, whether the trip has ended.
Future<void> clockOut(BuildContext context, WidgetRef ref) async {
  tapFeedback(strong: true);
  final state = ref.read(trackerStateProvider);
  final at = await askStampTime(
    context,
    ref,
    StampAction.clockOut,
    context.l10n.clockOut,
  );
  if (at == null || !context.mounted) return;
  final tracker = ref.read(trackerProvider);
  await withSummaryPrompt(context, ref, () => tracker.clockOut(at: at));
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
    if (end == true) await ref.read(trackerProvider).endTrip(at: at);
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
      : await clockIn(context, ref);
}

/// Starts or ends a break (only while clocked in).
Future<void> toggleBreak(BuildContext context, WidgetRef ref) async {
  final state = ref.read(trackerStateProvider);
  if (!state.clockedIn) return;
  tapFeedback();
  final l = context.l10n;
  final at = await askStampTime(
    context,
    ref,
    state.onBreak ? StampAction.endBreak : StampAction.startBreak,
    state.onBreak ? l.endBreak : l.startBreak,
  );
  if (at == null || !context.mounted) return;
  final tracker = ref.read(trackerProvider);
  state.onBreak
      ? await tracker.endBreak(at: at)
      : await withSummaryPrompt(context, ref, () => tracker.startBreak(at: at));
}

/// Opens the booking sheet for today.
Future<void> bookTime(BuildContext context, WidgetRef ref) =>
    showProjectTimeDialog(context, date: ref.read(todayProvider));
