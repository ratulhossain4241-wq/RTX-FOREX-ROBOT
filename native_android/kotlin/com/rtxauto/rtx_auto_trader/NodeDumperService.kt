package com.rtxauto.rtx_auto_trader

import android.accessibilityservice.AccessibilityService
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/// এই Accessibility Service শুধু স্ক্রিন "পড়ে" — কোনো ক্লিক/টাইপ করে না।
/// উদ্দেশ্য শুধু MT5 অ্যাপের UI এলিমেন্টগুলোর resourceId/text/bounds
/// বের করে একটা ফাইলে সেভ করা, যাতে পরে Trade Executor বানানোর সময়
/// সেই তথ্য ব্যবহার করা যায়। এটা সম্পূর্ণ read-only, তাই নিরাপদ।
class NodeDumperService : AccessibilityService() {

    companion object {
        private var instance: NodeDumperService? = null
        fun getInstance(): NodeDumperService? = instance
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
    }

    override fun onDestroy() {
        instance = null
        super.onDestroy()
    }

    // এই সার্ভিস কোনো event-এ প্রতিক্রিয়া দেখায় না — শুধু on-demand dump করে,
    // তাই এই ফাংশন ইচ্ছাকৃতভাবে খালি রাখা হয়েছে।
    override fun onAccessibilityEvent(event: AccessibilityEvent?) {}

    override fun onInterrupt() {}

    /// বর্তমানে স্ক্রিনে যা আছে (ধরে নিচ্ছি MT5 অ্যাপ সামনে আছে) তার পুরো
    /// node tree পড়ে একটা টেক্সট ফাইলে লেখে। সফল হলে ফাইলের path রিটার্ন
    /// করে, active window না পেলে null রিটার্ন করে।
    fun dumpToFile(): String? {
        val root = rootInActiveWindow ?: return null

        val sb = StringBuilder()
        sb.append("Package: ${root.packageName}\n")
        sb.append("Dump Time: ${SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.getDefault()).format(Date())}\n")
        sb.append("=".repeat(60)).append("\n\n")

        dumpNode(root, 0, sb)

        val dir = getExternalFilesDir(null) ?: filesDir
        val dumpFolder = File(dir, "mt5_dumps")
        if (!dumpFolder.exists()) dumpFolder.mkdirs()

        val fileName = "dump_${SimpleDateFormat("yyyyMMdd_HHmmss", Locale.getDefault()).format(Date())}.txt"
        val file = File(dumpFolder, fileName)
        file.writeText(sb.toString())

        return file.absolutePath
    }

    /// একটা নোড আর তার সব children রিকার্সিভলি প্রিন্ট করে — প্রতিটা
    /// নোডে class name, text, content-description, resource-id,
    /// clickable কি না, আর স্ক্রিনের কোন অবস্থানে (bounds) আছে তা থাকে।
    /// এই তথ্যগুলোই পরে Trade Executor-এ বাটন খুঁজে বের করতে ব্যবহার হবে।
    private fun dumpNode(node: AccessibilityNodeInfo, depth: Int, sb: StringBuilder) {
        val indent = "  ".repeat(depth)
        val bounds = android.graphics.Rect()
        node.getBoundsInScreen(bounds)

        val className = node.className ?: "?"
        val text = node.text?.toString()?.replace("\n", " ") ?: ""
        val desc = node.contentDescription?.toString()?.replace("\n", " ") ?: ""
        val resId = node.viewIdResourceName ?: ""
        val clickable = if (node.isClickable) "CLICKABLE" else ""

        sb.append("$indent[$className]")
        if (resId.isNotEmpty()) sb.append(" id=$resId")
        if (text.isNotEmpty()) sb.append(" text=\"$text\"")
        if (desc.isNotEmpty()) sb.append(" desc=\"$desc\"")
        sb.append(" bounds=$bounds")
        if (clickable.isNotEmpty()) sb.append(" $clickable")
        sb.append("\n")

        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            dumpNode(child, depth + 1, sb)
        }
    }
}
