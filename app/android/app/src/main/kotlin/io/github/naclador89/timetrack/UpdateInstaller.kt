package io.github.naclador89.timetrack

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInstaller
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * In-app updates (docs/specs/updates.md §5): Dart downloads and verifies the APK, this hands it to
 * Android's installer through a [PackageInstaller] session. Android asks the user to confirm and
 * only accepts an APK signed with the same key as the installed app.
 */
object UpdateInstaller {
    fun register(context: Context, messenger: BinaryMessenger) {
        MethodChannel(messenger, "timetrack/update").setMethodCallHandler { call, result ->
            when (call.method) {
                "canInstall" -> result.success(
                    Build.VERSION.SDK_INT < 26 || context.packageManager.canRequestPackageInstalls(),
                )
                "openInstallSettings" -> {
                    if (Build.VERSION.SDK_INT >= 26) {
                        context.startActivity(
                            Intent(
                                Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                                Uri.parse("package:${context.packageName}"),
                            ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                        )
                    }
                    result.success(null)
                }
                "install" -> {
                    try {
                        install(context, File(call.argument<String>("path")!!))
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("install", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun install(context: Context, apk: File) {
        val installer = context.packageManager.packageInstaller
        val params = PackageInstaller.SessionParams(PackageInstaller.SessionParams.MODE_FULL_INSTALL)
        val id = installer.createSession(params)
        installer.openSession(id).use { session ->
            apk.inputStream().use { input ->
                session.openWrite("timetrack.apk", 0, apk.length()).use { output ->
                    input.copyTo(output)
                    session.fsync(output)
                }
            }
            val flags = PendingIntent.FLAG_UPDATE_CURRENT or
                (if (Build.VERSION.SDK_INT >= 31) PendingIntent.FLAG_MUTABLE else 0)
            val status = PendingIntent.getBroadcast(
                context,
                id,
                Intent(context, UpdateStatusReceiver::class.java),
                flags,
            )
            session.commit(status.intentSender)
        }
    }
}

/** Shows Android's confirmation when the session asks for it; other results need nothing. */
class UpdateStatusReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val status = intent.getIntExtra(PackageInstaller.EXTRA_STATUS, PackageInstaller.STATUS_FAILURE)
        if (status != PackageInstaller.STATUS_PENDING_USER_ACTION) return
        val confirm = if (Build.VERSION.SDK_INT >= 33) {
            intent.getParcelableExtra(Intent.EXTRA_INTENT, Intent::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableExtra(Intent.EXTRA_INTENT)
        } ?: return
        context.startActivity(confirm.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
    }
}
