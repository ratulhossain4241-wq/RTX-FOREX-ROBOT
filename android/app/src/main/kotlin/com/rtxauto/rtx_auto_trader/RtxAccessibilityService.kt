package com.rtxauto.rtx_auto_trader

import android.accessibilityservice.AccessibilityService
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

class RtxAccessibilityService : AccessibilityService() {

    companion object {
        private const val TAG = "RtxAccessibility"
        var instance: RtxAccessibilityService? = null
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        Log.i(TAG, "RTX Accessibility Service Connected Successfully")
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // Reserved for future
    }

    override fun onInterrupt() {
        Log.w(TAG, "Accessibility Service Interrupted")
    }

    override fun onDestroy() {
        super.onDestroy()
        instance = null
        Log.i(TAG, "Accessibility Service Destroyed")
    }

    fun isMt5Active(): Boolean {
        val root = rootInActiveWindow ?: return false
        val pkg = root.packageName?.toString() ?: return false
        return pkg == "net.metaquotes.metatrader5"
    }

    fun performBuy(lotSize: Double? = null, sl: Double? = null, tp: Double? = null): Boolean {
        val root = rootInActiveWindow ?: return false

        if (lotSize != null && lotSize > 0) {
            Mt5NodeFinder.setVolume(root, lotSize)
            Thread.sleep(250)
        }

        if (sl != null && sl > 0) {
            Mt5AdvancedActions.trySetStopLoss(root, sl)
            Thread.sleep(200)
        }

        if (tp != null && tp > 0) {
            Mt5AdvancedActions.trySetTakeProfit(root, tp)
            Thread.sleep(200)
        }

        return Mt5NodeFinder.performBuy(root)
    }

    fun performSell(lotSize: Double? = null, sl: Double? = null, tp: Double? = null): Boolean {
        val root = rootInActiveWindow ?: return false

        if (lotSize != null && lotSize > 0) {
            Mt5NodeFinder.setVolume(root, lotSize)
            Thread.sleep(250)
        }

        if (sl != null && sl > 0) {
            Mt5AdvancedActions.trySetStopLoss(root, sl)
            Thread.sleep(200)
        }

        if (tp != null && tp > 0) {
            Mt5AdvancedActions.trySetTakeProfit(root, tp)
            Thread.sleep(200)
        }

        return Mt5NodeFinder.performSell(root)
    }

    fun performCloseAll(): Boolean {
        val root = rootInActiveWindow ?: return false
        return Mt5NodeFinder.performClose(root)
    }

    fun getCurrentState(): Map<String, Any?> {
        return mapOf(
            "isMt5" to isMt5Active(),
            "hasRoot" to (rootInActiveWindow != null)
        )
    }
}
