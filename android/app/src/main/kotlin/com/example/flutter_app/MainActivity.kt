package com.example.flutter_app

import android.content.Intent
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val channelName = "bitcoinz_wallet/power_optimizations"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "isIgnoringBatteryOptimizations" -> {
                    val pm = getSystemService(POWER_SERVICE) as PowerManager
                    val isIgnoring = pm.isIgnoringBatteryOptimizations(packageName)
                    result.success(isIgnoring)
                }
                "requestIgnoreBatteryOptimizations" -> {
                    try {
                        val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
                        intent.data = android.net.Uri.parse("package:$packageName")
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("intent_error", e.message, null)
                    }
                }
                "openBatteryOptimizationSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("intent_error", e.message, null)
                    }
                }
                "startForegroundService" -> {
                    try {
                        val intent = Intent(this, WalletSyncForegroundService::class.java)
                        intent.action = WalletSyncForegroundService.ACTION_START
                        ContextCompat.startForegroundService(this, intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("service_error", e.message, null)
                    }
                }
                "stopForegroundService" -> {
                    try {
                        val intent = Intent(this, WalletSyncForegroundService::class.java)
                        intent.action = WalletSyncForegroundService.ACTION_STOP
                        ContextCompat.startForegroundService(this, intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("service_error", e.message, null)
                    }
                }
                "openOEMSettings" -> {
                    val manufacturer = (call.argument<String>("manufacturer") ?: Build.MANUFACTURER).lowercase()
                    val success = OemSettingsHelper.openManufacturerSettings(this, manufacturer)
                    result.success(success)
                }
                "setBootStartEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    val prefs = getSharedPreferences("bitcoinz_prefs", MODE_PRIVATE)
                    prefs.edit().putBoolean("boot_start_enabled", enabled).apply()
                    result.success(true)
                }
                "getBootStartEnabled" -> {
                    val prefs = getSharedPreferences("bitcoinz_prefs", MODE_PRIVATE)
                    result.success(prefs.getBoolean("boot_start_enabled", false))
                }
                else -> result.notImplemented()
            }
        }
    }
}
