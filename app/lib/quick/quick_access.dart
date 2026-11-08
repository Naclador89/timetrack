import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import 'package:timetrack_core/timetrack_core.dart';
import 'package:workmanager/workmanager.dart';

import '../app/format.dart';
import '../app/services.dart';
import '../l10n/app_localizations.dart';
import '../reminders/reminders.dart';
import '../sync/sync_controller.dart';
import '../update/background_check.dart';

// Android quick access (concept §6 E1, milestone M5).
//
// Kotlin draws the ongoing notification, the Quick Settings tile and the
// home-screen widget from one state snapshot, which Dart writes into the
// home_widget preferences ([publishQuickStatus]). Their buttons send
// `timetrack://quick/<action>` URIs to [onQuickAction], which runs in a
// background Flutter engine. All logic stays in Dart (core `runQuickAction`).
// See android/app/src/main/kotlin/.../QuickAccess.kt for the native half.

/// Fully qualified name of the Kotlin receiver that redraws everything.
const quickAccessReceiver =
    'io.github.naclador89.timetrack.QuickAccessReceiver';

/// Whether this platform has quick access (Android only).
bool get hasQuickAccess => Platform.isAndroid;

const _channel = MethodChannel('timetrack/quick');

/// Registers the background handlers (call once from `main()`).
///
/// The periodic job syncs every 15 minutes while the app is closed
/// (sync-format.md §7.2); it does nothing without a bound connection.
Future<void> initQuickAccess() async {
  if (!hasQuickAccess) return;
  await HomeWidget.registerInteractivityCallback(onQuickAction);
  // Reminders need WorkManager too (reminders.md §2), the sync job doesn't
  // run in demo builds.
  await Workmanager().initialize(backgroundTaskDispatcher);
  if (syncDisabled) return;
  await Workmanager().registerPeriodicTask(
    'sync',
    'sync',
    frequency: const Duration(minutes: 15),
    constraints: Constraints(networkType: NetworkType.connected),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
  );
}

/// Asks for the notification permission (Android 13+). Without it the
/// ongoing notification stays hidden; tile and widget still work.
Future<void> requestNotificationPermission() async {
  if (!hasQuickAccess) return;
  try {
    await _channel.invokeMethod<void>('requestNotificationPermission');
  } on PlatformException {
    // Not critical.
  }
}

/// Writes [status] and the texts for it, then lets Kotlin redraw the
/// notification, tile and widget.
Future<void> publishQuickStatus(
  QuickStatus status,
  AppLocalizations l, {
  String projectName = '',
}) async {
  if (!hasQuickAccess) return;
  const minute = 60000;
  final location = status.location;
  final values = <String, Object>{
    'qa_phase': status.phase.name,
    'qa_today_min': status.todayMinutes,
    'qa_running_since_ms': (status.runningSince ?? 0) * minute,
    'qa_break_since_ms': (status.breakSince ?? 0) * minute,
    'qa_project': projectName,
    'qa_location': location == null ? '' : locationLabel(l, location),
    'qa_today_text': formatMinutes(status.todayMinutes),
    // Device time: the notification is read on this device.
    'qa_finish_text': switch (status.targetAt) {
      final at? => l.forecastTarget(
        DateFormat.Hm(l.localeName)
            .format(DateTime.fromMillisecondsSinceEpoch(at * minute)),
      ),
      null => '',
    },
    'qa_l_off': l.notClockedIn,
    'qa_l_working': l.quickWorking,
    'qa_l_break': l.quickOnBreak,
    'qa_l_clock_in': l.clockIn,
    'qa_l_clock_out': l.clockOut,
    'qa_l_break_start': l.startBreak,
    'qa_l_break_end': l.endBreak,
    'qa_l_switch': l.switchProject,
    'qa_l_today': l.quickToday,
  };
  for (final MapEntry(:key, :value) in values.entries) {
    await HomeWidget.saveWidgetData(key, value);
  }
  await HomeWidget.updateWidget(qualifiedAndroidName: quickAccessReceiver);
}

/// Computes the status from the database and publishes it (background
/// handlers; the UI publishes from its providers instead).
Future<void> publishFromStore(SyncStore store, {DateTime? now}) async {
  final at = now ?? DateTime.now();
  final rows = await store.watchRows(syncedTables).first;
  final ledger = appLedger(rows, at);
  final state = TrackerState.fromRows(rows);
  final status = QuickStatus.of(
    state,
    ledger,
    ledger.zone.dateOf(at),
    nowMinute: epochMinute(at),
  );
  final project = rows
      .where((r) => r.table == 'projects' && r.id == status.projectId)
      .map(projectFromRow)
      .nonNulls
      .firstOrNull;
  await publishQuickStatus(
    status,
    quickLocalizations(),
    projectName: project?.name ?? '',
  );
  await scheduleReminders(store, now: at);
}

/// Texts for notification, tile and widget in the system language. Also used
/// by the UI: it publishes while in the background, without a frame or context.
AppLocalizations quickLocalizations() {
  final code = PlatformDispatcher.instance.locale.languageCode;
  return lookupAppLocalizations(Locale(code == 'en' ? 'en' : 'de'));
}

// One action at a time: two quick taps must not interleave their writes.
Future<void> _queue = Future.value();

/// Background entry point for the buttons of notification, tile and widget.
@pragma('vm:entry-point')
Future<void> onQuickAction(Uri? uri) {
  final action = QuickAction.parse(uri);
  if (action == null) return Future.value();
  return _queue = _queue
      .then((_) async {
        final services = await AppServices.open(shareAcrossIsolates: false);
        try {
          await runQuickAction(services.repository, action);
          await publishFromStore(services.store);
          await syncInBackground(services.repository);
          // The sync may have brought changes from other devices.
          await publishFromStore(services.store);
        } finally {
          await services.close();
        }
      })
      .catchError((Object _) {});
}

/// Background entry point for WorkManager jobs (periodic sync, daily update
/// check, reminders).
@pragma('vm:entry-point')
void backgroundTaskDispatcher() {
  Workmanager().executeTask((task, _) async {
    WidgetsFlutterBinding.ensureInitialized();
    final services = await AppServices.open(shareAcrossIsolates: false);
    try {
      if (task != reminderTask) {
        await syncInBackground(services.repository);
        await publishFromStore(services.store);
        await checkUpdateInBackground(services.store);
      }
      await showDueReminders(services.store);
      await scheduleReminders(services.store);
    } finally {
      await services.close();
    }
    return true;
  });
}
