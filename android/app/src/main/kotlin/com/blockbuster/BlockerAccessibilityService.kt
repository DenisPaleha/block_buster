package com.blockbuster

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.view.accessibility.AccessibilityEvent

class BlockerAccessibilityService : AccessibilityService() {

    private val handler = Handler(Looper.getMainLooper())
    private var currentActivePackage: String? = null

    // Таймер списывает 1 секунду каждую секунду, пока запрещенное приложение на экране
    private val timeTicker = object : Runnable {
        override fun run() {
            val pkg = currentActivePackage ?: return
            val prefs = getSharedPreferences("app_blocker_prefs", Context.MODE_PRIVATE)
            val currentSeconds = prefs.getInt("time_left_$pkg", 0)

            if (currentSeconds > 1) {
                prefs.edit().putInt("time_left_$pkg", currentSeconds - 1).apply()
                handler.postDelayed(this, 1000)
            } else {
                // Время истекло — сбрасываем в 0, выкидываем на Home Screen
                prefs.edit().putInt("time_left_$pkg", 0).apply()
                performGlobalAction(GLOBAL_ACTION_HOME)
                stopTracking()
            }
        }
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event?.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return
        val openedPackage = event.packageName?.toString() ?: return

        // Не реагируем на собственное приложение и системный лаунчер
        if (openedPackage == packageName) return

        val prefs = getSharedPreferences("app_blocker_prefs", Context.MODE_PRIVATE)
        val blockedPackages = prefs.getStringSet("blocked_packages", emptySet()) ?: emptySet()

        if (blockedPackages.contains(openedPackage)) {
            val timeLeft = prefs.getInt("time_left_$openedPackage", 0)

            if (timeLeft <= 0) {
                // Обороты не накручены / лимит кончился — мгновенный сброс на рабочий стол
                performGlobalAction(GLOBAL_ACTION_HOME)
                stopTracking()
            } else {
                // Лимит есть — стартуем или продолжаем тиканье
                if (currentActivePackage != openedPackage) {
                    stopTracking()
                    currentActivePackage = openedPackage
                    handler.post(timeTicker)
                }
            }
        } else {
            // Пользователь перешел в разрешенное приложение — ставим списание на паузу
            stopTracking()
        }
    }

    private fun stopTracking() {
        handler.removeCallbacks(timeTicker)
        currentActivePackage = null
    }

    override fun onInterrupt() {
        stopTracking()
    }

    override fun onDestroy() {
        super.onDestroy()
        stopTracking()
    }
}