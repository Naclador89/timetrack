import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import 'package:timetrack_core/timetrack_core.dart';

import '../app/providers.dart';
import '../features/projects/project_picker.dart';
import '../features/projects/project_time_dialog.dart';
import '../update/update_banner.dart';
import '../update/update_controller.dart';
import 'quick_access.dart';

/// What notification, tile and widget should show, from the UI's providers.
final quickStatusProvider = Provider<QuickStatus>((ref) {
  final now = ref.watch(nowProvider).value ?? ref.watch(clockProvider)();
  return QuickStatus.of(
    ref.watch(trackerStateProvider),
    ref.watch(ledgerProvider),
    ref.watch(todayProvider),
    nowMinute: epochMinute(now),
  );
});

/// URI of the notification's "Switch project" action (opens the app).
final switchProjectUri = Uri.parse('timetrack://quick/switch');

/// URI of the update notification (`UpdateNotice.kt`).
final updateUri = Uri.parse('timetrack://update');

/// Keeps the Android quick access in step with the app (concept §6 E1):
/// mirrors every state change, reloads after background writes, opens the
/// project picker for "Switch project" and asks for the summaries of timers
/// stopped outside the app. Does nothing on desktop.
class QuickAccessHost extends ConsumerStatefulWidget {
  /// Wraps [child]; dialogs open on [navigatorKey].
  const QuickAccessHost({
    super.key,
    required this.navigatorKey,
    required this.child,
  });

  /// The router's navigator, for dialogs.
  final GlobalKey<NavigatorState> navigatorKey;

  /// The app.
  final Widget child;

  @override
  ConsumerState<QuickAccessHost> createState() => _QuickAccessHostState();
}

class _QuickAccessHostState extends ConsumerState<QuickAccessHost> {
  AppLifecycleListener? _lifecycle;
  StreamSubscription<Uri?>? _clicks;
  bool _askedPermission = false;
  bool _askingSummaries = false;

  @override
  void initState() {
    super.initState();
    if (!hasQuickAccess) return;
    _lifecycle = AppLifecycleListener(onResume: _onResume);
    _clicks = HomeWidget.widgetClicked.listen(_onLaunch);
    unawaited(HomeWidget.initiallyLaunchedFromHomeWidget().then(_onLaunch));
    ref.listenManual(quickStatusProvider, (previous, next) {
      if (previous != next) _publish(next);
    }, fireImmediately: true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _askSummaries());
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    unawaited(_clicks?.cancel());
    super.dispose();
  }

  void _onResume() {
    // Notification, tile and widget write through their own connection.
    ref.read(storeProvider).notifyExternalChange();
    unawaited(_askSummaries());
  }

  BuildContext? get _dialogContext => widget.navigatorKey.currentContext;

  /// The update notification was tapped (spec: updates.md §4).
  Future<void> _showUpdate() async {
    final updater = ref.read(updateControllerProvider.notifier);
    if (ref.read(updateControllerProvider).release == null) {
      try {
        await updater.checkNow();
      } on Object {
        return; // Offline now: the banner comes with the next check.
      }
    }
    final context = _dialogContext;
    if (context != null && context.mounted) {
      await showUpdateDialog(context, ref);
    }
  }

  Future<void> _onLaunch(Uri? uri) async {
    if (uri == updateUri) return _showUpdate();
    if (uri != switchProjectUri) return;
    final context = _dialogContext;
    if (context == null) return;
    final id = await showProjectPicker(context);
    if (id == null || !context.mounted) return;
    final tracker = ref.read(trackerProvider);
    final location = ref.read(trackerStateProvider).location;
    await withSummaryPrompt(
      context,
      ref,
      () => tracker.startProject(id, location: location),
    );
  }

  Future<void> _askSummaries() async {
    if (_askingSummaries) return;
    _askingSummaries = true;
    try {
      await ref.read(rowsProvider.future); // project names for the titles
      final ids = await PendingSummaries(ref.read(storeProvider)).take();
      for (final id in ids) {
        final context = _dialogContext;
        if (context == null || !context.mounted) return;
        await askSummary(context, ref, id);
      }
    } finally {
      _askingSummaries = false;
    }
  }

  void _publish(QuickStatus status) {
    if (status.phase != QuickPhase.off && !_askedPermission) {
      _askedPermission = true;
      unawaited(requestNotificationPermission());
    }
    final project = ref.read(projectByIdProvider)[status.projectId];
    unawaited(
      publishQuickStatus(
        status,
        quickLocalizations(),
        projectName: project?.name ?? '',
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
