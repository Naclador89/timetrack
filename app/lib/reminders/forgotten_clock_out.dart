import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timetrack_core/timetrack_core.dart';

import '../app/format.dart';
import '../app/providers.dart';
import '../features/projects/project_time_dialog.dart';

/// Asks "when did you finish?" when the app starts or returns with a
/// session that is probably forgotten (docs/specs/reminders.md §1).
class ForgottenClockOutHost extends ConsumerStatefulWidget {
  /// Wraps [child]; the dialog opens on [navigatorKey].
  const ForgottenClockOutHost({
    super.key,
    required this.navigatorKey,
    required this.child,
  });

  /// The router's navigator, for the dialog.
  final GlobalKey<NavigatorState> navigatorKey;

  /// The app.
  final Widget child;

  /// `local_values` key: the session the user is still working in.
  static const ackKey = 'forgotten_ack';

  @override
  ConsumerState<ForgottenClockOutHost> createState() =>
      _ForgottenClockOutHostState();
}

class _ForgottenClockOutHostState extends ConsumerState<ForgottenClockOutHost> {
  late final AppLifecycleListener _lifecycle;
  bool _asking = false;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: () => unawaited(_check()));
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_check()));
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    if (_asking) return;
    _asking = true;
    try {
      final store = ref.read(storeProvider);
      final now = ref.read(clockProvider)();
      final rows = await store.watchRows(syncedTables).first;
      final forgotten = forgottenClockOut(rows, now);
      if (forgotten == null || !mounted) return;
      final ack = await store.transaction(
        (tx) => tx.localValue(ForgottenClockOutHost.ackKey),
      );
      if (ack == forgotten.id) return;
      final context = widget.navigatorKey.currentContext;
      if (context == null || !context.mounted) return;
      final end = await showDialog<DateTime>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _ForgottenDialog(forgotten: forgotten, now: now),
      );
      if (end == null) {
        await store.transaction(
          (tx) => tx.setLocalValue(ForgottenClockOutHost.ackKey, forgotten.id),
        );
        return;
      }
      if (!context.mounted) return;
      final tracker = ref.read(trackerProvider);
      await withSummaryPrompt(context, ref, () => tracker.clockOut(at: end));
      if (!context.mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.clockedOutAt(
              _when(context, end, ref.read(zoneProvider), now),
            ),
          ),
        ),
      );
    } finally {
      _asking = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// "gestern, 08:00", "08:00" today, else "Mo., 2.11. 08:00".
String _when(
  BuildContext context,
  DateTime instant,
  HomeTimeZone zone,
  DateTime now,
) {
  final time = context.time(instant, zone);
  final day = zone.dateOf(instant);
  final today = zone.dateOf(now);
  if (day == today) return time;
  if (day == today.addDays(-1)) return context.l10n.yesterdayAt(time);
  return '${context.shortDate(day)} $time';
}

/// Pops the chosen end, or `null` for "still working".
class _ForgottenDialog extends ConsumerWidget {
  const _ForgottenDialog({required this.forgotten, required this.now});

  final ForgottenSession forgotten;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final zone = ref.watch(zoneProvider);
    String label(EndSuggestionKind kind) => switch (kind) {
      EndSuggestionKind.lastActivity => l.suggestLastActivity,
      EndSuggestionKind.targetReached => l.suggestTarget,
      EndSuggestionKind.usualEnd => l.suggestUsualEnd,
    };
    return AlertDialog(
      icon: const Icon(Icons.timer_off_outlined),
      title: Text(l.forgottenTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.forgottenText(_when(context, forgotten.start, zone, now))),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in forgotten.suggestions)
                ActionChip(
                  avatar: const Icon(Icons.schedule, size: 18),
                  label: Text(
                    '${_when(context, s.at, zone, now)} · ${label(s.kind)}',
                  ),
                  onPressed: () => Navigator.pop(context, s.at),
                ),
              ActionChip(
                avatar: const Icon(Icons.edit_calendar_outlined, size: 18),
                label: Text(l.otherTime),
                onPressed: () async {
                  final at = await _pick(context, zone);
                  if (at != null && context.mounted) {
                    Navigator.pop(context, at);
                  }
                },
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.stillWorking),
        ),
      ],
    );
  }

  /// Date and time after the session start, not in the future.
  Future<DateTime?> _pick(BuildContext context, HomeTimeZone zone) async {
    final first = zone.dateOf(forgotten.start);
    final last = zone.dateOf(now);
    LocalDate day = first;
    if (first != last) {
      final picked = await showDatePicker(
        context: context,
        firstDate: DateTime(first.year, first.month, first.day),
        lastDate: DateTime(last.year, last.month, last.day),
        initialDate: DateTime(first.year, first.month, first.day),
      );
      if (picked == null) return null;
      day = LocalDate(picked.year, picked.month, picked.day);
    }
    if (!context.mounted) return null;
    final startLocal = zone.toLocal(forgotten.start);
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: startLocal.hour, minute: startLocal.minute),
    );
    if (time == null || !context.mounted) return null;
    final at = zone.instantAt(day, time.hour, time.minute);
    if (!at.isAfter(forgotten.start) || at.isAfter(now)) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.forgottenTimeInvalid(
              _when(context, forgotten.start, zone, now),
            ),
          ),
        ),
      );
      return null;
    }
    return at;
  }
}
