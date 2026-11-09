import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timetrack_core/timetrack_core.dart';

import '../app/actions.dart';
import '../app/format.dart';
import '../app/providers.dart';
import '../features/projects/project_picker.dart';
import '../features/projects/project_time_dialog.dart';
import '../reminders/reminders.dart';
import 'month_report.dart';
import 'work_pc.dart';

/// The Windows tray icon (docs/specs/work-pc.md §3): mirrors the tracker in
/// its tooltip, colour and menu, runs the menu's actions, keeps the window
/// in the tray when closed and shows the reminders (reminders.md §2) as
/// Windows notifications. Does nothing elsewhere.
class TrayHost extends ConsumerStatefulWidget {
  /// Wraps [child]; dialogs open on [navigatorKey].
  const TrayHost({super.key, required this.navigatorKey, required this.child});

  /// The router's navigator, for dialogs.
  final GlobalKey<NavigatorState> navigatorKey;

  /// The app.
  final Widget child;

  /// How often the reminders are checked while the app runs.
  static const reminderCheck = Duration(minutes: 1);

  @override
  ConsumerState<TrayHost> createState() => _TrayHostState();
}

class _TrayHostState extends ConsumerState<TrayHost> {
  StreamSubscription<String>? _actions;
  Timer? _reminders;
  TrayModel? _sent;

  WorkPcPlatform? get _platform => ref.read(workPcPlatformProvider);

  @override
  void initState() {
    super.initState();
    final platform = _platform;
    if (platform == null) return;
    _actions = platform.trayActions.listen((id) => unawaited(_run(id)));
    _reminders = Timer.periodic(
      TrayHost.reminderCheck,
      (_) => unawaited(_remind()),
    );
    ref.listenManual(closeToTrayProvider, (_, next) {
      if (next.value case final on?) unawaited(platform.setCloseToTray(on));
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    unawaited(_actions?.cancel());
    _reminders?.cancel();
    super.dispose();
  }

  /// The menu for the current state.
  TrayModel _model(BuildContext context) {
    final l = context.l10n;
    final state = ref.watch(trackerStateProvider);
    final zone = ref.watch(zoneProvider);
    final today = ref.watch(todayProvider);
    final worked = ref.watch(ledgerProvider).day(today).work.worked;
    String at(StoredRow row) =>
        context.time(DateTime.parse(row.fields['start_utc']! as String), zone);
    final location = state.location;
    final status = state.onBreak
        ? l.onBreakSince(at(state.breakRow!))
        : state.clockedIn
        ? [
            l.clockedInSince(at(state.session!)),
            if (location != null) context.locationName(location),
          ].join(' · ')
        : l.notClockedIn;
    final projects = searchProjects(
      '',
      ref.watch(projectsProvider),
      usage: ref.watch(projectUsageProvider),
    ).map((m) => m.project).toList();
    final shortlist = [
      ...projects.where((p) => p.favorite),
      ...projects.where((p) => !p.favorite),
    ].take(5);
    TrayItem item(String id, String label, {bool enabled = true}) => (
      id: id,
      label: label,
      enabled: enabled,
      checked: false,
      separator: false,
    );
    const separator = (
      id: '',
      label: '',
      enabled: true,
      checked: false,
      separator: true,
    );
    return (
      tooltip: 'TimeTrack · $status · ${formatMinutes(worked)}',
      idle: !state.clockedIn,
      items: [
        item('status', '$status · ${formatMinutes(worked)}', enabled: false),
        separator,
        item('clock', state.clockedIn ? l.clockOut : l.clockIn),
        if (state.clockedIn)
          item('break', state.onBreak ? l.endBreak : l.startBreak),
        if (shortlist.isNotEmpty) separator,
        for (final p in shortlist)
          (
            id: 'project:${p.id}',
            label: p.name,
            enabled: true,
            checked: state.projectId == p.id,
            separator: false,
          ),
        item('switch', '${l.switchProject}…'),
        item('book', '${l.bookProjectTime}…'),
        separator,
        item('open', l.trayOpen),
        item('quit', l.trayQuit),
      ],
    );
  }

  /// Sends the menu after the frame, only when it changed.
  void _publish(TrayModel model) {
    final platform = _platform;
    if (platform == null || _same(model, _sent)) return;
    _sent = model;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => unawaited(platform.setTray(model)),
    );
  }

  static bool _same(TrayModel a, TrayModel? b) =>
      b != null &&
      a.tooltip == b.tooltip &&
      a.idle == b.idle &&
      a.items.length == b.items.length &&
      [for (var i = 0; i < a.items.length; i++) a.items[i] == b.items[i]]
          .every((same) => same);

  /// Runs a tray menu item. Whatever may ask something (the time of a
  /// stamp, the summary of a stopped project, the trip's end) brings the
  /// window up first.
  Future<void> _run(String id) async {
    final platform = _platform;
    final context = widget.navigatorKey.currentContext;
    if (platform == null || context == null || !context.mounted) return;
    final state = ref.read(trackerStateProvider);
    final asksTime = ref.read(askStampTimeProvider);
    final asks = asksTime || state.entry != null || state.trip != null;
    Future<void> visible() async {
      if (asks) await platform.showWindow();
    }

    switch (id) {
      case 'clock':
        if (state.clockedIn || asksTime) await visible();
        if (context.mounted) await toggleClock(context, ref);
      case 'break':
        if (!state.onBreak || asksTime) await visible();
        if (context.mounted) await toggleBreak(context, ref);
      case 'switch':
        await platform.showWindow();
        if (!context.mounted) return;
        final picked = await showProjectPicker(context);
        if (picked != null && context.mounted) await _start(context, picked);
      case 'book':
        await platform.showWindow();
        if (context.mounted) await bookTime(context, ref);
      case 'open':
        await platform.showWindow();
      case 'quit':
        await platform.quit();
      default:
        if (id.startsWith('project:')) {
          await visible();
          if (context.mounted) await _start(context, id.substring(8));
        }
    }
  }

  Future<void> _start(BuildContext context, String projectId) {
    final tracker = ref.read(trackerProvider);
    final location = ref.read(trackerStateProvider).location;
    return withSummaryPrompt(
      context,
      ref,
      () => tracker.startProject(projectId, location: location),
    );
  }

  /// Shows the reminders that are due (reminders.md §2) and, once a month,
  /// the one to report the balance (work-pc.md §4).
  Future<void> _remind() async {
    final platform = _platform;
    if (platform == null || !mounted) return;
    final store = ref.read(storeProvider);
    final report = ref.read(monthReportProvider);
    if (report != null) {
      final key = monthKey(report.month);
      final shown = await store.transaction(
        (tx) => tx.localValue(monthReportNotifiedKey),
      );
      if (shown != key && mounted) {
        final texts = monthReportTexts(context, report);
        await platform.notify(texts.title, texts.text);
        await store.transaction(
          (tx) => tx.setLocalValue(monthReportNotifiedKey, key),
        );
      }
    }
    if (!mounted) return;
    final now = ref.read(clockProvider)();
    final due = (await pendingReminders(
      store,
      now,
    )).where((r) => !r.at.isAfter(now)).toList();
    if (due.isEmpty || !mounted) return;
    final texts = reminderTexts(context.l10n, due.last);
    await platform.notify(texts.title, texts.text);
    await markRemindersShown(store, due.map((r) => r.key));
  }

  @override
  Widget build(BuildContext context) {
    if (_platform != null) _publish(_model(context));
    return widget.child;
  }
}
