package com.blockbuster

import android.content.Context
import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.block_buster/native_bridge"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            val prefs = getSharedPreferences("app_blocker_prefs", Context.MODE_PRIVATE)

            when (call.method) {
                // Обновить список заблокированных пакетов: ["com.instagram.android", ...]
                "setBlockedPackages" -> {
                    val list = call.argument<List<String>>("packages")?.toSet() ?: emptySet()
                    prefs.edit().putStringSet("blocked_packages", list).apply()
                    result.success(true)
                }

                // Добавить накрученные секунды при конвертации оборотов
                "addAllowedTime" -> {
                    val pkg = call.argument<String>("package")
                    val secondsToAdd = call.argument<Int>("seconds") ?: 0
                    if (pkg != null) {
                        val current = prefs.getInt("time_left_$pkg", 0)
                        val updated = current + secondsToAdd
                        prefs.edit().putInt("time_left_$pkg", updated).apply()
                        result.success(updated)
                    } else {
                        result.error("INVALID_ARGUMENT", "Package name is null", null)
                    }
                }

                // Получить оставшиеся секунды для конкретного пакета
                "getTimeLeft" -> {
                    val pkg = call.argument<String>("package")
                    if (pkg != null) {
                        val current = prefs.getInt("time_left_$pkg", 0)
                        result.success(current)
                    } else {
                        result.success(0)
                    }
                }

                // Проверить, включена ли служба Accessibility в настройках телефона
                "isAccessibilityServiceEnabled" -> {
                    val enabled = isAccessibilityEnabled(context)
                    result.success(enabled)
                }

                // Открыть экран настроек «Специальные возможности», чтобы пользователь включил службу
                "openAccessibilitySettings" -> {
                    val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                    startActivity(intent)
                    result.success(true)
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun isAccessibilityEnabled(context: Context): Boolean {
        val expectedServiceName = "${context.packageName}/${context.packageName}.BlockerAccessibilityService"
        val enabledServices = Settings.Secure.getString(
            context.contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false

        return enabledServices.contains(expectedServiceName)
    }
}