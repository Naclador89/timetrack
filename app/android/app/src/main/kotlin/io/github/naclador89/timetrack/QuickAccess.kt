package io.github.naclador89.timetrack

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.os.Build
import android.os.SystemClock
import android.service.quicksettings.TileService
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent

/**
 * Android quick access (concept §6 E1): draws the ongoing notification, the home-screen widget
 * and the Quick Settings tile from the snapshot Dart writes into the home_widget preferences
 * (keys `qa_*`, see lib/quick/quick_access.dart). No logic here: every button sends a
 * `timetrack://quick/<action>` URI to the Dart handler `onQuickAction`, which writes, syncs
 * and publishes a new snapshot, which ends up here again via [QuickAccessReceiver].
 */
object QuickAccess {
    private const val CHANNEL_ID = "tracking"
    private const val NOTIFICATION_ID = 1

    /** The snapshot written by Dart. */
    class Snapshot(private val prefs: SharedPreferences) {
        fun text(key: String) = prefs.getString(key, null) ?: ""
        private fun number(key: String) = (prefs.all[key] as? Number)?.toLong() ?: 0L

        val phase get() = text("qa_phase").ifEmpty { "off" }
        val working get() = phase == "working"
        val onBreak get() = phase == "onBreak"
        val clockedIn get() = working || onBreak
        val runningSinceMs get() = number("qa_running_since_ms")
        val breakSinceMs get() = number("qa_break_since_ms")
        val project get() = text("qa_project")

        /** Status line: "Bei der Arbeit · Büro" etc. */
        val title: String
            get() = when {
                working -> listOf(text("qa_l_working"), text("qa_location"))
                onBreak -> listOf(text("qa_l_break"))
                else -> listOf(text("qa_l_off").ifEmpty { "TimeTrack" })
            }.filter { it.isNotEmpty() }.joinToString(" · ")
    }

    fun snapshot(context: Context) =
        Snapshot(context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE))

    fun action(context: Context, name: String): PendingIntent =
        HomeWidgetBackgroundIntent.getBroadcast(context, Uri.parse("timetrack://quick/$name"))

    private fun openApp(context: Context, uri: Uri? = null): PendingIntent =
        HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, uri)

    /** Redraws everything from the current snapshot. */
    fun render(context: Context) {
        val s = snapshot(context)
        renderNotification(context, s)
        renderWidgets(context, s)
        TileService.requestListeningState(
            context,
            ComponentName(context, QuickTileService::class.java),
        )
    }

    private fun renderNotification(context: Context, s: Snapshot) {
        val manager = context.getSystemService(NotificationManager::class.java)
        if (!s.clockedIn) {
            manager.cancel(NOTIFICATION_ID)
            return
        }
        if (Build.VERSION.SDK_INT >= 26) {
            manager.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    s.text("qa_l_working").ifEmpty { "TimeTrack" },
                    NotificationManager.IMPORTANCE_LOW,
                ).apply { setShowBadge(false) },
            )
        }
        @Suppress("DEPRECATION")
        val builder = if (Build.VERSION.SDK_INT >= 26) {
            Notification.Builder(context, CHANNEL_ID)
        } else {
            Notification.Builder(context)
        }
        // The chronometer counts up from `when`: today's worked time while working, the
        // break's length while on a break. It ticks without any updates from Dart.
        val start = if (s.working) s.runningSinceMs else s.breakSinceMs
        val text = if (s.working) s.project else ""
        builder
            .setSmallIcon(R.drawable.ic_quick)
            .setContentTitle(s.title)
            .setContentText(text)
            .setWhen(start)
            .setShowWhen(true)
            .setUsesChronometer(true)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setCategory(Notification.CATEGORY_STATUS)
            .setContentIntent(openApp(context))
            .addAction(
                Notification.Action.Builder(
                    null,
                    s.text(if (s.onBreak) "qa_l_break_end" else "qa_l_break_start"),
                    action(context, "toggleBreak"),
                ).build(),
            )
            .addAction(
                Notification.Action.Builder(
                    null,
                    s.text("qa_l_clock_out"),
                    action(context, "clockOut"),
                ).build(),
            )
        if (s.working) {
            builder.addAction(
                Notification.Action.Builder(
                    null,
                    s.text("qa_l_switch"),
                    openApp(context, Uri.parse("timetrack://quick/switch")),
                ).build(),
            )
        }
        try {
            manager.notify(NOTIFICATION_ID, builder.build())
        } catch (_: SecurityException) {
            // Notifications not allowed (Android 13+): tile and widget still work.
        }
    }

    private fun renderWidgets(context: Context, s: Snapshot) {
        val manager = AppWidgetManager.getInstance(context)
        val ids = manager.getAppWidgetIds(ComponentName(context, QuickAccessReceiver::class.java))
        if (ids.isEmpty()) return
        val views = RemoteViews(context.packageName, R.layout.quick_widget)
        views.setTextViewText(R.id.status, s.title)
        views.setTextViewText(R.id.project, if (s.working) s.project else "")
        views.setViewVisibility(
            R.id.project,
            if (s.working && s.project.isNotEmpty()) View.VISIBLE else View.GONE,
        )
        // Chronometer bases are in the elapsedRealtime clock, the snapshot in wall-clock ms.
        val offset = SystemClock.elapsedRealtime() - System.currentTimeMillis()
        if (s.clockedIn) {
            val start = if (s.working) s.runningSinceMs else s.breakSinceMs
            views.setChronometer(R.id.timer, start + offset, null, true)
        } else {
            val today = s.text("qa_today_text").ifEmpty { "0:00" }
            views.setChronometer(R.id.timer, SystemClock.elapsedRealtime(), today, false)
        }
        views.setTextViewText(R.id.label_timer, if (s.onBreak) s.text("qa_l_break") else s.text("qa_l_today"))
        views.setTextViewText(
            R.id.clock,
            s.text(if (s.clockedIn) "qa_l_clock_out" else "qa_l_clock_in"),
        )
        views.setOnClickPendingIntent(R.id.clock, action(context, "toggle"))
        views.setTextViewText(
            R.id.pause,
            s.text(if (s.onBreak) "qa_l_break_end" else "qa_l_break_start"),
        )
        views.setViewVisibility(R.id.pause, if (s.clockedIn) View.VISIBLE else View.GONE)
        views.setOnClickPendingIntent(R.id.pause, action(context, "toggleBreak"))
        views.setOnClickPendingIntent(R.id.root, openApp(context))
        manager.updateAppWidget(ids, views)
    }
}
