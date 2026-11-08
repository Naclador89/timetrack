import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timetrack_core/timetrack_core.dart';

import '../app/format.dart';
import '../app/providers.dart';
import '../sync/sync_controller.dart';
import 'work_pc.dart';

/// After Windows started the app at sign-in: asks whether to start tracking
/// for today, unless it runs or ran already (spec: work-pc.md §2). Otherwise
/// the window stays minimized.
class StartPromptHost extends ConsumerStatefulWidget {
  /// Wraps [child]; the dialog opens on [navigatorKey].
  const StartPromptHost({
    super.key,
    required this.navigatorKey,
    required this.child,
  });

  /// The router's navigator, for the dialog.
  final GlobalKey<NavigatorState> navigatorKey;

  /// The app.
  final Widget child;

  /// How long to wait for the first sync, so a start on the phone counts.
  static const syncWait = Duration(seconds: 20);

  @override
  ConsumerState<StartPromptHost> createState() => _StartPromptHostState();
}

class _StartPromptHostState extends ConsumerState<StartPromptHost> {
  @override
  void initState() {
    super.initState();
    if (!ref.read(autostartedProvider)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_ask()));
  }

  Future<void> _ask() async {
    await _waitForSync();
    final prompt = StartPrompt(
      ref.read(storeProvider),
      now: ref.read(clockProvider),
    );
    final offered = await prompt.offer();
    if (offered == null) return;
    await ref.read(workPcPlatformProvider)?.showWindow();
    final context = widget.navigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    final location = await showDialog<WorkLocation>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _StartTrackingDialog(initial: offered),
    );
    if (location == null) {
      await prompt.decline();
    } else {
      await ref.read(trackerProvider).clockIn(location: location);
    }
  }

  /// Syncs until one cycle succeeded or [StartPromptHost.syncWait] is over;
  /// at sign-in the network often comes up a few seconds late.
  Future<void> _waitForSync() async {
    if (syncDisabled) return;
    if (await ref.read(syncConfigStoreProvider).load() == null) return;
    final deadline = DateTime.now().add(StartPromptHost.syncWait);
    final sync = ref.read(syncControllerProvider.notifier);
    while (mounted && DateTime.now().isBefore(deadline)) {
      await sync.syncNow(trigger: SyncTrigger.app);
      if (!mounted || ref.read(syncControllerProvider).lastSuccess != null) {
        return;
      }
      await Future<void>.delayed(const Duration(seconds: 2));
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// "Start tracking for today?" with office or home office; pops the
/// location, or `null` for "not today".
class _StartTrackingDialog extends StatefulWidget {
  const _StartTrackingDialog({required this.initial});

  final WorkLocation initial;

  @override
  State<_StartTrackingDialog> createState() => _StartTrackingDialogState();
}

class _StartTrackingDialogState extends State<_StartTrackingDialog> {
  late WorkLocation _location = widget.initial == WorkLocation.home
      ? WorkLocation.home
      : WorkLocation.office;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(l.startTrackingTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.startTrackingText),
          const SizedBox(height: 16),
          SegmentedButton<WorkLocation>(
            segments: [
              for (final loc in const [WorkLocation.office, WorkLocation.home])
                ButtonSegment(
                  value: loc,
                  icon: Icon(locationIcon(loc)),
                  label: Text(context.locationName(loc)),
                ),
            ],
            selected: {_location},
            onSelectionChanged: (s) => setState(() => _location = s.first),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.startTrackingNotToday),
        ),
        FilledButton(
          autofocus: true,
          onPressed: () => Navigator.pop(context, _location),
          child: Text(l.startTrackingStart),
        ),
      ],
    );
  }
}
