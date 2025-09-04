import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/notification_models.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';

/// Provider for managing notification settings and state
class NotificationProvider extends ChangeNotifier {
  static const String _settingsKey = 'notification_settings';
  static const String _historyKey = 'notification_history';

  NotificationSettings _settings = const NotificationSettings();
  List<NotificationData> _notificationHistory = [];
  bool _isInitialized = false;
  int _unreadCount = 0;
  int _unreadMemoCount = 0; // Track unread memos from wallet provider

  // Getters
  NotificationSettings get settings => _settings;
  List<NotificationData> get notificationHistory => List.unmodifiable(_notificationHistory);
  bool get isInitialized => _isInitialized;
  int get unreadCount => _unreadCount;
  int get unreadMemoCount => _unreadMemoCount;
  int get totalUnreadCount => _unreadCount + _unreadMemoCount;
  bool get hasUnreadNotifications => _unreadCount > 0;
  bool get hasUnreadMemos => _unreadMemoCount > 0;
  bool get hasAnyUnread => totalUnreadCount > 0;

  /// Initialize the notification provider
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Load settings and history
      await _loadSettings();
      await _loadNotificationHistory();

      // Initialize notification service
      await NotificationService.instance.initialize();

      // Set up callbacks
      NotificationService.instance.onNotificationReceived = _onNotificationReceived;
      NotificationService.instance.onNotificationTapped = _onNotificationTapped;

      // Provide NotificationService with the authoritative badge count source (unread memos only)
      NotificationService.instance.setBadgeCountProvider(() => _unreadMemoCount);

      _isInitialized = true;
      _updateUnreadCount();

