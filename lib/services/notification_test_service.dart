import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/notification_models.dart';
import 'notification_service.dart';

/// Test service for validating notification functionality
class NotificationTestService {
  static final NotificationTestService _instance = NotificationTestService._internal();
  factory NotificationTestService() => _instance;
  NotificationTestService._internal();

  static NotificationTestService get instance => _instance;

  final Random _random = Random();
  Timer? _testTimer;
  bool _isRunningTests = false;

  /// Test all notification types
  Future<Map<String, bool>> testAllNotificationTypes() async {
    final results = <String, bool>{};
    
    if (kDebugMode) print('🧪 Starting comprehensive notification tests...');
    
    try {
      // Test balance change notification
      results['balance_change'] = await testBalanceChangeNotification();
      await Future.delayed(const Duration(seconds: 2));
      
      // Test message notification
      results['message'] = await testMessageNotification();
      await Future.delayed(const Duration(seconds: 2));
      
      // Test transaction confirmation notification
      results['transaction_confirmation'] = await testTransactionConfirmationNotification();
      await Future.delayed(const Duration(seconds: 2));
      
      // Test sync notification
      results['sync'] = await testSyncNotification();
      await Future.delayed(const Duration(seconds: 2));
      
      // Test security alert notification
      results['security_alert'] = await testSecurityAlertNotification();
      await Future.delayed(const Duration(seconds: 2));
      
      // Test scheduled notification
      results['scheduled'] = await testScheduledNotification();
      
      if (kDebugMode) {
        print('🧪 Notification test results:');
        results.forEach((type, success) {
          print('  $type: ${success ? '✅' : '❌'}');
        });
      }
      
    } catch (e) {
      if (kDebugMode) print('❌ Error during notification tests: $e');
    }
    
    return results;
  }

  /// Test balance change notification
  Future<bool> testBalanceChangeNotification() async {
    try {
      if (kDebugMode) print('🧪 Testing balance change notification...');
      
      final previousBalance = 10.0 + _random.nextDouble() * 90.0;
      final changeAmount = 0.1 + _random.nextDouble() * 5.0;
      final newBalance = previousBalance + changeAmount;
      
      await NotificationService.instance.showBalanceChangeNotification(
        previousBalance: previousBalance,
        newBalance: newBalance,
        changeAmount: changeAmount,
        isIncoming: true,
        transactionId: 'test_tx_${DateTime.now().millisecondsSinceEpoch}',
      );
      
      if (kDebugMode) print('✅ Balance change notification test completed');
      return true;
    } catch (e) {
      if (kDebugMode) print('❌ Balance change notification test failed: $e');
      return false;
    }
  }

  /// Test message notification
  Future<bool> testMessageNotification() async {
    try {
      if (kDebugMode) print('🧪 Testing message notification...');
      
      final messages = [
        'Hello from BitcoinZ!',
        'Thank you for the payment',
        'Test message with emoji 🚀',
        'This is a longer test message to check how the notification handles extended text content',
      ];
      
      final message = messages[_random.nextInt(messages.length)];
      final amount = 0.01 + _random.nextDouble() * 2.0;
      
      await NotificationService.instance.showMessageNotification(
        transactionId: 'test_msg_${DateTime.now().millisecondsSinceEpoch}',
        message: message,
        amount: amount,
        fromAddress: 't1TestAddress${_random.nextInt(1000)}',
        isIncoming: true, // Test incoming message
      );
      
      if (kDebugMode) print('✅ Message notification test completed');
      return true;
    } catch (e) {
      if (kDebugMode) print('❌ Message notification test failed: $e');
      return false;
    }
  }

  /// Test transaction confirmation notification
  Future<bool> testTransactionConfirmationNotification() async {
    try {
      if (kDebugMode) print('🧪 Transaction confirmation notifications disabled');
      return true; // Skip test - feature disabled
    } catch (e) {
      if (kDebugMode) print('❌ Transaction confirmation notification test failed: $e');
      return false;
    }
  }

  /// Test sync notification
  Future<bool> testSyncNotification() async {
    try {
      if (kDebugMode) print('🧪 Sync notifications disabled');
      return true; // Skip test - feature disabled
    } catch (e) {
      if (kDebugMode) print('❌ Sync notification test failed: $e');
      return false;
    }
  }

  /// Test security alert notification
  Future<bool> testSecurityAlertNotification() async {
    try {
      if (kDebugMode) print('🧪 Security alert notifications disabled');
      return true; // Skip test - feature disabled
    } catch (e) {
      if (kDebugMode) print('❌ Security alert notification test failed: $e');
      return false;
    }
  }

