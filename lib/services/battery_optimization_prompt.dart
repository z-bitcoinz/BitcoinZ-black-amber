import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter/material.dart';
import 'android_power_service.dart';

class BatteryOptimizationPrompt {
  static const _shownKey = 'battery_prompt_shown_v1';

  static Future<void> maybePrompt(BuildContext context) async {
    if (!Platform.isAndroid) return;
    final already = await _getShown();
    if (already) return;

    final exempt = await AndroidPowerService.isIgnoringBatteryOptimizations();
    if (exempt) {
      await _setShown(true);
      return;
    }

    if (!context.mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Allow background operation'),
          content: const Text(
            'To keep your BitcoinZ wallet in sync and receive notifications, please allow the app to run in the background without battery restrictions.',
          ),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await AndroidPowerService.openOEMSettings();
              },
              child: const Text('Device settings'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await AndroidPowerService.requestIgnoreBatteryOptimizations();
              },
              child: const Text('Allow'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
              },
              child: const Text('Later'),
            ),
          ],
        );
      },
    );

    await _setShown(true);
  }

  static Future<bool> _getShown() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_shownKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> _setShown(bool v) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_shownKey, v);
    } catch (_) {}
  }
}

