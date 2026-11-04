package com.rtxauto.rtx_auto_trader

import android.util.Log
import android.view.accessibility.AccessibilityNodeInfo

object Mt5NodeFinder {

    private const val TAG = "Mt5NodeFinder"

    private val BUY_TEXTS = listOf(
        "Buy", "BUY", "Buy by Market", "Buy Limit", "Buy Stop",
        "Buy Order", "Market Buy", "ক্রয়", "কিনুন"
    )

    private val SELL_TEXTS = listOf(
        "Sell", "SELL", "Sell by Market", "Sell Limit", "Sell Stop",
        "Sell Order", "Market Sell", "বিক্রয়", "বেচুন"
    )

    private val CLOSE_TEXTS = listOf(
        "Close", "CLOSE", "Close position", "Close all", "Close Position",
        "বন্ধ করুন", "ক্লোজ", "বন্ধ"
    )

    fun performBuy(root: AccessibilityNodeInfo?): Boolean {
        return clickByPossibleTexts(root, BUY_TEXTS)
    }

    fun performSell(root: AccessibilityNodeInfo?): Boolean {
        return clickByPossibleTexts(root, SELL_TEXTS)
    }

    fun performClose(root: AccessibilityNodeInfo?): Boolean {
        return clickByPossibleTexts(root, CLOSE_TEXTS)
    }

    private fun clickByPossibleTexts(root: AccessibilityNodeInfo?, texts: List<String>): Boolean {
        if (root == null) {
            Log.w(TAG, "Root node is null")
            return false
        }

        for (text in texts) {
            val nodes = root.findAccessibilityNodeInfosByText(text)
            if (nodes.isNullOrEmpty()) continue

            for (node in nodes) {
                if (tryClick(node)) {
                    Log.i(TAG, "Successfully clicked: $text")
                    return true
                }
            }
        }

        Log.w(TAG, "No clickable node found for given texts")
        return false
    }

    private fun tryClick(node: AccessibilityNodeInfo?): Boolean {
        if (node == null) return false

        // নিজেই ক্লিকেবল হলে
        if (node.isClickable && node.isEnabled) {
            return node.performAction(AccessibilityNodeInfo.ACTION_CLICK)
        }

        // প্যারেন্ট খুঁজে দেখা
        var parent = node.parent
        var depth = 0
        while (parent != null && depth < 6) {
            if (parent.isClickable && parent.isEnabled) {
                val result = parent.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                parent.recycle()
                return result
            }
            val next = parent.parent
            parent.recycle()
            parent = next
            depth++
        }
        return false
    }
}
