import 'dart:async';
import 'foreground_sync_manager.dart';

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:app_badge_plus/app_badge_plus.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

import '../models/notification_models.dart';
import '../utils/constants.dart';
import 'database_service.dart';
import 'storage_service.dart';
import 'notification_navigation_service.dart';

/// Comprehensive notification service for cross-platform notifications
class NotificationService with WidgetsBindingObserver {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static NotificationService get instance => _instance;

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // macOS dock badge method channel
  static const MethodChannel _macBadgeChannel = MethodChannel('com.bitcoinz/app_badge');

  bool _isInitialized = false;
  NotificationSettings _settings = const NotificationSettings();
  final List<NotificationData> _notificationHistory = [];
  int _notificationIdCounter = 1000;
  // Optional provider for authoritative badge count (e.g., NotificationProvider.totalUnreadCount)
  int Function()? _badgeCountProvider;

  void setBadgeCountProvider(int Function() provider) {
    _badgeCountProvider = provider;
  }

  AppLifecycleState _appLifecycleState = AppLifecycleState.resumed;
  final List<NotificationData> _pendingNotifications = [];

  // Callbacks
  Function(String?)? onNotificationTapped;
  Function(NotificationData)? onNotificationReceived;

  /// Initialize the notification service
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // Initialize timezone data
      tz.initializeTimeZones();

      // Load settings
      await _loadSettings();

      // Initialize platform-specific settings
      await _initializePlatformSettings();

      // Request permissions
      await _requestPermissions();

      // Set up app lifecycle observer
      WidgetsBinding.instance.addObserver(this);

