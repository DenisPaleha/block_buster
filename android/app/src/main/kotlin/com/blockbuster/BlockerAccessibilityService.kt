package com.blockbuster

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.os.CountDownTimer
import android.util.Log
import android.view.accessibility.AccessibilityEvent

class BlockerAccessibilityService : AccessibilityService() {

    private val tag = "BlockerService"
    private var countDownTimer: CountDownTimer? = null
    private var currentActivePackage: String? = null

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        try {
            if (event == null || event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return

            val pkgSequence = event.packageName ?: return
            val openedPackage = pkgSequence.toString()

            // Игнорируем пустоту, себя, системный UI, клавиатуры и системные лаунчеры
            if (openedPackage.isBlank() ||
                openedPackage == packageName ||
                openedPackage == "com.android.systemui" ||
                openedPackage.contains("inputmethod") ||
                openedPackage.contains("launcher") ||
                openedPackage.contains("home")) {
                return
            }

            val prefs = getSharedPreferences("app_blocker_prefs", Context.MODE_PRIVATE)
            val blockedPackages = prefs.getStringSet("blocked_packages", emptySet()) ?: emptySet()

            if (blockedPackages.contains(openedPackage)) {
                val now = System.currentTimeMillis()
                val deadline = prefs.getLong("deadline_$openedPackage", 0L)
                val remainingMillis = deadline - now

                Log.d(tag, "Target app opened: $openedPackage, remaining: ${remainingMillis / 1000}s")

                if (remainingMillis <= 0L) {
                    stopTimer()
                    Log.d(tag, "Deadline is in the past. HOME!")
                    performGlobalAction(GLOBAL_ACTION_HOME)
                } else {
                    // Если таймер уже тикает именно для этого пакета — не трогаем
                    if (currentActivePackage == openedPackage && countDownTimer != null) {
                        return
                    }

                    // Иначе (первый вход или восстановление после оверлея) — запускаем таймер
                    startLockTimer(openedPackage, remainingMillis)
                }
            } else {
                // Пользователь перешел в другое РЕАЛЬНОЕ приложение (не лаунчер и не система)
                if (currentActivePackage != null) {
                    Log.d(tag, "Switched to real unblocked app $openedPackage. Stopping timer.")
                    stopTimer()
                }
            }
        } catch (e: Exception) {
            Log.e(tag, "Error in onAccessibilityEvent: ${e.message}", e)
        }
    }

    private fun startLockTimer(pkg: String, durationMs: Long) {
        stopTimer()
        currentActivePackage = pkg

        Log.d(tag, "Starting CountDownTimer for $pkg on ${durationMs / 1000}s")

        // CountDownTimer принудительно держит Looper активным каждую секунду
        countDownTimer = object : CountDownTimer(durationMs, 1000L) {
            override fun onTick(millisUntilFinished: Long) {
                // Каждую секунду проверяем актуальный дедлайн
                val prefs = getSharedPreferences("app_blocker_prefs", Context.MODE_PRIVATE)
                val deadline = prefs.getLong("deadline_$pkg", 0L)
                val left = deadline - System.currentTimeMillis()

                if (left <= 0L) {
                    onFinish()
                    cancel()
                }
            }

            override fun onFinish() {
                Log.d(tag, "CountDownTimer finished -> kicking to HOME")
                try {
                    performGlobalAction(GLOBAL_ACTION_HOME)
                } catch (e: Exception) {
                    Log.e(tag, "Error performing HOME: ${e.message}")
                } finally {
                    stopTimer()
                }
            }
        }.start()
    }

    private fun stopTimer() {
        try {
            countDownTimer?.cancel()
            countDownTimer = null
        } catch (e: Exception) {
            Log.e(tag, "Error stopping timer: ${e.message}")
        } finally {
            currentActivePackage = null
        }
    }

    override fun onInterrupt() {
        stopTimer()
    }

    override fun onDestroy() {
        super.onDestroy()
        stopTimer()
    }
}