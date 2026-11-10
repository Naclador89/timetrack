package io.github.naclador89.timetrack

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build

/**
 * Reminders while working (docs/specs/reminders.md §2): "break due", "target reached", "almost 10 hours". Dart
 * decides what is due and writes `rm_*` keys (one reminder at a time, each key once), then
 * triggers [QuickAccessReceiver]; [QuickAccess.render] calls [render]. The action button sends
 * the same quick action URI as the ongoing notification. A break or clocking out removes it.
 */
object ReminderNotice {
    private const val CHANNEL_ID = "reminders"
    private const val NOTIFICATION_ID = 3

    fun render(context: Context, s: QuickAccess.Snapshot) {
        val manager = context.getSystemService(NotificationManager::class.java)
        if (!s.working) {
            manager.cancel(NOTIFICATION_ID)
            return
        }
        val key = s.text("rm_key")
        if (key.isEmpty() || key == s.text("rm_shown")) return
        if (Build.VERSION.SDK_INT >= 26) {
            manager.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    s.text("rm_channel").ifEmpty { "Reminders" },
                    NotificationManager.IMPORTANCE_HIGH,
                ),
            )
        }
        @Suppress("DEPRECATION")
        val builder = if (Build.VERSION.SDK_INT >= 26) {
            Notification.Builder(context, CHANNEL_ID)
        } else {
            Notification.Builder(context)
        }
        builder
            .setSmallIcon(R.drawable.ic_quick)
            .setContentTitle(s.text("rm_title"))
            .setContentText(s.text("rm_text"))
            .setAutoCancel(true)
            .setCategory(Notification.CATEGORY_REMINDER)
            .setContentIntent(QuickAccess.openApp(context))
            .addAction(
                Notification.Action.Builder(
                    null,
                    s.text("rm_action_label"),
                    QuickAccess.action(context, s.text("rm_action")),
                ).build(),
            )
        try {
            manager.notify(NOTIFICATION_ID, builder.build())
        } catch (_: SecurityException) {
            // Notifications not allowed: nothing to remind with.
        }
        // Every render redraws the quick access; show each reminder only once.
        context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
            .edit().putString("rm_shown", key).apply()
    }
}
