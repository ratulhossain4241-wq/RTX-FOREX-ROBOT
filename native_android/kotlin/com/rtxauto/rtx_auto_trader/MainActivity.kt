package com.rtxauto.rtx_auto_trader

import android.content.ComponentName
import android.content.Intent
import android.provider.Settings
import android.text.TextUtils
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "rtx_auto_trader/native"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isAccessibilityServiceEnabled" -> {
                    result.success(isAccessibilityServiceEnabled())
                }
                "openAccessibilitySettings" -> {
                    startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                    result.success(null)
                }
                // ✅ বড় ফিক্স: আগে এই কল ৫ সেকেন্ড ধরে "result" কলব্যাক
                // পেন্ডিং রাখত। কিন্তু ইউজার MT5-এ সুইচ করার সময় Android
                // এই Activity-কে background-এ থাকা অবস্থায় recreate/kill
                // করে দিতে পারে (মেমোরি ম্যানেজমেন্টের কারণে) — তখন সেই
                // পুরনো পেন্ডিং result callback হারিয়ে যায়, কোনো error
                // ছাড়াই। এখন এই কল সাথে সাথেই "scheduled=true" রিটার্ন
                // করে, আর আসল dump কাজ AccessibilityService-এর নিজস্ব
                // Handler দিয়ে independent ভাবে চলে — Activity বাঁচুক বা
                // মরুক তাতে কিছু আসে যায় না, কারণ AccessibilityService
                // MainActivity-এর lifecycle-এর সাথে বাঁধা না।
                "scheduleDump" -> {
                    val delaySeconds = (call.argument<Int>("delaySeconds") ?: 5)
                    val service = NodeDumperService.getInstance()
                    if (service == null) {
                        result.error(
                            "SERVICE_NOT_RUNNING",
                            "Accessibility Service চালু নেই — আগে সেটিংস থেকে এনাবল করুন।",
                            null
                        )
                    } else {
                        service.scheduleDelayedDump(delaySeconds)
                        result.success(true)
                    }
                }
                "listDumps" -> {
                    result.success(listDumpFiles())
                }
                "readDump" -> {
                    val fileName = call.argument<String>("fileName")
                    if (fileName == null) {
                        result.error("BAD_ARGS", "fileName দেওয়া হয়নি।", null)
                    } else {
                        result.success(readDumpFile(fileName))
                    }
                }
                "deleteDump" -> {
                    val fileName = call.argument<String>("fileName")
                    if (fileName == null) {
                        result.error("BAD_ARGS", "fileName দেওয়া হয়নি।", null)
                    } else {
                        result.success(deleteDumpFile(fileName))
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun isAccessibilityServiceEnabled(): Boolean {
        val enabledServices = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false

        if (TextUtils.isEmpty(enabledServices)) return false

        val splitter = TextUtils.SimpleStringSplitter(':')
        splitter.setString(enabledServices)

        while (splitter.hasNext()) {
            val componentString = splitter.next()
            val component = ComponentName.unflattenFromString(componentString) ?: continue
            if (component.packageName == packageName &&
                component.className == "$packageName.NodeDumperService"
            ) {
                return true
            }
        }
        return false
    }

    private fun dumpDir(): java.io.File {
        val dir = getExternalFilesDir(null) ?: filesDir
        val dumpFolder = java.io.File(dir, "mt5_dumps")
        if (!dumpFolder.exists()) dumpFolder.mkdirs()
        return dumpFolder
    }

    private fun listDumpFiles(): List<String> {
        return dumpDir().listFiles()
            ?.filter { it.isFile && it.name.endsWith(".txt") }
            ?.sortedByDescending { it.lastModified() }
            ?.map { it.name }
            ?: emptyList()
    }

    private fun readDumpFile(fileName: String): String {
        val file = java.io.File(dumpDir(), fileName)
        return if (file.exists()) file.readText() else ""
    }

    private fun deleteDumpFile(fileName: String): Boolean {
        val file = java.io.File(dumpDir(), fileName)
        return if (file.exists()) file.delete() else false
    }
}