      if (kDebugMode) print('🔔 NotificationProvider initialized');
      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('❌ Failed to initialize NotificationProvider: $e');
    }
  }

  /// Load notification settings from storage
  Future<void> _loadSettings() async {
    try {
      final settingsJson = await StorageService.read(key: _settingsKey);
      if (settingsJson != null) {
        final Map<String, dynamic> settingsMap = json.decode(settingsJson);
        _settings = NotificationSettings(
          enabled: settingsMap['enabled'] ?? true,
          balanceChangeEnabled: settingsMap['balanceChangeEnabled'] ?? true,
          messageNotificationsEnabled: settingsMap['messageNotificationsEnabled'] ?? true,
          soundEnabled: settingsMap['soundEnabled'] ?? true,
          soundType: NotificationSound.values.firstWhere(
            (e) => e.name == settingsMap['soundType'],
            orElse: () => NotificationSound.defaultSound,
          ),
          vibrationEnabled: settingsMap['vibrationEnabled'] ?? true,
          showInForeground: settingsMap['showInForeground'] ?? true,
          showWhenLocked: settingsMap['showWhenLocked'] ?? false,
          quietHoursStart: settingsMap['quietHoursStart'] ?? 22,
          quietHoursEnd: settingsMap['quietHoursEnd'] ?? 7,
          quietHoursEnabled: settingsMap['quietHoursEnabled'] ?? false,
        );
      }
    } catch (e) {
      if (kDebugMode) print('⚠️ Failed to load notification settings: $e');
      _settings = const NotificationSettings();
    }
  }

  /// Save notification settings to storage
  Future<void> _saveSettings() async {
    try {
      final settingsMap = {
        'enabled': _settings.enabled,
        'balanceChangeEnabled': _settings.balanceChangeEnabled,
        'messageNotificationsEnabled': _settings.messageNotificationsEnabled,
        'soundEnabled': _settings.soundEnabled,
        'soundType': _settings.soundType.name,
        'vibrationEnabled': _settings.vibrationEnabled,
        'showInForeground': _settings.showInForeground,
        'showWhenLocked': _settings.showWhenLocked,
        'quietHoursStart': _settings.quietHoursStart,
        'quietHoursEnd': _settings.quietHoursEnd,
        'quietHoursEnabled': _settings.quietHoursEnabled,
      };

      await StorageService.write(key: _settingsKey, value: json.encode(settingsMap));

      // Update notification service settings
      await NotificationService.instance.updateSettings(_settings);
    } catch (e) {
      if (kDebugMode) print('⚠️ Failed to save notification settings: $e');
    }
  }

  /// Load notification history from storage
  Future<void> _loadNotificationHistory() async {
    try {
      final historyJson = await StorageService.read(key: _historyKey);
      if (historyJson != null) {
        final List<dynamic> historyList = json.decode(historyJson);
        _notificationHistory = historyList.map((item) {
          return NotificationData(
            id: item['id'],
            type: NotificationType.values.firstWhere(
              (e) => e.name == item['type'],
              orElse: () => NotificationType.balanceChange,
            ),
            category: NotificationCategory.values.firstWhere(
              (e) => e.name == item['category'],
              orElse: () => NotificationCategory.financial,
            ),
            priority: NotificationPriority.values.firstWhere(
              (e) => e.name == item['priority'],
              orElse: () => NotificationPriority.normal,
            ),
            title: item['title'],
            body: item['body'],
            subtitle: item['subtitle'],
            payload: item['payload'],
            timestamp: DateTime.fromMillisecondsSinceEpoch(item['timestamp']),
            isRead: item['isRead'] ?? false,
            actionUrl: item['actionUrl'],
            iconPath: item['iconPath'],
            imagePath: item['imagePath'],
            soundPath: item['soundPath'],
          );
        }).toList();
      }
    } catch (e) {
      if (kDebugMode) print('⚠️ Failed to load notification history: $e');
      _notificationHistory = [];
    }
  }

  /// Save notification history to storage
  Future<void> _saveNotificationHistory() async {
    try {
      final historyList = _notificationHistory.map((notification) {
        return {
          'id': notification.id,
          'type': notification.type.name,
          'category': notification.category.name,
          'priority': notification.priority.name,
          'title': notification.title,
          'body': notification.body,
          'subtitle': notification.subtitle,
          'payload': notification.payload,
          'timestamp': notification.timestamp.millisecondsSinceEpoch,
          'isRead': notification.isRead,
          'actionUrl': notification.actionUrl,
          'iconPath': notification.iconPath,
          'imagePath': notification.imagePath,
          'soundPath': notification.soundPath,
        };
      }).toList();

      await StorageService.write(key: _historyKey, value: json.encode(historyList));
    } catch (e) {
      if (kDebugMode) print('⚠️ Failed to save notification history: $e');
    }
  }

  /// Update notification settings
  Future<void> updateSettings(NotificationSettings newSettings) async {
    _settings = newSettings;
    await _saveSettings();
    notifyListeners();
  }

  /// Toggle notifications enabled/disabled
  Future<void> toggleNotifications(bool enabled) async {
    await updateSettings(_settings.copyWith(enabled: enabled));
  }

  /// Toggle balance change notifications
  Future<void> toggleBalanceChangeNotifications(bool enabled) async {
    await updateSettings(_settings.copyWith(balanceChangeEnabled: enabled));
  }

  /// Toggle message notifications
  Future<void> toggleMessageNotifications(bool enabled) async {
    await updateSettings(_settings.copyWith(messageNotificationsEnabled: enabled));
  }


  /// Toggle sound
  Future<void> toggleSound(bool enabled) async {
    await updateSettings(_settings.copyWith(soundEnabled: enabled));
  }

  /// Update sound type
  Future<void> updateSoundType(NotificationSound soundType) async {
    await updateSettings(_settings.copyWith(soundType: soundType));
  }

  /// Toggle vibration
  Future<void> toggleVibration(bool enabled) async {
    await updateSettings(_settings.copyWith(vibrationEnabled: enabled));
  }

  /// Toggle quiet hours
  Future<void> toggleQuietHours(bool enabled) async {
    await updateSettings(_settings.copyWith(quietHoursEnabled: enabled));
  }

  /// Update quiet hours
  Future<void> updateQuietHours(int startHour, int endHour) async {
    await updateSettings(_settings.copyWith(
      quietHoursStart: startHour,
      quietHoursEnd: endHour,
    ));
  }


  /// Handle new notification received
  void _onNotificationReceived(NotificationData notification) {
    _notificationHistory.insert(0, notification);

    // Limit history size
    if (_notificationHistory.length > 100) {
      _notificationHistory.removeRange(100, _notificationHistory.length);
    }

    _updateUnreadCount();
    _saveNotificationHistory();
    notifyListeners();

    if (kDebugMode) print('🔔 Notification received and processed: ${notification.title}');
  }

  /// Handle notification tapped
  void _onNotificationTapped(String? payload) {
    if (kDebugMode) print('🔔 Notification tapped with payload: $payload');
    // Navigation will be handled by the main app
  }

  /// Mark notification as read
  Future<void> markNotificationAsRead(String notificationId) async {
    final index = _notificationHistory.indexWhere((n) => n.id == notificationId);
    if (index != -1) {
      _notificationHistory[index] = _notificationHistory[index].copyWith(isRead: true);
      _updateUnreadCount();
      await _saveNotificationHistory();
      notifyListeners();
    }
  }

  /// Mark all notifications as read
  Future<void> markAllNotificationsAsRead() async {
    for (int i = 0; i < _notificationHistory.length; i++) {
      _notificationHistory[i] = _notificationHistory[i].copyWith(isRead: true);
    }
    _updateUnreadCount();
    await _saveNotificationHistory();
    await NotificationService.instance.clearAppBadge();
    notifyListeners();
  }

  /// Clear notification history
  Future<void> clearNotificationHistory() async {
    _notificationHistory.clear();
    _updateUnreadCount();
    await _saveNotificationHistory();
    await NotificationService.instance.clearAppBadge();
    notifyListeners();
  }

  /// Update unread count
  void _updateUnreadCount() {
    final historyUnread = _notificationHistory.where((n) => !n.isRead).length;
    _unreadCount = historyUnread;
    _updateAppBadge();
    if (kDebugMode) {
      print('🔎 Badge sync: historyUnread=$_unreadCount, memoUnread=$_unreadMemoCount, total=$totalUnreadCount');
    }
  }
  /// Reconcile notification history with actual memo read state
  Future<void> reconcileWithMemoReadState({required int actualUnreadMemos}) async {
    try {
      // If app shows 0 unread memos but history has unread message notifications, mark them read
      if (actualUnreadMemos == 0) {
        bool changed = false;
        for (int i = 0; i < _notificationHistory.length; i++) {
          final n = _notificationHistory[i];
          if (!n.isRead && n.type == NotificationType.messageReceived) {
            _notificationHistory[i] = n.copyWith(isRead: true);
            changed = true;
          }
        }
        if (changed) {
          _updateUnreadCount();
          await _saveNotificationHistory();
          notifyListeners();
          if (kDebugMode) print('🧹 Reconciled notification history with memo read state');
        }
      }
    } catch (e) {
      if (kDebugMode) print('⚠️ Failed reconciliation: $e');
    }
  }


  /// Update unread memo count from wallet provider
  void updateUnreadMemoCount(int count) {
    if (_unreadMemoCount != count) {
      _unreadMemoCount = count;
      _updateAppBadge();
      notifyListeners();
    }
  }

  /// Update app badge with memo count only (consistent with setBadgeCountProvider)
  void _updateAppBadge() {
    try {
      // 🔄 BADGE FIX: Use memos only (consistent with line 48 setBadgeCountProvider)
      final memoCount = _unreadMemoCount;
      if (kDebugMode) print('🔄 BADGE FIX: Updating app badge to $memoCount (memos only)');
      
      if (memoCount > 0) {
        NotificationService.instance.updateAppBadge(memoCount);
      } else {
        NotificationService.instance.clearAppBadge();
      }
      
      if (kDebugMode) print('🔄 BADGE FIX: App badge updated successfully');
    } catch (e) {
      if (kDebugMode) print('⚠️ Failed to update app badge: $e');
    }
  }

  /// Get notifications by type
  List<NotificationData> getNotificationsByType(NotificationType type) {
    return _notificationHistory.where((n) => n.type == type).toList();
  }

  /// Get notifications by category
  List<NotificationData> getNotificationsByCategory(NotificationCategory category) {
    return _notificationHistory.where((n) => n.category == category).toList();
  }

  /// Get unread notifications
  List<NotificationData> get unreadNotifications {
    return _notificationHistory.where((n) => !n.isRead).toList();
  }

  @override
  void dispose() {
    NotificationService.instance.dispose();
    super.dispose();
  }
}
