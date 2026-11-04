package com.rtxauto.rtx_auto_trader

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.util.Log

/**
 * RTX Auto Trader Accessibility Service
 * শুধু MetaTrader 5 প্যাকেজ স্ক্যান করে এবং Buy/Sell/Close অ্যাকশন সাপোর্ট করে।
 * এটি প্রাথমিক ভার্সন — পরবর্তী ব্যাচে আরও শক্তিশালী Node Finder যোগ করা হবে।
 */
class RtxAccessibilityService : AccessibilityService() {

    companion object {
        private const val TAG = "RtxAccessibility"
        var instance: RtxAccessibilityService? = null
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        Log.i(TAG, "Accessibility Service Connected")
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // প্রাথমিক ভার্সনে শুধু ইভেন্ট রিসিভ করছি
        // পরবর্তী আপডেটে এখানে রিয়েল-টাইম স্ক্যান লজিক যোগ হবে
    }

    override fun onInterrupt() {
        Log.w(TAG, "Accessibility Service Interrupted")
    }

    override fun onDestroy() {
        super.onDestroy()
        instance = null
    }

    /**
     * রুট নোড থেকে টেক্সট খুঁজে ক্লিক করার প্রাথমিক হেল্পার
     */
    fun findAndClickByText(text: String): Boolean {
        val root = rootInActiveWindow ?: return false
        val nodes = root.findAccessibilityNodeInfosByText(text)
        for (node in nodes) {
            if (node.isClickable) {
                node.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                return true
            }
            // প্যারেন্ট ক্লিকেবল হতে পারে
            var parent = node.parent
            while (parent != null) {
                if (parent.isClickable) {
                    parent.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                    return true
                }
                parent = parent.parent
            }
        }
        return false
    }
}
