package com.example.flutter_app

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings

object OemSettingsHelper {
    fun openManufacturerSettings(context: Context, manufacturer: String = Build.MANUFACTURER.lowercase()): Boolean {
        return try {
            val intent = when {
                manufacturer.contains("huawei") -> Intent().apply {
                    setClassName("com.huawei.systemmanager", "com.huawei.systemmanager.optimize.process.ProtectActivity")
                }
                manufacturer.contains("xiaomi") -> Intent("miui.intent.action.POWER_HIDE_MODE_APP_LIST").apply {
                    addCategory(Intent.CATEGORY_DEFAULT)
                }
                manufacturer.contains("oppo") -> Intent().apply {
                    setClassName("com.coloros.oppoguardelf", "com.coloros.oppoguardelf.MonitoredPackageActivity")
                }
                manufacturer.contains("vivo") -> Intent().apply {
                    setClassName("com.vivo.abe", "com.vivo.applicationbehaviorengine.ui.ExcessivePowerManagerActivity")
                }
                manufacturer.contains("samsung") -> Intent().apply {
                    action = Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS
                    data = Uri.parse("package:${context.packageName}")
                }
                else -> Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
            }
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(intent)
            true
        } catch (e: Exception) {
            try {
                val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                context.startActivity(intent)
                true
            } catch (_: Exception) {
                false
            }
        }
    }
}

