package com.blockbuster

import android.content.Context
import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.blockbuster/blocker"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            val prefs = getSharedPreferences("app_blocker_prefs", Context.MODE_PRIVATE)

            when (call.method) {
                "setBlockedPackages" -> {
                    val packages = call.argument<List<String>>("packages") ?: emptyList()
                    prefs.edit().putStringSet("blocked_packages", packages.toSet()).apply()
                    result.success(true)
                }
                "addTime" -> {
                    val packageName = call.argument<String>("packageName") ?: ""
                    val seconds = call.argument<Int>("seconds") ?: 0
                    val current = prefs.getInt("time_left_$packageName", 0)
                    prefs.edit().putInt("time_left_$packageName", current + seconds).apply()
                    result.success(true)
                }
                "getTimeLeft" -> {
                    val packageName = call.argument<String>("packageName") ?: ""
                    val timeLeft = prefs.getInt("time_left_$packageName", 0)
                    result.success(timeLeft)
                }
                "isAccessibilityEnabled" -> {
                    val enabled = isAccessibilityServiceEnabled(context, BlockerAccessibilityService::class.java)
                    result.success(enabled)
                }
                "openAccessibilitySettings" -> {
                    val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                    startActivity(intent)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun isAccessibilityServiceEnabled(context: Context, service: Class<*>): Boolean {
        val expectedComponentName = "${context.packageName}/${service.name}"
        val enabledServices = Settings.Secure.getString(
            context.contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false
        return enabledServices.contains(expectedComponentName)
    }
}