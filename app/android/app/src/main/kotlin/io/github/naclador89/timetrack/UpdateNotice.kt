package io.github.naclador89.timetrack

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.net.Uri
import android.os.Build
import es.antonborri.home_widget.HomeWidgetLaunchIntent

/**
 * The "update available" system notification (docs/specs/updates.md §4). The background job in
 * Dart writes `up_*` keys into the home_widget preferences, once per version, and triggers
 * [QuickAccessReceiver]; [QuickAccess.render] calls [render]. Tapping opens the app with
 * `timetrack://update`, which shows the update dialog.
 */
object UpdateNotice {
    private const val CHANNEL_ID = "updates"
    private const val NOTIFICATION_ID = 2

    fun render(context: Context) {
        val s = QuickAccess.snapshot(context)
        val version = s.text("up_version")
        if (version.isEmpty() || version == s.text("up_shown")) return
        val manager = context.getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= 26) {
            manager.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    s.text("up_channel").ifEmpty { "Updates" },
                    NotificationManager.IMPORTANCE_DEFAULT,
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
            .setContentTitle(s.text("up_title"))
            .setContentText(s.text("up_text"))
            .setAutoCancel(true)
            .setContentIntent(
                HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("timetrack://update"),
                ),
            )
        try {
            manager.notify(NOTIFICATION_ID, builder.build())
        } catch (_: SecurityException) {
            // Notifications not allowed: the banner in the app still shows it.
        }
        // Every render redraws the quick access; show this one only once.
        context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
            .edit().putString("up_shown", version).apply()
    }
}
