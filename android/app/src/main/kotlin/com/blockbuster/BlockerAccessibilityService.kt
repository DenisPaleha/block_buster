package com.blockbuster

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.view.accessibility.AccessibilityEvent

class BlockerAccessibilityService : AccessibilityService() {

    private val handler = Handler(Looper.getMainLooper())
    private var currentActivePackage: String? = null
    private var lastTickTimestamp: Long = 0L
    private var isTickerRunning = false

    private val timeTicker = object : Runnable {
        override fun run() {
            val pkg = currentActivePackage
            if (pkg == null) {
                isTickerRunning = false
                return
            }

            val now = SystemClock.elapsedRealtime()
            val elapsedSeconds = ((now - lastTickTimestamp) / 1000).toInt()

            if (elapsedSeconds >= 1) {
                lastTickTimestamp = now
                val prefs = getSharedPreferences("app_blocker_prefs", Context.MODE_PRIVATE)
                val currentSeconds = prefs.getInt("time_left_$pkg", 0)
                val newSeconds = (currentSeconds - elapsedSeconds).coerceAtLeast(0)

                prefs.edit().putInt("time_left_$pkg", newSeconds).apply()

                if (newSeconds <= 0) {
                    // Время вышло — блокируем и отправляем на рабочий стол
                    performGlobalAction(GLOBAL_ACTION_HOME)
                    stopTracking()
                    return
                }
            }

            // Перезапускаем тикер строго в одном экземпляре
            handler.postDelayed(this, 1000)
        }
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null || event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return
        val openedPackage = event.packageName?.toString() ?: return

        // Пропускаем собственное приложение, системный UI и клавиатуры
        if (openedPackage == packageName ||
            openedPackage == "com.android.systemui" ||
            openedPackage.contains("inputmethod")) {
            return
        }

        val prefs = getSharedPreferences("app_blocker_prefs", Context.MODE_PRIVATE)
        val blockedPackages = prefs.getStringSet("blocked_packages", emptySet()) ?: emptySet()

        if (blockedPackages.contains(openedPackage)) {
            val timeLeft = prefs.getInt("time_left_$openedPackage", 0)

            if (timeLeft <= 0) {
                // Времени нет — мгновенный сброс
                performGlobalAction(GLOBAL_ACTION_HOME)
                stopTracking()
            } else {
                // Если приложение уже трекается — не плодим параллельные таймеры
                if (currentActivePackage != openedPackage) {
                    stopTracking()
                    currentActivePackage = openedPackage
                    lastTickTimestamp = SystemClock.elapsedRealtime()
                    isTickerRunning = true
                    handler.post(timeTicker)
                }
            }
        } else {
            // Пользователь свернул заблокированное приложение или перешел в другое разрешенное
            stopTracking()
        }
    }

    private fun stopTracking() {
        handler.removeCallbacks(timeTicker)
        currentActivePackage = null
        isTickerRunning = false
    }

    override fun onInterrupt() {
        stopTracking()
    }

    override fun onDestroy() {
        super.onDestroy()
        stopTracking()
    }
}