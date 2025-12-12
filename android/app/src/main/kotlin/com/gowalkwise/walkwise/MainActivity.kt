package com.gowalkwise.walkwise

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.net.Uri

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "awty_engine"
    private val BATTERY_OPT_CHANNEL = "walkwise_battery_opt"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // No-op: MethodChannel is set up in Dart, but we need to keep this for completeness

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BATTERY_OPT_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isIgnoringBatteryOptimizations" -> {
                    val pm = getSystemService(POWER_SERVICE) as PowerManager
                    val ignoring = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        pm.isIgnoringBatteryOptimizations(packageName)
                    } else {
                        true // Not needed below M
                    }
                    result.success(ignoring)
                }
                "requestIgnoreBatteryOptimizations" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        try {
                            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
                            intent.data = Uri.parse("package:$packageName")
                            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("ERROR", "Failed to request battery optimization exemption: ${e.message}", null)
                        }
                    } else {
                        result.success(true)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleAwtyNotificationIntent(intent)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleAwtyNotificationIntent(intent)
    }

    private fun handleAwtyNotificationIntent(intent: Intent?) {
        if (intent == null) return
        val action = intent.action
        val fromAwty = action == "com.gowalkwise.walkwise.AWTY_MILESTONE"
        if (fromAwty) {
            // Send message to Flutter via MethodChannel
            val engine = flutterEngine ?: return
            MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL).invokeMethod("milestoneReached", null)
        }
    }
}
