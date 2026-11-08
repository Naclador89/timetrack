import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import 'package:timetrack_core/timetrack_core.dart';
import 'package:workmanager/workmanager.dart';

import '../l10n/app_localizations.dart';
import '../quick/quick_access.dart';

// Reminders while working (docs/specs/reminders.md §2): which are due, their
// texts, and on Android the scheduling and the notification.

/// Whether this platform shows reminders (Android notifications, Windows
/// through the tray icon).
bool get hasReminders => Platform.isAndroid || Platform.isWindows;

/// [hasReminders], overridable in tests: the settings show the switches.
final remindersAvailableProvider = Provider<bool>((ref) => hasReminders);

/// `local_values` key of the keys already shown (the last 20).
const _shownKey = 'reminders_shown';

/// The WorkManager task that shows the next reminder.
const reminderTask = 'reminder';

/// The reminders of today not shown yet, with their due instants.
Future<List<Reminder>> pendingReminders(SyncStore store, DateTime now) async {
  final rows = await store.watchRows(syncedTables).first;
  final ledger = appLedger(rows, now);
  final shown = await _shown(store);
  return nextReminders(
    ledger,
    TrackerState.fromRows(rows),
    ledger.zone.dateOf(now),
    AppSettings.fromRows(rows),
  ).where((r) => !shown.contains(r.key)).toList();
}

Future<List<String>> _shown(SyncStore store) async {
  final raw = await store.transaction((tx) => tx.localValue(_shownKey));
  if (raw == null) return [];
  try {
    return (jsonDecode(raw) as List).cast<String>();
  } on Object {
    return [];
  }
}

/// Remembers that the reminders with [keys] were shown.
Future<void> markRemindersShown(SyncStore store, Iterable<String> keys) async {
  final shown = [...await _shown(store), ...keys];
  final recent = shown.length > 20 ? shown.sublist(shown.length - 20) : shown;
  await store.transaction(
    (tx) => tx.setLocalValue(_shownKey, jsonEncode(recent)),
  );
}

/// Title, text and action label of [reminder].
({String title, String text, String action}) reminderTexts(
  AppLocalizations l,
  Reminder reminder,
) => switch (reminder.kind) {
  ReminderKind.breakDue => (
    title: l.reminderBreakTitle,
    text: l.reminderBreakText,
    action: l.startBreak,
  ),
  ReminderKind.longDay => (
    title: l.reminderLongDayTitle,
    text: l.reminderLongDayText,
    action: l.clockOut,
  ),
};

/// Android: schedules the WorkManager task for the next reminder, or
/// cancels it when nothing is pending.
Future<void> scheduleReminders(SyncStore store, {DateTime? now}) async {
  if (!hasQuickAccess) return;
  final at = now ?? DateTime.now();
  final pending = await pendingReminders(store, at);
  try {
    if (pending.isEmpty) {
      await Workmanager().cancelByUniqueName(reminderTask);
      return;
    }
    final next = pending
        .map((r) => r.at)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    final delay = next.difference(at);
    await Workmanager().registerOneOffTask(
      reminderTask,
      reminderTask,
      initialDelay: delay.isNegative ? Duration.zero : delay,
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );
  } on Object {
    // Not every background engine has WorkManager; the periodic job checks.
  }
}

/// Android: shows the reminder that is due now (the latest one if several
/// are) as a notification (`ReminderNotice.kt`).
Future<void> showDueReminders(SyncStore store, {DateTime? now}) async {
  if (!hasQuickAccess) return;
  final at = now ?? DateTime.now();
  final due = (await pendingReminders(
    store,
    at,
  )).where((r) => !r.at.isAfter(at)).toList();
  if (due.isEmpty) return;
  final reminder = due.last;
  final texts = reminderTexts(quickLocalizations(), reminder);
  final values = <String, String>{
    'rm_key': reminder.key,
    'rm_title': texts.title,
    'rm_text': texts.text,
    'rm_action_label': texts.action,
    'rm_action': switch (reminder.kind) {
      ReminderKind.breakDue => 'toggleBreak',
      ReminderKind.longDay => 'clockOut',
    },
    'rm_channel': quickLocalizations().reminders,
  };
  for (final MapEntry(:key, :value) in values.entries) {
    await HomeWidget.saveWidgetData(key, value);
  }
  await HomeWidget.updateWidget(qualifiedAndroidName: quickAccessReceiver);
  await markRemindersShown(store, due.map((r) => r.key));
}
