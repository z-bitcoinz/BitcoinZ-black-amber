package com.example.flutter_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.content.ContextCompat

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val prefs = context.getSharedPreferences("bitcoinz_prefs", Context.MODE_PRIVATE)
        val enabled = prefs.getBoolean("boot_start_enabled", false)
        if (!enabled) return

        val startIntent = Intent(context, WalletSyncForegroundService::class.java).apply {
            action = WalletSyncForegroundService.ACTION_START
        }
        ContextCompat.startForegroundService(context, startIntent)
    }
}

