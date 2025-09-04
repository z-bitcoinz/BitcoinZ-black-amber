import 'dart:async';
import 'dart:isolate';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'notification_service.dart';
import '../models/notification_models.dart';

/// Background service for handling notifications when app is closed
class BackgroundNotificationService {
  static const String _isolateName = 'background_notification_isolate';
  static const MethodChannel _backgroundChannel = MethodChannel('bitcoinz_wallet/background_notifications');
  
  static SendPort? _isolateSendPort;
  static Isolate? _backgroundIsolate;
  
  /// Initialize background notification service
  static Future<void> initialize() async {
    try {
      // Register the isolate
      final receivePort = ReceivePort();
      _backgroundIsolate = await Isolate.spawn(
        _backgroundIsolateEntryPoint,
        receivePort.sendPort,
      );
      
      // Get the send port from the isolate
      _isolateSendPort = await receivePort.first as SendPort;
      
      // Register the isolate with the Flutter engine
      IsolateNameServer.registerPortWithName(
        receivePort.sendPort,
        _isolateName,
      );
      
      if (kDebugMode) print('🔔 Background notification service initialized');
    } catch (e) {
      if (kDebugMode) print('❌ Failed to initialize background notification service: $e');
    }
  }
  
  /// Background isolate entry point
  static void _backgroundIsolateEntryPoint(SendPort sendPort) async {
    // Create a receive port for this isolate
    final receivePort = ReceivePort();
    
    // Send the receive port back to the main isolate
    sendPort.send(receivePort.sendPort);
    
    // Listen for messages from the main isolate
    receivePort.listen((dynamic message) async {
      if (message is Map<String, dynamic>) {
        await _handleBackgroundMessage(message);
      }
    });
  }
  
  /// Handle background message
  static Future<void> _handleBackgroundMessage(Map<String, dynamic> message) async {
    try {
      final String type = message['type'] as String;
      
      switch (type) {
        case 'balance_change':
          await _handleBalanceChangeInBackground(message);
          break;
        case 'message_received':
          await _handleMessageInBackground(message);
          break;
        case 'sync_update':
          await _handleSyncUpdateInBackground(message);
          break;
        default:
          if (kDebugMode) print('⚠️ Unknown background message type: $type');
      }
    } catch (e) {
      if (kDebugMode) print('❌ Failed to handle background message: $e');
    }
  }
  
  /// Handle balance change in background
  static Future<void> _handleBalanceChangeInBackground(Map<String, dynamic> data) async {
    try {
      // Initialize notification service in background
      await NotificationService.instance.initialize();
      
      // Show balance change notification
      await NotificationService.instance.showBalanceChangeNotification(
        previousBalance: data['previous_balance'] as double,
        newBalance: data['new_balance'] as double,
        changeAmount: data['change_amount'] as double,
        isIncoming: data['is_incoming'] as bool,
        transactionId: data['transaction_id'] as String?,
      );
      
      if (kDebugMode) print('🔔 Background balance change notification sent');
    } catch (e) {
      if (kDebugMode) print('❌ Failed to handle background balance change: $e');
    }
  }
  
  /// Handle message in background
  static Future<void> _handleMessageInBackground(Map<String, dynamic> data) async {
    try {
      // Initialize notification service in background
      await NotificationService.instance.initialize();
      
      // Show message notification
      await NotificationService.instance.showMessageNotification(
        transactionId: data['transaction_id'] as String,
        message: data['message'] as String,
        amount: data['amount'] as double,
        fromAddress: data['from_address'] as String?,
      );
      
      if (kDebugMode) print('🔔 Background message notification sent');
    } catch (e) {
      if (kDebugMode) print('❌ Failed to handle background message: $e');
    }
  }
  
  /// Handle sync update in background
  static Future<void> _handleSyncUpdateInBackground(Map<String, dynamic> data) async {
    // Sync notifications are disabled - skip all sync notification functionality
    if (kDebugMode) print('🔔 Sync notifications disabled - skipping');
    return;
  }
  
  /// Send message to background isolate
  static Future<void> sendToBackground(Map<String, dynamic> message) async {
    try {
      if (_isolateSendPort != null) {
        _isolateSendPort!.send(message);
      } else {
        if (kDebugMode) print('⚠️ Background isolate not available, sending via platform channel');
        await _backgroundChannel.invokeMethod('sendNotification', message);
      }
    } catch (e) {
      if (kDebugMode) print('❌ Failed to send message to background: $e');
    }
  }
  
  /// Dispose background service
  static void dispose() {
    try {
      _backgroundIsolate?.kill();
      _backgroundIsolate = null;
      _isolateSendPort = null;
      
      IsolateNameServer.removePortNameMapping(_isolateName);
      
      if (kDebugMode) print('🔔 Background notification service disposed');
    } catch (e) {
      if (kDebugMode) print('⚠️ Failed to dispose background notification service: $e');
    }
  }
  
  /// Check if background service is available
  static bool get isAvailable => _isolateSendPort != null;
}
