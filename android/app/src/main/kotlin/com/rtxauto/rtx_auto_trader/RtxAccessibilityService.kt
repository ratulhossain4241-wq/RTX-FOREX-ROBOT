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
        // বর্তমানে শুধু ইভেন্ট রিসিভ করছি। পরে প্রয়োজন হলে এখানে লাইভ মনিটরিং যোগ করা যাবে।
    }

    override fun onInterrupt() {
        Log.w(TAG, "Accessibility Service Interrupted")
    }

    override fun onDestroy() {
        super.onDestroy()
        instance = null
        Log.i(TAG, "Accessibility Service Destroyed")
    }

    /** MetaTrader 5 বর্তমানে অ্যাকটিভ আছে কিনা */
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
        return mapOf(
            "isMt5" to isMt5Active(),
            "hasRoot" to (rootInActiveWindow != null)
        )
    }
}
