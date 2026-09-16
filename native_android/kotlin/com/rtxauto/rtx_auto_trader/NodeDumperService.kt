package com.rtxauto.rtx_auto_trader

import android.accessibilityservice.AccessibilityService
import android.os.Handler
import android.os.Looper
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/// এই Accessibility Service শুধু স্ক্রিন "পড়ে" — কোনো ক্লিক/টাইপ করে না।
/// ✅ scheduleDelayedDump() এখন এই Service-এর নিজস্ব Handler ব্যবহার করে,
/// যেটা MainActivity-এর lifecycle-এর সাথে বাঁধা না। তাই ইউজার MT5-এ
/// সুইচ করার সময় MainActivity recreate/pause হলেও এই delayed dump
/// কাজটা নির্বিঘ্নে চলতে থাকে (যতক্ষণ পুরো অ্যাপ প্রসেস বেঁচে থাকে
/// এবং Accessibility Service সিস্টেম থেকে বন্ধ না করা হয়)।
class NodeDumperService : AccessibilityService() {

    companion object {
        private var instance: NodeDumperService? = null
        fun getInstance(): NodeDumperService? = instance
    }

    private val handler = Handler(Looper.getMainLooper())

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
    }

    override fun onDestroy() {
        instance = null
        handler.removeCallbacksAndMessages(null)
        super.onDestroy()
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {}

    override fun onInterrupt() {}

    /// নির্দিষ্ট সময় পর dumpToFile() কল করে — এই কল MainActivity বা
    /// Flutter engine-এর ওপর নির্ভর করে না, তাই সেগুলো ব্যাকগ্রাউন্ডে
    /// pause/recreate হলেও এই শিডিউল করা কাজ প্রভাবিত হয় না।
    fun scheduleDelayedDump(delaySeconds: Int) {
        handler.postDelayed({
            dumpToFile()
        }, delaySeconds * 1000L)
    }

    /// বর্তমানে স্ক্রিনে যা আছে তার পুরো node tree পড়ে একটা টেক্সট
    /// ফাইলে লেখে। সফল হলে ফাইলের path রিটার্ন করে, active window না
    /// পেলে null রিটার্ন করে (কিন্তু ব্যর্থতাও ফাইলে লগ করা হয়, যাতে
    /// ডিবাগ করা সহজ হয়)।
    fun dumpToFile(): String? {
        val dir = getExternalFilesDir(null) ?: filesDir
        val dumpFolder = File(dir, "mt5_dumps")
        if (!dumpFolder.exists()) dumpFolder.mkdirs()

        val root = rootInActiveWindow
        val fileName = "dump_${SimpleDateFormat("yyyyMMdd_HHmmss", Locale.getDefault()).format(Date())}.txt"
        val file = File(dumpFolder, fileName)

        if (root == null) {
            // ✅ ব্যর্থ হলেও একটা ফাইল লেখা হচ্ছে, যাতে ইউজার/আমরা বুঝতে
            // পারি ঠিক কী কারণে dump ফাঁকা এলো (আগে এই তথ্য হারিয়ে যেত)।
            file.writeText(
                "❌ ব্যর্থ: rootInActiveWindow পাওয়া যায়নি।\n" +
                "সম্ভাব্য কারণ:\n" +
                "1. MT5 অ্যাপ তখন সামনে ছিল না (৫ সেকেন্ডের মধ্যে সুইচ করা হয়নি)\n" +
                "2. MT5-এর প্যাকেজ নাম accessibility_dumper_config.xml-এর packageNames-এ নেই\n" +
                "3. Accessibility Service সিস্টেম দ্বারা বন্ধ হয়ে গেছে\n" +
                "Dump Time: ${SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.getDefault()).format(Date())}\n"
            )
            return file.absolutePath
        }

        val sb = StringBuilder()
        sb.append("Package: ${root.packageName}\n")
        sb.append("Dump Time: ${SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.getDefault()).format(Date())}\n")
        sb.append("=".repeat(60)).append("\n\n")

        dumpNode(root, 0, sb)
        file.writeText(sb.toString())

        return file.absolutePath
    }

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
