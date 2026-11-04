package com.rtxauto.rtx_auto_trader

import android.view.accessibility.AccessibilityNodeInfo
import android.util.Log

/**
 * MetaTrader 5 UI থেকে নির্দিষ্ট বাটন ও টেক্সট খুঁজে বের করার দায়িত্ব এই ক্লাসের।
 * বিভিন্ন ব্রোকার ও থিমে টেক্সট আলাদা হতে পারে, তাই একাধিক সম্ভাব্য টেক্সট চেষ্টা করা হয়।
 */
object Mt5NodeFinder {

    private const val TAG = "Mt5NodeFinder"

    // সম্ভাব্য Buy বাটন টেক্সট
    private val BUY_TEXTS = listOf(
        "Buy", "BUY", "Buy by Market", "Buy Limit", "Buy Stop",
        "ক্রয়", "কিনুন"
    )

    // সম্ভাব্য Sell বাটন টেক্সট
    private val SELL_TEXTS = listOf(
        "Sell", "SELL", "Sell by Market", "Sell Limit", "Sell Stop",
        "বিক্রয়", "বেচুন"
    )

    // Close সংক্রান্ত টেক্সট
    private val CLOSE_TEXTS = listOf(
        "Close", "CLOSE", "Close position", "Close all",
        "বন্ধ", "ক্লোজ"
    )

    /**
     * রুট নোড থেকে নির্দিষ্ট টেক্সটের ক্লিকেবল নোড খুঁজে ক্লিক করে।
     */
    fun clickByPossibleTexts(root: AccessibilityNodeInfo?, texts: List<String>): Boolean {
        if (root == null) return false

        for (text in texts) {
            val nodes = root.findAccessibilityNodeInfosByText(text)
            for (node in nodes) {
                if (tryClick(node)) {
                    Log.i(TAG, "Clicked on text: $text")
                    return true
                }
            }
        }
        return false
    }

    private fun tryClick(node: AccessibilityNodeInfo?): Boolean {
        if (node == null) return false

        if (node.isClickable) {
            return node.performAction(AccessibilityNodeInfo.ACTION_CLICK)
        }

        // প্যারেন্ট চেক করা
        var parent = node.parent
        var depth = 0
        while (parent != null && depth < 5) {
            if (parent.isClickable) {
                val clicked = parent.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                parent.recycle()
                return clicked
            }
            val next = parent.parent
            parent.recycle()
            parent = next
            depth++
        }
        return false
    }

    fun performBuy(root: AccessibilityNodeInfo?): Boolean {
        return clickByPossibleTexts(root, BUY_TEXTS)
    }

    fun performSell(root: AccessibilityNodeInfo?): Boolean {
        return clickByPossibleTexts(root, SELL_TEXTS)
    }

    fun performClose(root: AccessibilityNodeInfo?): Boolean {
        return clickByPossibleTexts(root, CLOSE_TEXTS)
    }
}
