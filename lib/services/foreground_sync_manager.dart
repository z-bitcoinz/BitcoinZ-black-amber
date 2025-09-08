import 'dart:io';
import 'package:flutter/foundation.dart';
import 'android_power_service.dart';

/// Minimal helper to ensure the foreground service runs when app goes background
class ForegroundSyncManager {
  static bool _started = false;

  static Future<void> onAppPaused() async {
    if (!Platform.isAndroid) return;
    if (_started) return;
    await AndroidPowerService.startForegroundService();
    if (kDebugMode) print('▶️ Foreground service requested on pause');
    _started = true;
  }

  static Future<void> onAppResumed() async {
    if (!Platform.isAndroid) return;
    if (!_started) return;
    await AndroidPowerService.stopForegroundService();
    if (kDebugMode) print('⏹ Foreground service stop requested on resume');
    _started = false;
  }
}

