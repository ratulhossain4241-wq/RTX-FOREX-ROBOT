package com.rtxauto.rtx_auto_trader

import android.accessibilityservice.AccessibilityService
import android.os.Handler
import android.os.Looper
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.view.accessibility.AccessibilityWindowInfo
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/// এই Accessibility Service শুধু স্ক্রিন "পড়ে" — কোনো ক্লিক/টাইপ করে না।
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

    fun scheduleDelayedDump(delaySeconds: Int) {
        handler.postDelayed({
            dumpToFile()
        }, delaySeconds * 1000L)
    }

    /// ✅ বড় ফিক্স: আগে শুধু rootInActiveWindow ব্যবহার করা হতো, যেটা
    /// শুধু "focused" window-এর রুট দেয়। কিন্তু RTX-এর নিজস্ব floating
    /// bubble overlay MT5-এর ওপর ভাসমান থাকায় Android মাঝে মাঝে কোনো
    /// windowকেই স্পষ্টভাবে "active/focused" চিহ্নিত করে না, ফলে
    /// rootInActiveWindow null আসে যদিও MT5 আসলে স্ক্রিনে দৃশ্যমান।
    /// এখন windows (getWindows()) লিস্ট থেকে সব দৃশ্যমান window ঘেঁটে
    /// আমাদের নিজের অ্যাপ বাদে প্রথম "application" টাইপ window খুঁজে
    /// বের করে সেটার রুট ব্যবহার করা হচ্ছে — এটা "active" এর ওপর
    /// নির্ভর করে না, তাই অনেক বেশি নির্ভরযোগ্য।
    fun dumpToFile(): String? {
        val dir = getExternalFilesDir(null) ?: filesDir
        val dumpFolder = File(dir, "mt5_dumps")
        if (!dumpFolder.exists()) dumpFolder.mkdirs()

        val fileName = "dump_${SimpleDateFormat("yyyyMMdd_HHmmss", Locale.getDefault()).format(Date())}.txt"
        val file = File(dumpFolder, fileName)

        val targetRoot = findBestTargetRoot()

        if (targetRoot == null) {
            val windowSummary = buildWindowSummary()
            file.writeText(
                "❌ ব্যর্থ: কোনো উপযুক্ত window পাওয়া যায়নি।\n" +
                "সম্ভাব্য কারণ:\n" +
                "1. MT5 অ্যাপ তখন স্ক্রিনে ছিল না (৫ সেকেন্ডের মধ্যে সুইচ করা হয়নি)\n" +
                "2. Accessibility Service সিস্টেম দ্বারা বন্ধ হয়ে গেছে\n" +
                "3. স্ক্রিন লক ছিল বা ফোন স্লিপে চলে গিয়েছিল\n\n" +
                "এই মুহূর্তে সিস্টেম যেসব window দেখতে পেয়েছে:\n$windowSummary\n" +
                "Dump Time: ${SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.getDefault()).format(Date())}\n"
            )
            return file.absolutePath
        }

        val sb = StringBuilder()
        sb.append("Package: ${targetRoot.packageName}\n")
        sb.append("Dump Time: ${SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.getDefault()).format(Date())}\n")
        sb.append("=".repeat(60)).append("\n\n")

        dumpNode(targetRoot, 0, sb)
        file.writeText(sb.toString())

        return file.absolutePath
    }

    /// স্ক্রিনে থাকা সব window ঘেঁটে আমাদের নিজের প্যাকেজ বাদে প্রথম
    /// "application" টাইপ window-এর রুট নোড খুঁজে দেয়। না পেলে
    /// rootInActiveWindow-কে শেষ চেষ্টা হিসেবে ব্যবহার করে।
    private fun findBestTargetRoot(): AccessibilityNodeInfo? {
        try {
            val windowList = windows
            if (windowList != null && windowList.isNotEmpty()) {
                // প্রথমে TYPE_APPLICATION টাইপ, আমাদের নিজের প্যাকেজ বাদে খোঁজা
                for (window: AccessibilityWindowInfo in windowList) {
                    if (window.type == AccessibilityWindowInfo.TYPE_APPLICATION) {
                        val root = window.root
                        if (root != null && root.packageName != packageName) {
                            return root
                        }
                    }
                }
                // সেটা না পেলে, আমাদের নিজের প্যাকেজ বাদে যেকোনো window
                for (window: AccessibilityWindowInfo in windowList) {
                    val root = window.root
                    if (root != null && root.packageName != packageName) {
                        return root
                    }
                }
            }
        } catch (e: Exception) {
            // windows API ব্যর্থ হলে নিচের fallback-এ যাওয়া হবে
        }

        // শেষ চেষ্টা — পুরনো পদ্ধতি
        return rootInActiveWindow
    }

    private fun buildWindowSummary(): String {
        return try {
            val windowList = windows
            if (windowList == null || windowList.isEmpty()) {
                "(কোনো window পাওয়া যায়নি — windows() null বা খালি)"
            } else {
                windowList.joinToString("\n") { w ->
                    "- type=${w.type} package=${w.root?.packageName ?: "?"} title=${w.title ?: "?"}"
                }
            }
        } catch (e: Exception) {
            "(windows() কল করতে সমস্যা হয়েছে: ${e.message})"
        }
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
