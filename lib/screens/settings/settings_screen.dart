import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'currency_settings_screen.dart';
import 'change_pin_screen.dart';
import 'backup_wallet_screen.dart';
import 'help_screen.dart';
import 'network_settings_screen.dart';
import '../../providers/currency_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/network_provider.dart';

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
        automaticallyImplyLeading: false,
      ),
      body: Consumer<CurrencyProvider>(
        builder: (context, currencyProvider, child) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Currency Settings
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
                ],
              ),
              
              const SizedBox(height: 24),
              
              _buildSettingsSection(
                title: 'About',
                children: [
                  _buildSettingsTile(
                    context: context,
                    icon: Icons.info,
                    title: 'App Version',
                    subtitle: '1.0.0',
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