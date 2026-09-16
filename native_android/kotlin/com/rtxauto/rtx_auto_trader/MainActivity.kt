package com.rtxauto.rtx_auto_trader

import android.content.ComponentName
import android.content.Intent
import android.os.Handler
import android.os.Looper
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
                // ✅ ফিক্স: এই অ্যাপে বাটন চাপার মুহূর্তে এই অ্যাপই "active
                // window" থাকে, MT5 না — তাই সাথে সাথে dump করলে সবসময়
                // "active window পাওয়া যায়নি" এরর আসবে। এখন একটা
                // delaySeconds প্যারামিটার নেওয়া হচ্ছে — ইউজার এই সময়ের
                // মধ্যে MT5-এ সুইচ করবে, তারপর Handler.postDelayed দিয়ে
                // দেরিতে dump করা হবে। এই Handler মেইন Activity বন্ধ/পজড
                // হলেও (ইউজার অন্য অ্যাপে গেলে) প্রসেস জীবিত থাকা পর্যন্ত
                // কাজ করতে থাকে।
                "dumpNow" -> {
                    val delaySeconds = (call.argument<Int>("delaySeconds") ?: 5)
                    Handler(Looper.getMainLooper()).postDelayed({
                        val service = NodeDumperService.getInstance()
                        if (service == null) {
                            result.error(
                                "SERVICE_NOT_RUNNING",
                                "Accessibility Service চালু নেই — আগে সেটিংস থেকে এনাবল করুন।",
                                null
                            )
                        } else {
                            val filePath = service.dumpToFile()
                            if (filePath != null) {
                                result.success(filePath)
                            } else {
                                result.error(
                                    "DUMP_FAILED",
                                    "কোনো active window পাওয়া যায়নি — MT5 অ্যাপ সামনে আছে কি না চেক করুন।",
                                    null
                                )
                            }
                        }
                    }, delaySeconds * 1000L)
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