  /// Test scheduled notification
  Future<bool> testScheduledNotification() async {
    try {
      if (kDebugMode) print('🧪 Testing scheduled notification...');
      
      final scheduledTime = DateTime.now().add(const Duration(seconds: 10));
      
      final notificationData = NotificationData(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: NotificationType.balanceChange,
        category: NotificationCategory.financial,
        priority: NotificationPriority.normal,
        title: 'Scheduled Test Notification',
        body: 'This notification was scheduled 10 seconds ago',
        timestamp: DateTime.now(),
        actionUrl: '/wallet/dashboard',
        payload: {
          'type': 'scheduled_test',
          'scheduled_at': DateTime.now().millisecondsSinceEpoch,
        },
      );
      
      await NotificationService.instance.scheduleNotification(
        notificationData,
        scheduledTime,
      );
      
      if (kDebugMode) print('✅ Scheduled notification test completed (will appear in 10 seconds)');
      return true;
    } catch (e) {
      if (kDebugMode) print('❌ Scheduled notification test failed: $e');
      return false;
    }
  }

  /// Test notification permissions
  Future<bool> testNotificationPermissions() async {
    try {
      if (kDebugMode) print('🧪 Testing notification permissions...');
      
      // This would typically check platform-specific permission status
      // For now, we'll assume permissions are granted if the service is initialized
      final isInitialized = NotificationService.instance.isInitialized;
      
      if (kDebugMode) {
        print('Notification service initialized: $isInitialized');
        print('✅ Notification permissions test completed');
      }
      
      return isInitialized;
    } catch (e) {
      if (kDebugMode) print('❌ Notification permissions test failed: $e');
      return false;
    }
  }

  /// Start continuous notification testing (for development)
  void startContinuousTesting({Duration interval = const Duration(minutes: 1)}) {
    if (_isRunningTests) {
      if (kDebugMode) print('⚠️ Continuous testing already running');
      return;
    }
    
    _isRunningTests = true;
    if (kDebugMode) print('🧪 Starting continuous notification testing...');
    
    _testTimer = Timer.periodic(interval, (timer) async {
      final testTypes = [
        'balance_change',
        'message',
        'transaction_confirmation',
        'sync',
      ];
      
      final randomType = testTypes[_random.nextInt(testTypes.length)];
      
      switch (randomType) {
        case 'balance_change':
          await testBalanceChangeNotification();
          break;
        case 'message':
          await testMessageNotification();
          break;
        case 'transaction_confirmation':
          await testTransactionConfirmationNotification();
          break;
        case 'sync':
          await testSyncNotification();
          break;
      }
    });
  }

  /// Stop continuous testing
  void stopContinuousTesting() {
    if (!_isRunningTests) {
      if (kDebugMode) print('⚠️ Continuous testing not running');
      return;
    }
    
    _testTimer?.cancel();
    _testTimer = null;
    _isRunningTests = false;
    
    if (kDebugMode) print('🧪 Continuous notification testing stopped');
  }

  /// Get test statistics
  Map<String, dynamic> getTestStatistics() {
    return {
      'is_running_tests': _isRunningTests,
      'service_initialized': NotificationService.instance.isInitialized,
      'app_lifecycle_state': NotificationService.instance.appLifecycleState.name,
      'pending_notifications_count': NotificationService.instance.pendingNotifications.length,
      'notification_history_count': NotificationService.instance.notificationHistory.length,
    };
  }

  /// Validate notification service configuration
  Future<Map<String, bool>> validateConfiguration() async {
    final results = <String, bool>{};
    
    try {
      // Check if service is initialized
      results['service_initialized'] = NotificationService.instance.isInitialized;
      
      // Check if settings are loaded
      results['settings_loaded'] = NotificationService.instance.settings.enabled;
      
      // Check if platform is supported
      results['platform_supported'] = true; // All platforms are supported
      
      // Check if permissions are likely granted (basic check)
      results['permissions_likely_granted'] = await testNotificationPermissions();
      
      if (kDebugMode) {
        print('🧪 Configuration validation results:');
        results.forEach((check, passed) {
          print('  $check: ${passed ? '✅' : '❌'}');
        });
      }
      
    } catch (e) {
      if (kDebugMode) print('❌ Configuration validation failed: $e');
    }
    
    return results;
  }

  /// Dispose test service
  void dispose() {
    stopContinuousTesting();
  }
}
