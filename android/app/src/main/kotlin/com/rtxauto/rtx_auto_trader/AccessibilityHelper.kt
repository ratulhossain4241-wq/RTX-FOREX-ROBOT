package com.rtxauto.rtx_auto_trader

import android.content.ComponentName
import android.content.Context
import android.provider.Settings
import android.text.TextUtils

object AccessibilityHelper {

    /**
     * RtxAccessibilityService চালু আছে কিনা চেক করে।
     * ComponentName দিয়ে মেলানো হয়, তাই ফোন full form (pkg/pkg.Class)
     * বা short form (pkg/.Class) যেভাবেই সংরক্ষণ করুক, ঠিকভাবে কাজ করবে।
     */
    fun isServiceEnabled(context: Context): Boolean {
        val expected = ComponentName(context, RtxAccessibilityService::class.java)

        val enabledServices = Settings.Secure.getString(
            context.contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false

        val colonSplitter = TextUtils.SimpleStringSplitter(':')
        colonSplitter.setString(enabledServices)

        while (colonSplitter.hasNext()) {
            val component = ComponentName.unflattenFromString(colonSplitter.next())
            if (component != null && component == expected) {
                return true
            }
        }
        return false
    }
}
