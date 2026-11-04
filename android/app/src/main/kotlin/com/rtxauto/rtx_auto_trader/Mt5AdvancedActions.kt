package com.rtxauto.rtx_auto_trader

import android.os.Bundle
import android.util.Log
import android.view.accessibility.AccessibilityNodeInfo

/**
 * SL এবং TP ফিল্ডে ভ্যালু বসানোর চেষ্টা করে।
 * অনেক MT5 UI-তে এটা সফল হয় না, তাই best-effort হিসেবে রাখা হয়েছে।
 */
object Mt5AdvancedActions {

    private const val TAG = "Mt5AdvancedActions"

    private val SL_HINTS = listOf(
        "Stop Loss", "SL", "S/L", "StopLoss", "স্টপ লস"
    )

    private val TP_HINTS = listOf(
        "Take Profit", "TP", "T/P", "TakeProfit", "টেক প্রফিট"
    )

    fun trySetStopLoss(root: AccessibilityNodeInfo?, value: Double): Boolean {
        return trySetField(root, SL_HINTS, value)
    }

    fun trySetTakeProfit(root: AccessibilityNodeInfo?, value: Double): Boolean {
        return trySetField(root, TP_HINTS, value)
    }

    private fun trySetField(
        root: AccessibilityNodeInfo?,
        hints: List<String>,
        value: Double
    ): Boolean {
        if (root == null) return false

        for (hint in hints) {
            val nodes = root.findAccessibilityNodeInfosByText(hint)
            for (node in nodes) {
                val editable = findNearbyEditable(node)
                if (editable != null) {
                    val success = setText(editable, value.toString())
                    if (success) {
                        Log.i(TAG, "Set $hint = $value")
                        return true
                    }
                }
            }
        }
        return false
    }

    private fun findNearbyEditable(node: AccessibilityNodeInfo): AccessibilityNodeInfo? {
        if (node.isEditable) return node

        val parent = node.parent ?: return null
        for (i in 0 until parent.childCount) {
            val child = parent.getChild(i) ?: continue
            if (child.isEditable) return child
        }

        val grandParent = parent.parent
        if (grandParent != null) {
            for (i in 0 until grandParent.childCount) {
                val child = grandParent.getChild(i) ?: continue
                if (child.isEditable) return child
            }
        }
        return null
    }

    private fun setText(node: AccessibilityNodeInfo, text: String): Boolean {
        val args = Bundle()
        args.putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, text)
        return node.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, args)
    }
}
