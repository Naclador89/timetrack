package io.github.naclador89.timetrack

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent

/**
 * The home-screen widget, and the target of `HomeWidget.updateWidget` from Dart: every update
 * redraws notification, widget and tile ([QuickAccess.render]), also when no widget is placed.
 */
class QuickAccessReceiver : AppWidgetProvider() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == AppWidgetManager.ACTION_APPWIDGET_UPDATE) {
            QuickAccess.render(context)
        } else {
            super.onReceive(context, intent)
        }
    }
}
