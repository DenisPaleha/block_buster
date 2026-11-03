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

            // Игнорируем системные оверлеи, лаунчеры, клавиатуры и сам Block Buster
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
                val currentBankSeconds = prefs.getInt("bank_seconds_$openedPackage", 0)

                Log.d(tag, "Target app opened: $openedPackage, bank: ${currentBankSeconds}s")

                if (currentBankSeconds <= 0) {
                    stopTimer()
                    Log.d(tag, "Bank is 0s. Immediate HOME!")
                    performGlobalAction(GLOBAL_ACTION_HOME)
                } else {
                    // Если таймер уже запущен для этого приложения — продолжаем отсчет
                    if (currentActivePackage == openedPackage && countDownTimer != null) {
                        return
                    }

                    startBankTicker(openedPackage, currentBankSeconds)
                }
            } else {
                // Пользователь переключился в другое стороннее приложение или рабочий экран
                if (currentActivePackage != null) {
                    Log.d(tag, "Switched away from $currentActivePackage to $openedPackage. Pausing bank.")
                    stopTimer()
                }
            }
        } catch (e: Exception) {
            Log.e(tag, "Error in onAccessibilityEvent: ${e.message}", e)
        }
    }

    private fun startBankTicker(pkg: String, startSeconds: Int) {
        stopTimer()
        currentActivePackage = pkg

        Log.d(tag, "Starting Bank Ticker for $pkg with $startSeconds seconds")

        // Запускаем таймер на количество оставшихся секунд с шагом 1 сек
        countDownTimer = object : CountDownTimer(startSeconds * 1000L, 1000L) {
            override fun onTick(millisUntilFinished: Long) {
                val prefs = getSharedPreferences("app_blocker_prefs", Context.MODE_PRIVATE)
                val bank = prefs.getInt("bank_seconds_$pkg", 0)

                if (bank <= 1) {
                    // Время закончилось прямо на тике
                    prefs.edit().putInt("bank_seconds_$pkg", 0).apply()
                    onFinish()
                    cancel()
                } else {
                    // Декрементируем банк на 1 секунду
                    prefs.edit().putInt("bank_seconds_$pkg", bank - 1).apply()
                }
            }

            override fun onFinish() {
                Log.d(tag, "Bank depleted for $pkg -> kicking to HOME")
                val prefs = getSharedPreferences("app_blocker_prefs", Context.MODE_PRIVATE)
                prefs.edit().putInt("bank_seconds_$pkg", 0).apply()

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