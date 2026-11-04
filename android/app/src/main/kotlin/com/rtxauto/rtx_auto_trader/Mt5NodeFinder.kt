package com.rtxauto.rtx_auto_trader

import android.util.Log
import android.view.accessibility.AccessibilityNodeInfo

object Mt5NodeFinder {

    private const val TAG = "Mt5NodeFinder"

    private val BUY_TEXTS = listOf(
        "Buy", "BUY", "Buy by Market", "Buy Limit", "Buy Stop",
        "Buy Order", "Market Buy", "Buy Market", "ক্রয়", "কিনুন", "Buy now"
    )

    private val SELL_TEXTS = listOf(
        "Sell", "SELL", "Sell by Market", "Sell Limit", "Sell Stop",
        "Sell Order", "Market Sell", "Sell Market", "বিক্রয়", "বেচুন", "Sell now"
    )

    private val CLOSE_TEXTS = listOf(
        "Close", "CLOSE", "Close position", "Close all", "Close Position",
        "Close By", "বন্ধ করুন", "ক্লোজ", "বন্ধ", "Close order"
    )

    private val VOLUME_HINTS = listOf(
        "Volume", "Lot", "Lots", "Size", "ভলিউম", "লট"
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

    /**
     * Volume ফিল্ড খুঁজে ভ্যালু সেট করার চেষ্টা করে।
     * সফল হলে true রিটার্ন করে।
     */
    fun setVolume(root: AccessibilityNodeInfo?, lotSize: Double): Boolean {
        if (root == null) return false

        // প্রথমে Volume লেবেল খুঁজে তার পাশের এডিট টেক্সট খুঁজি
        for (hint in VOLUME_HINTS) {
            val nodes = root.findAccessibilityNodeInfosByText(hint)
            for (node in nodes) {
                val edit = findNearbyEditable(node)
                if (edit != null) {
                    val success = setTextOnNode(edit, lotSize.toString())
                    if (success) {
                        Log.i(TAG, "Volume set to $lotSize")
                        return true
                    }
                }
            }
        }

        // সরাসরি editable ফিল্ড খুঁজে দেখা (fallback)
        val editables = findAllEditableNodes(root)
        if (editables.isNotEmpty()) {
            // সাধারণত প্রথম editable ফিল্ডটাই volume হয় অনেক UI-তে
            val success = setTextOnNode(editables.first(), lotSize.toString())
            if (success) {
                Log.i(TAG, "Volume set via fallback editable")
                return true
            }
        }

        Log.w(TAG, "Could not set volume")
        return false
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

        Log.w(TAG, "No clickable node found")
        return false
    }

    private fun tryClick(node: AccessibilityNodeInfo?): Boolean {
        if (node == null) return false

        if (node.isClickable && node.isEnabled) {
            return node.performAction(AccessibilityNodeInfo.ACTION_CLICK)
        }

        var parent = node.parent
        var depth = 0
        while (parent != null && depth < 7) {
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

    private fun findNearbyEditable(node: AccessibilityNodeInfo): AccessibilityNodeInfo? {
        // নিজেই editable কিনা
        if (node.isEditable) return node

        // ভাইবোন খুঁজে দেখা
        val parent = node.parent ?: return null
        for (i in 0 until parent.childCount) {
            val child = parent.getChild(i) ?: continue
            if (child.isEditable) return child
        }

        // এক ধাপ উপরে গিয়ে আবার খোঁজা
        val grandParent = parent.parent
        if (grandParent != null) {
            for (i in 0 until grandParent.childCount) {
                val child = grandParent.getChild(i) ?: continue
                if (child.isEditable) return child
            }
        }
        return null
    }

    private fun findAllEditableNodes(root: AccessibilityNodeInfo): List<AccessibilityNodeInfo> {
        val result = mutableListOf<AccessibilityNodeInfo>()
        collectEditables(root, result)
        return result
    }

    private fun collectEditables(node: AccessibilityNodeInfo?, list: MutableList<AccessibilityNodeInfo>) {
        if (node == null) return
        if (node.isEditable) {
            list.add(node)
        }
        for (i in 0 until node.childCount) {
            collectEditables(node.getChild(i), list)
        }
    }

    private fun setTextOnNode(node: AccessibilityNodeInfo, text: String): Boolean {
        val arguments = android.os.Bundle()
        arguments.putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, text)
        return node.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, arguments)
    }
}
