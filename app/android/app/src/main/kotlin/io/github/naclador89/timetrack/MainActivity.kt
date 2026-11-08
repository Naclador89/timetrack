package io.github.naclador89.timetrack

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // lib/quick/quick_access.dart: the ongoing notification needs this on Android 13+.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "timetrack/quick")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "requestNotificationPermission" -> {
                        if (Build.VERSION.SDK_INT >= 33 &&
                            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
                            PackageManager.PERMISSION_GRANTED
                        ) {
                            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 1)
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        // lib/update/installer.dart: installs a downloaded, verified release.
        UpdateInstaller.register(applicationContext, flutterEngine.dartExecutor.binaryMessenger)
        // lib/app/back_navigation.dart: back on Today sends the app to the
        // background like Home instead of closing it.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "timetrack/system")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "moveToBack" -> result.success(moveTaskToBack(true))
                    else -> result.notImplemented()
                }
            }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        QuickAccess.render(this) // show the notification right away once allowed
    }
}
