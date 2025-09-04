import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/notification_provider.dart';
import '../../services/notification_service.dart';
import '../../services/notification_test_service.dart';
import '../../widgets/notification_badge.dart';

class NotificationDebugScreen extends StatefulWidget {
  const NotificationDebugScreen({Key? key}) : super(key: key);

  @override
  State<NotificationDebugScreen> createState() => _NotificationDebugScreenState();
}

class _NotificationDebugScreenState extends State<NotificationDebugScreen> {
  Map<String, bool> _testResults = {};
  Map<String, bool> _validationResults = {};
  Map<String, dynamic> _statistics = {};
  bool _isRunningTests = false;
  bool _continuousTestingEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  void _loadStatistics() {
    setState(() {
      _statistics = NotificationTestService.instance.getTestStatistics();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Debug'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStatistics,
            tooltip: 'Refresh Statistics',
          ),
        ],
      ),
      body: Consumer<NotificationProvider>(
        builder: (context, notificationProvider, child) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Status Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Notification Status',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildStatusRow('Service Initialized', _statistics['service_initialized'] ?? false),
                      _buildStatusRow('Notifications Enabled', notificationProvider.settings.enabled),
                      _buildStatusRow('App Lifecycle', _statistics['app_lifecycle_state'] ?? 'unknown'),
                      _buildStatusRow('Unread Count', '${notificationProvider.totalUnreadCount}'),
                      _buildStatusRow('History Count', '${notificationProvider.notificationHistory.length}'),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Test Controls Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.science,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Test Controls',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      
                      // Individual test buttons
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ElevatedButton(
                            onPressed: _isRunningTests ? null : () => _runSingleTest('balance_change'),
                            child: const Text('Test Balance'),
                          ),
                          ElevatedButton(
                            onPressed: _isRunningTests ? null : () => _runSingleTest('message'),
                            child: const Text('Test Message'),
                          ),
                          ElevatedButton(
                            onPressed: _isRunningTests ? null : () => _runSingleTest('sync'),
                            child: const Text('Test Sync'),
                          ),
                          ElevatedButton(
                            onPressed: _isRunningTests ? null : () => _runSingleTest('security'),
                            child: const Text('Test Security'),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Comprehensive test button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isRunningTests ? null : _runAllTests,
                          icon: _isRunningTests 
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.play_arrow),
                          label: Text(_isRunningTests ? 'Running Tests...' : 'Run All Tests'),
                        ),
                      ),
                      
                      const SizedBox(height: 8),
                      
                      // Continuous testing toggle
                      SwitchListTile(
                        title: const Text('Continuous Testing'),
                        subtitle: const Text('Send test notifications every minute'),
                        value: _continuousTestingEnabled,
                        onChanged: _toggleContinuousTesting,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Test Results Card
              if (_testResults.isNotEmpty) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.assignment_turned_in,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Test Results',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ..._testResults.entries.map((entry) => 
                          _buildStatusRow(entry.key.replaceAll('_', ' ').toUpperCase(), entry.value)
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Validation Results Card
              if (_validationResults.isNotEmpty) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.verified,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Configuration Validation',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ..._validationResults.entries.map((entry) => 
                          _buildStatusRow(entry.key.replaceAll('_', ' ').toUpperCase(), entry.value)
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Utility Actions Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.build,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Utility Actions',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _validateConfiguration,
                              child: const Text('Validate Config'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _clearNotificationHistory,
                              child: const Text('Clear History'),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 8),
                      
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _markAllAsRead,
                              child: const Text('Mark All Read'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _cancelAllNotifications,
                              child: const Text('Cancel All'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Debug Info Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.bug_report,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Debug Information',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      
                      Text(
                        'This screen is only available in debug mode and provides tools for testing and validating the notification system.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      
                      const SizedBox(height: 8),
                      
                      Text(
                        'Platform: ${Theme.of(context).platform.name}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      
                      Text(
                        'Debug Mode: ${kDebugMode ? 'Enabled' : 'Disabled'}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatusRow(String label, dynamic value) {
    Color? color;
    IconData? icon;
    
    if (value is bool) {
      color = value ? Colors.green : Colors.red;
      icon = value ? Icons.check_circle : Icons.error;
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Text(
            value.toString(),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _runSingleTest(String testType) async {
    setState(() {
      _isRunningTests = true;
    });

    try {
      bool result = false;
      
      switch (testType) {
        case 'balance_change':
          result = await NotificationTestService.instance.testBalanceChangeNotification();
          break;
        case 'message':
          result = await NotificationTestService.instance.testMessageNotification();
          break;
        case 'sync':
          result = await NotificationTestService.instance.testSyncNotification();
          break;
        case 'security':
          result = await NotificationTestService.instance.testSecurityAlertNotification();
          break;
      }
      
      setState(() {
        _testResults[testType] = result;
      });
      
      _showSnackBar(result ? 'Test passed ✅' : 'Test failed ❌');
    } finally {
      setState(() {
        _isRunningTests = false;
      });
      _loadStatistics();
    }
  }

  Future<void> _runAllTests() async {
    setState(() {
      _isRunningTests = true;
      _testResults.clear();
    });

    try {
      final results = await NotificationTestService.instance.testAllNotificationTypes();
      setState(() {
        _testResults = results;
      });
      
      final passedCount = results.values.where((v) => v).length;
      final totalCount = results.length;
      
      _showSnackBar('Tests completed: $passedCount/$totalCount passed');
    } finally {
      setState(() {
        _isRunningTests = false;
      });
      _loadStatistics();
    }
  }

  Future<void> _validateConfiguration() async {
    final results = await NotificationTestService.instance.validateConfiguration();
    setState(() {
      _validationResults = results;
    });
    
    final passedCount = results.values.where((v) => v).length;
    final totalCount = results.length;
    
    _showSnackBar('Validation completed: $passedCount/$totalCount checks passed');
  }

  void _toggleContinuousTesting(bool enabled) {
    setState(() {
      _continuousTestingEnabled = enabled;
    });
    
    if (enabled) {
      NotificationTestService.instance.startContinuousTesting();
      _showSnackBar('Continuous testing started');
    } else {
      NotificationTestService.instance.stopContinuousTesting();
      _showSnackBar('Continuous testing stopped');
    }
  }

  void _clearNotificationHistory() {
    final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
    notificationProvider.clearNotificationHistory();
    _loadStatistics();
    _showSnackBar('Notification history cleared');
  }

  void _markAllAsRead() {
    final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
    notificationProvider.markAllNotificationsAsRead();
    _loadStatistics();
    _showSnackBar('All notifications marked as read');
  }

  void _cancelAllNotifications() {
    NotificationService.instance.cancelAllNotifications();
    _showSnackBar('All notifications cancelled');
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    if (_continuousTestingEnabled) {
      NotificationTestService.instance.stopContinuousTesting();
    }
    super.dispose();
  }
}
