import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/android_power_service.dart';
import '../../providers/wallet_provider.dart';

class BackgroundPowerSettingsScreen extends StatefulWidget {
  const BackgroundPowerSettingsScreen({super.key});

  @override
  State<BackgroundPowerSettingsScreen> createState() => _BackgroundPowerSettingsScreenState();
}

class _BackgroundPowerSettingsScreenState extends State<BackgroundPowerSettingsScreen> {
  bool _batteryExempt = false;
  bool _bootStartEnabled = false;
  bool _serviceRunning = false;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    if (!Platform.isAndroid) return;
    final exempt = await AndroidPowerService.isIgnoringBatteryOptimizations();
    final boot = await AndroidPowerService.getBootStartEnabled();
    setState(() {
      _batteryExempt = exempt;
      _bootStartEnabled = boot;
      _checking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Background Operation'),
      ),
      body: _checking
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: SwitchListTile(
                    value: _batteryExempt,
                    onChanged: (v) async {
                      if (v) {
                        await AndroidPowerService.requestIgnoreBatteryOptimizations();
                      } else {
                        await AndroidPowerService.openBatteryOptimizationSettings();
                      }
                      await _loadState();
                    },
                    secondary: const Icon(Icons.battery_alert),
                    title: const Text('Exclude from Battery Optimization'),
                    subtitle: const Text('Recommended to keep sync and notifications reliable'),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Column(
                    children: [
                      SwitchListTile(
                        value: _serviceRunning,
                        onChanged: (v) async {
                          final walletProvider = Provider.of<WalletProvider>(context, listen: false);
                          if (v) {
                            await AndroidPowerService.startForegroundService();
                            walletProvider.startAutoSync();
                          } else {
                            await AndroidPowerService.stopForegroundService();
                            walletProvider.stopAutoSync();
                          }
                          setState(() => _serviceRunning = v);
                        },
                        secondary: const Icon(Icons.sync),
                        title: const Text('Keep Wallet Sync Running'),
                        subtitle: const Text('Runs a foreground service with a small notification'),
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        value: _bootStartEnabled,
                        onChanged: (v) async {
                          await AndroidPowerService.setBootStartEnabled(v);
                          setState(() => _bootStartEnabled = v);
                        },
                        secondary: const Icon(Icons.power_settings_new),
                        title: const Text('Start After Reboot'),
                        subtitle: const Text('Resume monitoring after device restarts'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (Platform.isAndroid)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.settings_power),
                      title: const Text('Open Manufacturer Power Settings'),
                      subtitle: const Text('Samsung, Xiaomi/MIUI, Huawei, Oppo, Vivo...'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        await AndroidPowerService.openOEMSettings();
                      },
                    ),
                  ),
                const SizedBox(height: 8),
                const Text(
                  'Tip: On some devices, you may also need to lock the app in recent apps or allow unlimited background activity.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
    );
  }
}

