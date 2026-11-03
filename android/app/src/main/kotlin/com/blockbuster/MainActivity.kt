package com.blockbuster

import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Context
import android.content.Intent
import android.provider.Settings
import android.view.accessibility.AccessibilityManager
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
                // Проверка статуса службы (Dart ждет строго "isAccessibilityEnabled")
                "isAccessibilityEnabled", "isAccessibilityServiceEnabled" -> {
                    val isEnabled = isAccessibilityServiceEnabled()
                    result.success(isEnabled)
                }

                // Переход в настройки спецвозможностей
                "openAccessibilitySettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("INTENT_ERROR", e.message, null)
                    }
                }

                // Сохранение списка блокируемых приложений
                "setBlockedPackages", "setBlockedApps" -> {
                    val packages = call.argument<List<String>>("packages")
                    if (packages != null) {
                        prefs.edit().putStringSet("blocked_packages", packages.toSet()).apply()
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGUMENT", "Packages list is null", null)
                    }
                }

                // Получение списка блокируемых приложений
                "getBlockedApps", "getBlockedPackages" -> {
                    val packages = prefs.getStringSet("blocked_packages", emptySet()) ?: emptySet()
                    result.success(packages.toList())
                }

                // Добавление времени в банк секунд
                "addTime" -> {
                    val packageName = call.argument<String>("packageName")
                    val seconds = call.argument<Int>("seconds") ?: 0

                    if (packageName != null) {
                        val currentBank = prefs.getInt("bank_seconds_$packageName", 0)
                        val newBank = currentBank + seconds
                        prefs.edit().putInt("bank_seconds_$packageName", newBank).apply()
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGUMENT", "Package name is null", null)
                    }
                }

                // Чтение остатка банка секунд
                "getTimeLeft" -> {
                    val packageName = call.argument<String>("packageName")
                    if (packageName != null) {
                        val remainingSeconds = prefs.getInt("bank_seconds_$packageName", 0)
                        result.success(if (remainingSeconds > 0) remainingSeconds else 0)
                    } else {
                        result.error("INVALID_ARGUMENT", "Package name is null", null)
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun isAccessibilityServiceEnabled(): Boolean {
        val expectedComponentName = "$packageName/${BlockerAccessibilityService::class.java.canonicalName}"
        val expectedShortName = "$packageName/.BlockerAccessibilityService"

        val enabledServices = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: ""

        val colonSplitter = enabledServices.split(":")
        return colonSplitter.any {
            it.equals(expectedComponentName, ignoreCase = true) ||
                    it.equals(expectedShortName, ignoreCase = true) ||
                    it.contains(packageName)
        }
    }
}