import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/notification_provider.dart';
import '../../models/notification_models.dart';
import '../../widgets/notification_badge.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Settings'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
      ),
      body: Consumer<NotificationProvider>(
        builder: (context, notificationProvider, child) {
          final settings = notificationProvider.settings;
          
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Main toggle
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.notifications, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Enable Notifications', style: Theme.of(context).textTheme.titleMedium),
                            Text('Receive notifications for wallet activity', style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                      ),
                      Switch(
                        value: settings.enabled,
                        onChanged: (value) => notificationProvider.toggleNotifications(value),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Notification types
              if (settings.enabled) ...[
                Text('Notification Types', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                
                _buildNotificationTypeCard(
                  context, notificationProvider,
                  icon: Icons.account_balance_wallet,
                  title: 'Balance Changes',
                  subtitle: 'Get notified when you receive funds',
                  value: settings.balanceChangeEnabled,
                  onChanged: notificationProvider.toggleBalanceChangeNotifications,
                ),
                
                _buildNotificationTypeCard(
                  context, notificationProvider,
                  icon: Icons.message,
                  title: 'Messages',
                  subtitle: 'Get notified when you receive transaction messages',
                  value: settings.messageNotificationsEnabled,
                  onChanged: notificationProvider.toggleMessageNotifications,
                ),
                
                const SizedBox(height: 24),
                
                // Sound and vibration settings
                Text('Sound & Vibration', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: Icon(
                          settings.soundEnabled ? Icons.volume_up : Icons.volume_off,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        title: const Text('Sound'),
                        subtitle: const Text('Play sound for notifications'),
                        trailing: Switch(
                          value: settings.soundEnabled,
                          onChanged: notificationProvider.toggleSound,
                        ),
                      ),
                      
                      const Divider(height: 1),
                      ListTile(
                        leading: Icon(
                          settings.vibrationEnabled ? Icons.vibration : Icons.phone_android,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        title: const Text('Vibration'),
                        subtitle: const Text('Vibrate for notifications'),
                        trailing: Switch(
                          value: settings.vibrationEnabled,
                          onChanged: notificationProvider.toggleVibration,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Advanced settings
                Text('Advanced Settings', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: Icon(Icons.bedtime, color: Theme.of(context).colorScheme.primary),
                        title: const Text('Quiet Hours'),
                        subtitle: Text(
                          settings.quietHoursEnabled
                              ? 'Enabled (${_formatHour(settings.quietHoursStart)} - ${_formatHour(settings.quietHoursEnd)})'
                              : 'Disabled',
                        ),
                        trailing: Switch(
                          value: settings.quietHoursEnabled,
                          onChanged: notificationProvider.toggleQuietHours,
                        ),
                      ),
                    ],
                  ),
                ),
                
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildNotificationTypeCard(
    BuildContext context,
    NotificationProvider notificationProvider, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: Switch(value: value, onChanged: onChanged),
      ),
    );
  }

  String _formatHour(int hour) {
    if (hour == 0) return '12:00 AM';
    if (hour < 12) return '$hour:00 AM';
    if (hour == 12) return '12:00 PM';
    return '${hour - 12}:00 PM';
  }

}
