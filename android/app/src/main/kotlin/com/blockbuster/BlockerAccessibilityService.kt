package com.blockbuster

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.accessibility.AccessibilityEvent

class BlockerAccessibilityService : AccessibilityService() {

    private val tag = "BlockerService"
    private val handler = Handler(Looper.getMainLooper())
    private var scheduledPackage: String? = null

    private val autoLockTask = Runnable {
        try {
            Log.d(tag, "Deadline reached -> performing GLOBAL_ACTION_HOME")
            performGlobalAction(GLOBAL_ACTION_HOME)
        } catch (e: Exception) {
            Log.e(tag, "Error performing home action: ${e.message}")
        } finally {
            scheduledPackage = null
        }
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        try {
            if (event == null || event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return

            val pkgSequence = event.packageName ?: return
            val openedPackage = pkgSequence.toString()

            // Игнорируем пустые имена, себя, системный UI и клавиатуры
            if (openedPackage.isBlank() ||
                openedPackage == packageName ||
                openedPackage == "com.android.systemui" ||
                openedPackage.contains("inputmethod")) {
                return
            }

            val prefs = getSharedPreferences("app_blocker_prefs", Context.MODE_PRIVATE)
            val blockedPackages = prefs.getStringSet("blocked_packages", emptySet()) ?: emptySet()

            if (blockedPackages.contains(openedPackage)) {
                val now = System.currentTimeMillis()
                val deadline = prefs.getLong("deadline_$openedPackage", 0L)
                val remainingMillis = deadline - now

                if (remainingMillis <= 0L) {
                    cancelScheduledLock()
                    Log.d(tag, "App $openedPackage is locked. Minimizing.")
                    performGlobalAction(GLOBAL_ACTION_HOME)
                } else {
                    // Всегда гарантированно перевзводим таймер на точный остаток времени
                    cancelScheduledLock()
                    scheduledPackage = openedPackage
                    Log.d(tag, "Scheduling lock for $openedPackage in ${remainingMillis / 1000}s")
                    handler.postDelayed(autoLockTask, remainingMillis)
                }
            } else {
                // Пользователь вышел из заблокированного приложения — снимаем таймер
                cancelScheduledLock()
            }
        } catch (e: Exception) {
            Log.e(tag, "Unhandled error in onAccessibilityEvent: ${e.message}", e)
        }
    }

    private fun cancelScheduledLock() {
        try {
            handler.removeCallbacks(autoLockTask)
        } catch (e: Exception) {
            Log.e(tag, "Error cancelling lock: ${e.message}")
        } finally {
            scheduledPackage = null
        }
    }

    override fun onInterrupt() {
        cancelScheduledLock()
    }

    override fun onDestroy() {
        super.onDestroy()
        cancelScheduledLock()
    }
}