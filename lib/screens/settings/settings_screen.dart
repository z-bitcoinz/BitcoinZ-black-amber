import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'currency_settings_screen.dart';
import 'change_pin_screen.dart';
import 'backup_wallet_screen.dart';
import 'help_screen.dart';
import 'analytics_help_screen.dart';
import 'network_settings_screen.dart';
import 'notification_settings_screen.dart';
import 'background_power_settings_screen.dart';
import 'about_screen.dart';
import '../analytics/financial_analytics_screen.dart';
import 'contacts_backup_screen.dart';
import '../../providers/currency_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/network_provider.dart';
import '../../providers/contact_provider.dart';
import '../../providers/interface_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/notification_provider.dart';

import '../../services/bitcoinz_rust_service.dart';
import '../../services/database_service.dart';
import '../../services/storage_service.dart';
import '../../services/wallet_storage_service.dart';
import '../onboarding/welcome_screen.dart';
import 'package:flutter/foundation.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 48.0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Consumer2<CurrencyProvider, InterfaceProvider>(
        builder: (context, currencyProvider, interfaceProvider, child) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Display Settings
              _buildSettingsSection(
                title: 'Display',
                children: [
                  _buildSettingsTile(
                    context: context,
                    icon: Icons.attach_money,
                    title: 'Fiat Currency',
                    subtitle: currencyProvider.selectedCurrency.name,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          currencyProvider.selectedCurrency.code,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CurrencySettingsScreen(),
                        ),
                      );
                    },
                  ),
                  _buildSettingsTile(
                    context: context,
                    icon: Icons.analytics,
                    title: 'Show Analytics Tab',
                    subtitle: interfaceProvider.analyticsTabVisible
                        ? 'Analytics tab visible in main navigation'
                        : 'Analytics tab hidden (accessible via Settings)',
                    trailing: Switch(
                      value: interfaceProvider.analyticsTabVisible,
                      onChanged: (value) {
                        interfaceProvider.setAnalyticsTabVisible(value);
                      },
                      activeColor: Theme.of(context).colorScheme.primary,
                    ),
                    onTap: () {
                      interfaceProvider.toggleAnalyticsTabVisible();
                    },
                  ),
                  _buildSettingsTile(
                    context: context,
                    icon: Icons.format_list_numbered,
                    title: 'Show Decimals',
                    subtitle: interfaceProvider.showDecimals
                        ? 'Show digits after the decimal point'
                        : 'Hide the fractional part (BTCZ)',
                    trailing: Switch(
                      value: interfaceProvider.showDecimals,
                      onChanged: (value) {
                        interfaceProvider.setShowDecimals(value);
                      },
                      activeColor: Theme.of(context).colorScheme.primary,
                    ),
                    onTap: () {
                      interfaceProvider.toggleShowDecimals();
                    },
                  ),
                ],
              ),

              // Power & Background
              if (Platform.isAndroid)
                _buildSettingsSection(
                  title: 'Background & Power',
                  children: [
                    _buildSettingsTile(
                      context: context,
                      icon: Icons.battery_saver,
                      title: 'Background Operation',
                      subtitle: 'Keep wallet syncing in background',
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const BackgroundPowerSettingsScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),


              const SizedBox(height: 24),

              // Network settings
              Consumer<NetworkProvider>(
                builder: (context, networkProvider, child) {
                  final currentServer = networkProvider.getServerInfo(networkProvider.currentServerUrl);
                  return _buildSettingsSection(
                    title: 'Network',
                    children: [
                      _buildSettingsTile(
                        context: context,
                        icon: Icons.wifi,
                        title: 'Server Settings',
                        subtitle: currentServer?.displayName ?? 'Unknown Server',
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (networkProvider.currentServerInfo != null)
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            const SizedBox(width: 8),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const NetworkSettingsScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 24),

              // Notification settings
              Consumer<NotificationProvider>(
                builder: (context, notificationProvider, child) {
                  return _buildSettingsSection(
                    title: 'Notifications',
                    children: [
                      _buildSettingsTile(
                        context: context,
                        icon: Icons.notifications,
                        title: 'Notification Settings',
                        subtitle: notificationProvider.settings.enabled
                            ? 'Enabled'
                            : 'Disabled',
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: notificationProvider.settings.enabled
                                    ? Colors.green
                                    : Colors.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const NotificationSettingsScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 24),

              // Security settings
              _buildSettingsSection(
                title: 'Security',
                children: [
                  _buildSettingsTile(
                    context: context,
                    icon: Icons.lock,
                    title: 'Change PIN',
                    subtitle: 'Update your wallet PIN',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ChangePinScreen(),
                        ),
                      );
                    },
                  ),
                  Consumer<AuthProvider>(
                    builder: (context, authProvider, child) {
                      return FutureBuilder<bool>(
                        future: authProvider.isBiometricsAvailable(),
                        builder: (context, snapshot) {
                          final isAvailable = snapshot.data ?? false;
                          if (!isAvailable) return const SizedBox.shrink();

                          return _buildSettingsTile(
                            context: context,
                            icon: Icons.fingerprint,
                            title: 'Biometric Authentication',
                            subtitle: authProvider.biometricsEnabled
                                ? 'Enabled'
                                : 'Disabled',
                            trailing: Switch(
                              value: authProvider.biometricsEnabled,
                              onChanged: (value) async {
                                await authProvider.setBiometricsEnabled(value);
                              },
                              activeColor: Theme.of(context).colorScheme.primary,
                            ),
                            onTap: null,
                          );
                        },
                      );
                    },
                  ),
                  _buildSettingsTile(
                    context: context,
                    icon: Icons.backup,
                    title: 'Backup Wallet',
                    subtitle: 'View seed phrase',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const BackupWalletScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Contacts section
              Consumer<ContactProvider>(
                builder: (context, contactProvider, child) {
                  return _buildSettingsSection(
                    title: 'Contacts',
                    children: [
                      _buildSettingsTile(
                        context: context,
                        icon: Icons.backup,
                        title: 'Backup & Restore Contacts',
                        subtitle: contactProvider.hasContacts
                            ? '${contactProvider.contactsCount} contact${contactProvider.contactsCount == 1 ? '' : 's'}'
                            : 'No contacts to backup',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ContactsBackupScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 24),

              // Help & Support section
              _buildSettingsSection(
                title: 'Help & Support',
                children: [
                  _buildSettingsTile(
                    context: context,
                    icon: Icons.help_outline,
                    title: 'Balance & Transactions Guide',
                    subtitle: 'Learn about balance types and transaction states',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const HelpScreen(),
                        ),
                      );
                    },
                  ),
                  _buildSettingsTile(
                    context: context,
                    icon: Icons.analytics,
                    title: 'Analytics & Address Labels Guide',
                    subtitle: 'Learn how to use financial analytics and address labeling',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AnalyticsHelpScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Analytics Access section (always available)
              _buildSettingsSection(
                title: 'Analytics & Tools',
                children: [
                  _buildSettingsTile(
                    context: context,
                    icon: Icons.analytics,
                    title: 'Financial Analytics',
                    subtitle: interfaceProvider.analyticsTabVisible
                        ? 'View detailed financial insights and trends'
                        : 'Access analytics (tab hidden from main navigation)',
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!interfaceProvider.analyticsTabVisible)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              'DIRECT ACCESS',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        const SizedBox(width: 8),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const FinancialAnalyticsScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: 24),

              _buildDangerZoneSection(context),

              const SizedBox(height: 24),

              _buildSettingsSection(
                title: 'About',
                children: [
                  _buildSettingsTile(
                    context: context,
                    icon: Icons.info,
                    title: 'About BitcoinZ Wallet',
                    subtitle: 'Your Keys, Your Coins, Your Freedom',
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AboutScreen(),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1, color: Colors.white24),
                  _buildSettingsTile(
                    context: context,
                    icon: Icons.verified,
                    title: 'App Version',
                    subtitle: 'v0.8.1',
                    onTap: null,
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSettingsSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withOpacity(0.08),
              width: 1,
            ),
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }



  Widget _buildDangerZoneSection(BuildContext context) {
    return _buildSettingsSection(
      title: 'Danger Zone',
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: ElevatedButton.icon(
            icon: const Icon(Icons.delete_forever),
            label: const Text('Wipe Wallet (Kill Switch)'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) {
                      return AlertDialog(
                        title: const Text('Wipe Wallet?'),
                        content: const Text(
                          'This will delete your seed phrase, wallet data, cached DB, and settings on this device. '
                          'Make sure you have your seed backed up. This action cannot be undone.'
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                            onPressed: () => Navigator.of(ctx).pop(true),
                            child: const Text('Wipe Wallet'),
                          ),
                        ],
                      );
                    },
                  ) ??
                  false;

              if (!confirmed) return;

              try {
                // Stop rust timers and deinitialize
                final rust = BitcoinzRustService.instance;
                await rust.dispose();

                // Clear database completely
                await DatabaseService.forceReset();

                // Clear secure/shared storage (seed, walletId, PIN, wallet_data)
                await StorageService.deleteAll();

                // Remove only Black Amber app data directories (safe, scoped)
                try {
                  final walletDir = await WalletStorageService.getWalletDataDirectory();
                  final cacheDir = await WalletStorageService.getCacheDirectory();
                  final settingsDir = await WalletStorageService.getSettingsDirectory();

                  // Safety guard: ensure paths contain our app subfolder
                  bool isSafePath(String p) => p.contains(WalletStorageService.appDirName);

                  if (isSafePath(walletDir.path) && await walletDir.exists()) {
                    await walletDir.delete(recursive: true);
                  }
                  if (isSafePath(cacheDir.path) && await cacheDir.exists()) {
                    await cacheDir.delete(recursive: true);
                  }
                  if (isSafePath(settingsDir.path) && await settingsDir.exists()) {
                    await settingsDir.delete(recursive: true);
                  }
                } catch (_) {}

                // Clear wallet provider in-memory state
                final wallet = Provider.of<WalletProvider>(context, listen: false);
                wallet.clearWallet();

                if (!mounted) return;

                // Navigate to onboarding welcome screen
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                  (route) => false,
                );

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(Platform.isIOS
                        ? '✅ Wallet wiped. Force close app then reopen to start restore.'
                        : '✅ Wallet wiped. Start restore to test sync UI.'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('❌ Wipe failed: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
          ),
        ),
      ],
    );
  }



  Widget _buildSettingsTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 13,
                        ),
                      ),
                    ],


                  ],
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
        ),
      ),
    );
  }
}