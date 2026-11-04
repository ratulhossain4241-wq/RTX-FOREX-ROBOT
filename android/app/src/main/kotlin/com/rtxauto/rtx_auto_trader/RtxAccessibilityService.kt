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
        // Reserved for future live monitoring
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

    fun performBuy(lotSize: Double? = null): Boolean {
        val root = rootInActiveWindow ?: return false

        // আগে volume সেট করার চেষ্টা
        if (lotSize != null && lotSize > 0) {
            Mt5NodeFinder.setVolume(root, lotSize)
            // একটু সময় দেওয়া ভালো
            Thread.sleep(300)
        }

        return Mt5NodeFinder.performBuy(root)
    }

    fun performSell(lotSize: Double? = null): Boolean {
        val root = rootInActiveWindow ?: return false

        if (lotSize != null && lotSize > 0) {
            Mt5NodeFinder.setVolume(root, lotSize)
            Thread.sleep(300)
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
