import 'package:home_widget/home_widget.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:timetrack_core/timetrack_core.dart';

import '../quick/quick_access.dart';
import '../sync/sync_controller.dart';

/// The Android background job's update check (spec: updates.md §3, §4): at
/// most once per 24 h, and a system notification once per version. Kotlin
/// (`UpdateNotice.kt`) draws it from the `up_*` keys. Never throws.
Future<void> checkUpdateInBackground(SyncStore store) async {
  if (syncDisabled || !hasQuickAccess) return;
  try {
    final installed = AppVersion.tryParse(
      (await PackageInfo.fromPlatform()).version,
    );
    if (installed == null) return;
    final proxy = (await SecureSyncConfigStore().load())?.proxy ?? '';
    final checker = UpdateChecker(
      store: store,
      installed: installed,
      platform: UpdatePlatform.android,
      fetch: () async {
        final client = proxiedClient(proxy);
        try {
          return await fetchLatestRelease(client);
        } finally {
          client.close();
        }
      },
    );
    final release = await checker.check();
    if (release == null || !await checker.takeNotification(release)) return;
    final l = quickLocalizations();
    final version = '${release.version}';
    final values = {
      'up_version': version,
      'up_title': l.updateAvailable(version),
      'up_text': l.updateNotificationText,
      'up_channel': l.updatesChannel,
    };
    for (final MapEntry(:key, :value) in values.entries) {
      await HomeWidget.saveWidgetData(key, value);
    }
    await HomeWidget.updateWidget(qualifiedAndroidName: quickAccessReceiver);
  } on Object {
    // Offline or no GitHub: the next run tries again.
  }
}
