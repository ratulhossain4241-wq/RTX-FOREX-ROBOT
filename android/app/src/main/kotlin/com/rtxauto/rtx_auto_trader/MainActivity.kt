package com.rtxauto.rtx_auto_trader

import android.content.Intent
import android.provider.Settings
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.rtxauto.rtx_auto_trader/accessibility"
    private val TAG = "RtxMainActivity"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {

                    "isAccessibilityEnabled" -> {
                        result.success(isAccessibilityServiceEnabled())
                    }

                    "openAccessibilitySettings" -> {
                        try {
                            val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            Log.e(TAG, "Failed to open accessibility settings", e)
                            result.error("OPEN_SETTINGS_FAILED", e.message, null)
                        }
                    }

                    "isMt5InForeground" -> {
                        val isMt5 = RtxAccessibilityService.instance?.isMt5Active() ?: false
                        result.success(isMt5)
                    }

                    "performAction" -> {
                        val action = call.argument<String>("action") ?: ""
                        val data = call.argument<Map<String, Any>>("data") ?: emptyMap()

                        val service = RtxAccessibilityService.instance
                        if (service == null) {
                            result.success(mapOf(
                                "success" to false,
                                "message" to "Accessibility Service চালু নেই"
                            ))
                            return@setMethodCallHandler
                        }

                        val lot = (data["lot"] as? Number)?.toDouble()
                        val sl = (data["sl"] as? Number)?.toDouble()
                        val tp = (data["tp"] as? Number)?.toDouble()

                        val success = when (action.uppercase()) {
                            "BUY" -> service.performBuy(lot, sl, tp)
                            "SELL" -> service.performSell(lot, sl, tp)
                            "CLOSE_ALL" -> service.performCloseAll()
                            else -> false
                        }

                        result.success(mapOf(
                            "success" to success,
                            "message" to if (success) "অ্যাকশন সফল" else "বাটন খুঁজে পাওয়া যায়নি বা ক্লিক ব্যর্থ"
                        ))
                    }

                    "getCurrentMt5State" -> {
                        result.success(RtxAccessibilityService.instance?.getCurrentState())
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun isAccessibilityServiceEnabled(): Boolean {
        return AccessibilityHelper.isServiceEnabled(this)
    }
}