      _isInitialized = true;
      if (kDebugMode) print('🔔 NotificationService initialized successfully');
      return true;
    } catch (e) {
      if (kDebugMode) print('❌ Failed to initialize NotificationService: $e');
      return false;
    }
  }

  /// Initialize platform-specific notification settings
  Future<void> _initializePlatformSettings() async {
    // Android settings
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS settings
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,

    );

    // macOS settings
    const DarwinInitializationSettings initializationSettingsMacOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // Linux settings
    final LinuxInitializationSettings initializationSettingsLinux =
        LinuxInitializationSettings(
      defaultActionName: 'Open notification',
      defaultIcon: AssetsLinuxIcon('assets/images/bitcoinz_logo.png'),
    );

    // Windows settings (if available)
    const WindowsInitializationSettings? initializationSettingsWindows = null;

    final InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
      macOS: initializationSettingsMacOS,
      linux: initializationSettingsLinux,
      windows: initializationSettingsWindows,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create Android notification channels
    if (Platform.isAndroid) {
      await _createAndroidChannels();
    }
  }

  /// Create Android notification channels
  Future<void> _createAndroidChannels() async {
    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
        _flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin == null) return;

    // Financial notifications channel
    const AndroidNotificationChannel financialChannel =
        AndroidNotificationChannel(
      'financial_notifications_v4',
      'Financial Notifications',
      description: 'Balance changes and transaction notifications',
      importance: Importance.high,
      sound: RawResourceAndroidNotificationSound('coin_sound'),
      enableVibration: true,
      playSound: true,
      showBadge: true,
      enableLights: true,
      ledColor: Color.fromARGB(255, 255, 107, 53), // BitcoinZ orange
    );

    // Message notifications channel
    const AndroidNotificationChannel messageChannel =
        AndroidNotificationChannel(
      'message_notifications_v4',
      'Message Notifications',
      description: 'Transaction messages and memos',
      importance: Importance.high,
      sound: RawResourceAndroidNotificationSound('message_sound'),
      enableVibration: true,
      playSound: true,
      showBadge: true,
      enableLights: true,
      ledColor: Color.fromARGB(255, 33, 150, 243), // BitcoinZ blue
    );

    // System notifications channel
    const AndroidNotificationChannel systemChannel =
        AndroidNotificationChannel(
      'system_notifications',
      'System Notifications',
      description: 'Sync status and system alerts',
      importance: Importance.defaultImportance,
      enableVibration: false,
      playSound: false,
      showBadge: false,
    );

    // Security notifications channel
    const AndroidNotificationChannel securityChannel =
        AndroidNotificationChannel(
      'security_notifications_v3',
      'Security Notifications',
      description: 'Security alerts and warnings',
      importance: Importance.max,
      sound: RawResourceAndroidNotificationSound('alert_sound'),
      enableVibration: true,
      playSound: true,
      showBadge: true,
      enableLights: true,
      ledColor: Color.fromARGB(255, 244, 67, 54), // Red for security alerts
    );

    await androidPlugin.createNotificationChannel(financialChannel);
    await androidPlugin.createNotificationChannel(messageChannel);
    await androidPlugin.createNotificationChannel(systemChannel);
    await androidPlugin.createNotificationChannel(securityChannel);
  }

  /// Request notification permissions
  Future<bool> _requestPermissions() async {
    if (Platform.isIOS || Platform.isMacOS) {
      final bool? result = await _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
      return result ?? false;
    } else if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      final bool? result = await androidImplementation?.requestNotificationsPermission();
      return result ?? false;
    }
    return true; // Assume granted for other platforms
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    if (kDebugMode) {
      print('🔔 Notification tapped: ${response.payload}');
    }

    // Mark notification as read
    _markNotificationAsRead(response.id.toString());

    // Handle navigation
    NotificationNavigationService.instance.handleNotificationTap(response.payload);

    // Call the callback
    onNotificationTapped?.call(response.payload);
  }

  /// Show a notification
  Future<void> showNotification(NotificationData notificationData) async {
    if (!_isInitialized) {
      if (kDebugMode) print('⚠️ NotificationService not initialized');
      return;
    }

    // Check if notifications are enabled
    if (!_settings.enabled) return;

    // Check specific type settings
    if (!_isNotificationTypeEnabled(notificationData.type)) return;

    // Check quiet hours
    if (_settings.isInQuietHours) return;

    try {
      final int notificationId = _notificationIdCounter++;

      // Get platform-specific details
      final NotificationDetails platformDetails = _getPlatformNotificationDetails(
        notificationData.category,
        notificationData.priority,
      );

      await _flutterLocalNotificationsPlugin.show(
        notificationId,
        notificationData.title,
        notificationData.body,
        platformDetails,
        payload: notificationData.actionUrl,
      );

      // Add to history
      final historyItem = notificationData.copyWith(id: notificationId.toString());
      _notificationHistory.insert(0, historyItem);

      // Limit history size
      if (_notificationHistory.length > 100) {
        _notificationHistory.removeRange(100, _notificationHistory.length);
      }

      // Save to database
      await _saveNotificationToDatabase(historyItem);

      // Update app badge
      await _updateAppBadge();

      // Call callback
      onNotificationReceived?.call(historyItem);

      if (kDebugMode) {
        print('🔔 Notification shown: ${notificationData.title}');
      }
    } catch (e) {
      if (kDebugMode) print('❌ Failed to show notification: $e');
    }
  }

  /// Get platform-specific notification details
  NotificationDetails _getPlatformNotificationDetails(
    NotificationCategory category,
    NotificationPriority priority,
  ) {
    // Android details
    final channelId = _getAndroidChannelId(category);
    if (kDebugMode) {
      print('🔊 Creating notification for channel: $channelId (category: $category)');
      print('   Sound enabled: ${_settings.soundEnabled}');
    }

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      channelId,
      _getAndroidChannelName(category),
      channelDescription: _getAndroidChannelDescription(category),
      importance: _getAndroidImportance(priority),
      priority: _getAndroidPriority(priority),
      playSound: _settings.soundEnabled,
      enableVibration: _settings.vibrationEnabled,
      icon: '@drawable/ic_notification',
      largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      styleInformation: const BigTextStyleInformation(''),
    );

    // iOS/macOS details
    final int? providerCount = _badgeCountProvider?.call();
    if (kDebugMode) {
      print('🧭 Darwin badgeNumber source = '
          '${providerCount != null ? 'provider:' + providerCount.toString() : 'history:' + _getUnreadNotificationCount().toString()}');
    }
    final DarwinNotificationDetails darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: _settings.soundEnabled,
      sound: _settings.soundEnabled ? 'default' : null,
      // Use ONLY the unified provider (same as app's unread messages). Default to 0 if not yet set.
      badgeNumber: providerCount ?? 0,
    );

    // Linux details
    final LinuxNotificationDetails linuxDetails = LinuxNotificationDetails(
      icon: AssetsLinuxIcon('assets/images/bitcoinz_logo.png'),
    );

    return NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
      linux: linuxDetails,
    );
  }

  /// Get Android channel ID for category
  String _getAndroidChannelId(NotificationCategory category) {
    switch (category) {
      case NotificationCategory.financial:
        return 'financial_notifications_v4';
      case NotificationCategory.messages:
        return 'message_notifications_v4';
    }
  }

  /// Get Android channel name for category
  String _getAndroidChannelName(NotificationCategory category) {
    switch (category) {
      case NotificationCategory.financial:
        return 'Financial Notifications';
      case NotificationCategory.messages:
        return 'Message Notifications';
    }
  }

  /// Get Android channel description for category
  String _getAndroidChannelDescription(NotificationCategory category) {
    switch (category) {
      case NotificationCategory.financial:
        return 'Balance changes and transaction notifications';
      case NotificationCategory.messages:
        return 'Transaction messages and memos';
    }
  }

  /// Get Android importance for priority
  Importance _getAndroidImportance(NotificationPriority priority) {
    switch (priority) {
      case NotificationPriority.low:
        return Importance.low;
      case NotificationPriority.normal:
        return Importance.defaultImportance;
      case NotificationPriority.high:
        return Importance.high;
      case NotificationPriority.urgent:
        return Importance.max;
    }
  }

  /// Get Android priority for priority
  Priority _getAndroidPriority(NotificationPriority priority) {
    switch (priority) {
      case NotificationPriority.low:
        return Priority.low;
      case NotificationPriority.normal:
        return Priority.defaultPriority;
      case NotificationPriority.high:
        return Priority.high;
      case NotificationPriority.urgent:
        return Priority.max;
    }
  }

  /// Check if notification type is enabled
  bool _isNotificationTypeEnabled(NotificationType type) {
    switch (type) {
      case NotificationType.balanceChange:
        return _settings.balanceChangeEnabled;
      case NotificationType.messageReceived:
        return _settings.messageNotificationsEnabled;
    }
  }

  /// Load notification settings
  Future<void> _loadSettings() async {
    try {
      final settingsJson = await StorageService.read(key: 'notification_settings');
      if (settingsJson != null) {
        // _settings = NotificationSettings.fromJson(json.decode(settingsJson));
        // For now, use default settings until JSON serialization is fixed
        _settings = const NotificationSettings();
      }
    } catch (e) {
      if (kDebugMode) print('⚠️ Failed to load notification settings: $e');
      _settings = const NotificationSettings();
    }
  }

  /// Save notification settings
  Future<void> _saveSettings() async {
    try {
      // await StorageService.setString('notification_settings', json.encode(_settings.toJson()));
      // For now, skip saving until JSON serialization is fixed
    } catch (e) {
      if (kDebugMode) print('⚠️ Failed to save notification settings: $e');
    }
  }

  /// Save notification to database
  Future<void> _saveNotificationToDatabase(NotificationData notification) async {
    try {
      final db = await DatabaseService.instance.database;
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.insert('notifications', {
        'id': notification.id,
        'type': notification.type.name,
        'category': notification.category.name,
        'priority': notification.priority.name,
        'title': notification.title,
        'body': notification.body,
        'subtitle': notification.subtitle,
        'payload': notification.payload?.toString(),
        'timestamp': notification.timestamp.millisecondsSinceEpoch,
        'is_read': notification.isRead ? 1 : 0,
        'action_url': notification.actionUrl,
        'icon_path': notification.iconPath,
        'image_path': notification.imagePath,
        'sound_path': notification.soundPath,
        'created_at': now,
        'updated_at': now,
      });
    } catch (e) {
      if (kDebugMode) print('⚠️ Failed to save notification to database: $e');
    }
  }

  /// Mark notification as read
  Future<void> _markNotificationAsRead(String notificationId) async {
    try {
      // Update in memory
      final index = _notificationHistory.indexWhere((n) => n.id == notificationId);
      if (index != -1) {
        _notificationHistory[index] = _notificationHistory[index].copyWith(isRead: true);
      }

      // Update in database
      final db = await DatabaseService.instance.database;
      await db.update(
        'notifications',
        {
          'is_read': 1,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [notificationId],
      );

      // Update app badge
      await _updateAppBadge();
    } catch (e) {
      if (kDebugMode) print('⚠️ Failed to mark notification as read: $e');
    }
  }

  /// Update app badge count
  Future<void> _updateAppBadge() async {
    try {
      // Use ONLY the authoritative provider (WalletProvider via NotificationProvider).
      // If not yet set, default to 0 to avoid stale history-based numbers.
      final unreadCount = _badgeCountProvider?.call() ?? 0;

      if (kDebugMode) {
        print('🔢 Badge update -> count=$unreadCount (provider-only)');
      }

      if (Platform.isIOS || Platform.isAndroid) {
        await AppBadgePlus.updateBadge(unreadCount);
      } else if (Platform.isMacOS) {
        await _setMacBadge(unreadCount);
      }
    } catch (e) {
      if (kDebugMode) print('⚠️ Failed to update app badge: $e');
    }
  }

  /// Get unread notification count
  int _getUnreadNotificationCount() {
    return _notificationHistory.where((n) => !n.isRead).length;
  }

  /// Update app badge with specific count
  Future<void> updateAppBadge(int count) async {
    try {
      if (Platform.isIOS || Platform.isAndroid) {
        await AppBadgePlus.updateBadge(count.clamp(0, 9999));
      } else if (Platform.isMacOS) {
        await _setMacBadge(count);
      }
    } catch (e) {
      if (kDebugMode) print('⚠️ Failed to update app badge: $e');
    }
  }

  /// Clear app badge
  Future<void> clearAppBadge() async {
    try {
      if (Platform.isIOS || Platform.isAndroid) {
        await AppBadgePlus.updateBadge(0);
      } else if (Platform.isMacOS) {
        await _setMacBadge(0);
      }
    } catch (e) {
      if (kDebugMode) print('⚠️ Failed to clear app badge: $e');
    }
  }
  /// Set macOS dock badge (via MethodChannel)
  Future<void> _setMacBadge(int count) async {
    try {
      final clamped = count < 0 ? 0 : count;
      await _macBadgeChannel.invokeMethod('setBadge', {
        'count': clamped,
      });
    } catch (e) {
      if (kDebugMode) print('⚠️ Failed to set macOS badge: $e');
    }
  }


  /// Get notification settings
  NotificationSettings get settings => _settings;

  /// Update notification settings
  Future<void> updateSettings(NotificationSettings newSettings) async {
    _settings = newSettings;
    await _saveSettings();
  }



  /// Clear notification history
  Future<void> clearNotificationHistory() async {
    try {
      _notificationHistory.clear();
      final db = await DatabaseService.instance.database;
      await db.delete('notifications');
      await _updateAppBadge();
    } catch (e) {
      if (kDebugMode) print('⚠️ Failed to clear notification history: $e');
    }
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    try {
      await _flutterLocalNotificationsPlugin.cancelAll();
    } catch (e) {
      if (kDebugMode) print('⚠️ Failed to cancel all notifications: $e');
    }
  }

  /// Cancel specific notification
  Future<void> cancelNotification(int notificationId) async {
    try {
      await _flutterLocalNotificationsPlugin.cancel(notificationId);
    } catch (e) {
      if (kDebugMode) print('⚠️ Failed to cancel notification: $e');
    }
  }

  /// Show balance change notification
  Future<void> showBalanceChangeNotification({
    required double previousBalance,
    required double newBalance,
    required double changeAmount,
    String? transactionId,
    required bool isIncoming,
  }) async {
    // No minimum threshold - notify for all changes

    final String title = isIncoming ? 'Funds Received' : 'Funds Sent';

    // Create balance change notification data to get proper formatting
    final balanceData = BalanceChangeNotificationData(
      previousBalance: previousBalance,
      newBalance: newBalance,
      changeAmount: changeAmount,
      transactionId: transactionId,
      isIncoming: isIncoming,
    );
    final String body = balanceData.formattedChangeAmount;

    final notificationData = NotificationData(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: NotificationType.balanceChange,
      category: NotificationCategory.financial,
      priority: NotificationPriority.high,
      title: title,
      body: body,
      timestamp: DateTime.now(),
      actionUrl: '/wallet/dashboard',
      payload: {
        'type': 'balance_change',
        'previous_balance': previousBalance,
        'new_balance': newBalance,
        'change_amount': changeAmount,
        'transaction_id': transactionId,
        'is_incoming': isIncoming,
      },
    );

    await showNotification(notificationData);
  }

  /// Show message notification for transactions with memos
  Future<void> showMessageNotification({
    required String transactionId,
    required String message,
    required double amount,
    String? fromAddress,
    bool isIncoming = true,
  }) async {
    if (!_isInitialized) {
      if (kDebugMode) print('⚠️ NotificationService not initialized');
      return;
    }

    // Check if message notifications are enabled
    if (!_settings.messageNotificationsEnabled) return;

    try {
      // Create message notification data to get proper formatting
      final messageData = MessageNotificationData(
        transactionId: transactionId,
        message: message,
        fromAddress: fromAddress,
        amount: amount,
        transactionTime: DateTime.now(),
      );
      final String amountStr = messageData.formattedAmount;

      // Truncate message for preview (messenger style - shorter for better readability)
      final String messagePreview = message.length > 35
          ? '${message.substring(0, 35)}...'
          : message;

      // Create messenger-style notification
      final String title = isIncoming ? 'Message with Payment' : 'Message Sent';
      final String body = '$amountStr\n"$messagePreview"';

      final notificationData = NotificationData(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: NotificationType.messageReceived,
        category: NotificationCategory.messages,
        priority: NotificationPriority.high,
        title: title,
        body: body,
        timestamp: DateTime.now(),
        actionUrl: '/transactions',
        payload: {
          'type': 'message_received',
          'transaction_id': transactionId,
          'message': message,
          'amount': amount,
          'from_address': fromAddress,
          'is_incoming': isIncoming,
        },
      );

      await showNotification(notificationData);

      if (kDebugMode) {
        print('🔔 Message notification sent: ${isIncoming ? 'received' : 'sent'} ${amount.toStringAsFixed(8)} BTCZ with message');
      }
    } catch (e) {
      if (kDebugMode) print('❌ Failed to show message notification: $e');
    }
  }

  /// Handle app lifecycle state changes
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    _appLifecycleState = state;

    if (kDebugMode) print('🔔 App lifecycle state changed to: $state');

    switch (state) {
      case AppLifecycleState.resumed:
        // App came to foreground
        _handleAppResumed();
        break;
      case AppLifecycleState.paused:
        // App went to background
        _handleAppPaused();
        break;
      case AppLifecycleState.detached:
        // App is being terminated
        _handleAppDetached();
        break;
      case AppLifecycleState.inactive:
        // App is inactive (e.g., during phone call)
        break;
      case AppLifecycleState.hidden:
        // App is hidden
        break;
    }
  }

  /// Handle app resumed (came to foreground)
  void _handleAppResumed() {
    if (kDebugMode) print('🔔 App resumed - processing pending notifications');

    // Stop foreground service when user returns
    try {
      ForegroundSyncManager.onAppResumed();
    } catch (_) {}

    // Process any pending notifications that were queued while app was in background
    if (_pendingNotifications.isNotEmpty) {
      for (final notification in _pendingNotifications) {
        _showInAppNotification(notification);
      }
      _pendingNotifications.clear();
    }
  }

  /// Handle app paused (went to background)
  void _handleAppPaused() {
    if (kDebugMode) print('🔔 App paused - notifications will be shown as system notifications');
    // Start foreground service to keep sync stable
    try {
      ForegroundSyncManager.onAppPaused();
    } catch (_) {}
  }

  /// Handle app detached (being terminated)
  void _handleAppDetached() {
    if (kDebugMode) print('🔔 App detached - cleaning up notification service');
  }

  /// Show in-app notification (when app is in foreground)
  void _showInAppNotification(NotificationData notification) {
    // This could show a custom in-app notification widget
    // For now, we'll just call the callback
    onNotificationReceived?.call(notification);
  }

  /// Check if app is in foreground
  bool get isAppInForeground => _appLifecycleState == AppLifecycleState.resumed;

  /// Check if app is in background
  bool get isAppInBackground =>
      _appLifecycleState == AppLifecycleState.paused ||
      _appLifecycleState == AppLifecycleState.detached;

  /// Show notification with proper handling based on app state
  Future<void> showNotificationWithLifecycleHandling(NotificationData notificationData) async {
    if (!_isInitialized) {
      if (kDebugMode) print('⚠️ NotificationService not initialized');
      return;
    }

    // Check if notifications are enabled
    if (!_settings.enabled) return;

    // Check specific type settings
    if (!_isNotificationTypeEnabled(notificationData.type)) return;

    // Check quiet hours
    if (_settings.isInQuietHours) return;

    try {
      // Always show system notification
      await showNotification(notificationData);

      // If app is in foreground and settings allow, also show in-app notification
      if (isAppInForeground && _settings.showInForeground) {
        _showInAppNotification(notificationData);
      }
      // If app is in background, queue for when app resumes (if needed)
      else if (isAppInBackground) {
        // System notification is already shown, no need to queue
        if (kDebugMode) print('🔔 System notification shown while app in background');
      }

    } catch (e) {
      if (kDebugMode) print('❌ Failed to show notification with lifecycle handling: $e');
    }
  }

  /// Schedule a notification for later delivery
  Future<void> scheduleNotification(
    NotificationData notificationData,
    DateTime scheduledTime,
  ) async {
    if (!_isInitialized) {
      if (kDebugMode) print('⚠️ NotificationService not initialized');
      return;
    }

    try {
      final int notificationId = _notificationIdCounter++;

      // Get platform-specific details
      final NotificationDetails platformDetails = _getPlatformNotificationDetails(
        notificationData.category,
        notificationData.priority,
      );

      await _flutterLocalNotificationsPlugin.zonedSchedule(
        notificationId,
        notificationData.title,
        notificationData.body,
        tz.TZDateTime.from(scheduledTime, tz.local),
        platformDetails,
        payload: notificationData.actionUrl,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,

      );

      if (kDebugMode) {
        print('🔔 Notification scheduled for: $scheduledTime');
      }
    } catch (e) {
      if (kDebugMode) print('❌ Failed to schedule notification: $e');
    }
  }

  /// Cancel scheduled notification
  Future<void> cancelScheduledNotification(int notificationId) async {
    try {
      await _flutterLocalNotificationsPlugin.cancel(notificationId);
    } catch (e) {
      if (kDebugMode) print('⚠️ Failed to cancel scheduled notification: $e');
    }
  }

  /// Get pending notifications
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    try {
      return await _flutterLocalNotificationsPlugin.pendingNotificationRequests();
    } catch (e) {
      if (kDebugMode) print('⚠️ Failed to get pending notifications: $e');
      return [];
    }
  }

  /// Public getters for testing
  bool get isInitialized => _isInitialized;
  AppLifecycleState get appLifecycleState => _appLifecycleState;
  List<NotificationData> get pendingNotifications => List.unmodifiable(_pendingNotifications);
  List<NotificationData> get notificationHistory => List.unmodifiable(_notificationHistory);

  /// Dispose resources
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notificationHistory.clear();
    _pendingNotifications.clear();
    _isInitialized = false;
  }
}
