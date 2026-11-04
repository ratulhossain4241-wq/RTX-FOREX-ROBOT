package com.rtxauto.rtx_auto_trader

import android.content.Context
import android.provider.Settings
import android.text.TextUtils
import android.util.Log

object AccessibilityHelper {

    private const val TAG = "AccessibilityHelper"

    fun isServiceEnabled(context: Context): Boolean {
        val expectedComponent = "\( {context.packageName}/ \){RtxAccessibilityService::class.java.canonicalName}"
        val enabledServices = Settings.Secure.getString(
            context.contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false

        val colonSplitter = TextUtils.SimpleStringSplitter(':')
        colonSplitter.setString(enabledServices)

        while (colonSplitter.hasNext()) {
            val component = colonSplitter.next()
            if (component.equals(expectedComponent, ignoreCase = true)) {
                return true
            }
        }
        return false
    }
}
