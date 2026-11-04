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
        Log.i(TAG, "RTX Accessibility Service Connected")
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // প্রয়োজন হলে পরে রিয়েল-টাইম মনিটরিং যোগ করা যাবে
    }

    override fun onInterrupt() {
        Log.w(TAG, "Service Interrupted")
    }

    override fun onDestroy() {
        super.onDestroy()
        instance = null
    }

    fun isMt5Active(): Boolean {
        val root = rootInActiveWindow ?: return false
        val pkg = root.packageName?.toString() ?: return false
        return pkg == "net.metaquotes.metatrader5"
    }

    fun performBuy(): Boolean {
        val root = rootInActiveWindow ?: return false
        return Mt5NodeFinder.performBuy(root)
    }

    fun performSell(): Boolean {
        val root = rootInActiveWindow ?: return false
        return Mt5NodeFinder.performSell(root)
    }

    fun performCloseAll(): Boolean {
        val root = rootInActiveWindow ?: return false
        return Mt5NodeFinder.performClose(root)
    }

    fun getCurrentState(): Map<String, Any?> {
        val root = rootInActiveWindow
        return mapOf(
            "isMt5" to isMt5Active(),
            "hasRoot" to (root != null)
        )
    }
}
