import 'dart:io';
import 'package:flutter/services.dart';

class AndroidPowerService {
  static const MethodChannel _channel = MethodChannel('bitcoinz_wallet/power_optimizations');

  static Future<bool> isIgnoringBatteryOptimizations() async {
    if (!Platform.isAndroid) return true;
    try {
      final result = await _channel.invokeMethod<bool>('isIgnoringBatteryOptimizations');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> requestIgnoreBatteryOptimizations() async {
    if (!Platform.isAndroid) return true;
    try {
      final result = await _channel.invokeMethod<bool>('requestIgnoreBatteryOptimizations');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> openBatteryOptimizationSettings() async {
    if (!Platform.isAndroid) return true;
    try {
      final result = await _channel.invokeMethod<bool>('openBatteryOptimizationSettings');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> openOEMSettings({String? manufacturer}) async {
    if (!Platform.isAndroid) return true;
    try {
      final result = await _channel.invokeMethod<bool>('openOEMSettings', {
        'manufacturer': manufacturer,
      });
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> startForegroundService() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('startForegroundService');
    } catch (_) {}
  }

  static Future<void> stopForegroundService() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('stopForegroundService');
    } catch (_) {}
  }

  static Future<void> setBootStartEnabled(bool enabled) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('setBootStartEnabled', {'enabled': enabled});
    } catch (_) {}
  }

  static Future<bool> getBootStartEnabled() async {
    if (!Platform.isAndroid) return false;
    try {
      final result = await _channel.invokeMethod<bool>('getBootStartEnabled');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }
}

