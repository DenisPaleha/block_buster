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
                    val now = System.currentTimeMillis()
                    val currentDeadline = prefs.getLong("deadline_$packageName", 0L)

                    // Если время еще не вышло — продлеваем дедлайн, иначе считаем от текущего момента
                    val baseTime = if (currentDeadline > now) currentDeadline else now
                    val newDeadline = baseTime + (seconds * 1000L)

                    prefs.edit().putLong("deadline_$packageName", newDeadline).apply()
                    result.success(true)
                }

                "getTimeLeft" -> {
                    val packageName = call.argument<String>("packageName") ?: ""
                    val now = System.currentTimeMillis()
                    val deadline = prefs.getLong("deadline_$packageName", 0L)
                    val remainingSeconds = if (deadline > now) ((deadline - now) / 1000).toInt() else 0
                    result.success(remainingSeconds)
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