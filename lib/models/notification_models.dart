import 'package:json_annotation/json_annotation.dart';
import '../utils/formatters.dart';


part 'notification_models.g.dart';

/// Types of notifications that can be sent
enum NotificationType {
  balanceChange,
  messageReceived,
}

/// Categories for organizing notifications
enum NotificationCategory {
  financial,
  messages,
}

/// Priority levels for notifications
enum NotificationPriority {
  low,
  normal,
  high,
  urgent,
}

/// Sound options for notifications
enum NotificationSound {
  none,
  defaultSound,
  coin,
  message,
  alert,
  success,
  custom,
}

/// Notification settings for different types
@JsonSerializable()
class NotificationSettings {
  final bool enabled;
  final bool balanceChangeEnabled;
  final bool messageNotificationsEnabled;
  final bool soundEnabled;
  final NotificationSound soundType;
  final bool vibrationEnabled;
  final bool showInForeground;
  final bool showWhenLocked;
  final int quietHoursStart; // Hour in 24h format (e.g., 22 for 10 PM)
  final int quietHoursEnd;   // Hour in 24h format (e.g., 7 for 7 AM)
  final bool quietHoursEnabled;

  const NotificationSettings({
    this.enabled = true,
    this.balanceChangeEnabled = true,
    this.messageNotificationsEnabled = true,
    this.soundEnabled = true,
    this.soundType = NotificationSound.defaultSound,
    this.vibrationEnabled = true,
    this.showInForeground = true,
    this.showWhenLocked = false,
    this.quietHoursStart = 22,
    this.quietHoursEnd = 7,
    this.quietHoursEnabled = false,
  });

  factory NotificationSettings.fromJson(Map<String, dynamic> json) =>
      _$NotificationSettingsFromJson(json);

  Map<String, dynamic> toJson() => _$NotificationSettingsToJson(this);

  NotificationSettings copyWith({
    bool? enabled,
    bool? balanceChangeEnabled,
    bool? messageNotificationsEnabled,
    bool? soundEnabled,
    NotificationSound? soundType,
    bool? vibrationEnabled,
    bool? showInForeground,
    bool? showWhenLocked,
    int? quietHoursStart,
    int? quietHoursEnd,
    bool? quietHoursEnabled,
  }) {
    return NotificationSettings(
      enabled: enabled ?? this.enabled,
      balanceChangeEnabled: balanceChangeEnabled ?? this.balanceChangeEnabled,
      messageNotificationsEnabled: messageNotificationsEnabled ?? this.messageNotificationsEnabled,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      soundType: soundType ?? this.soundType,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      showInForeground: showInForeground ?? this.showInForeground,
      showWhenLocked: showWhenLocked ?? this.showWhenLocked,
      quietHoursStart: quietHoursStart ?? this.quietHoursStart,
      quietHoursEnd: quietHoursEnd ?? this.quietHoursEnd,
      quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
    );
  }

  /// Check if notifications should be shown during quiet hours
  bool get isInQuietHours {
    if (!quietHoursEnabled) return false;

    final now = DateTime.now();
    final currentHour = now.hour;

    if (quietHoursStart <= quietHoursEnd) {
      // Same day quiet hours (e.g., 22:00 to 07:00 next day)
      return currentHour >= quietHoursStart || currentHour < quietHoursEnd;
    } else {
      // Cross-midnight quiet hours (e.g., 10 PM to 7 AM)
      return currentHour >= quietHoursStart && currentHour < quietHoursEnd;
    }
  }
}

/// Individual notification data model
@JsonSerializable()
class NotificationData {
  final String id;
  final NotificationType type;
  final NotificationCategory category;
  final NotificationPriority priority;
  final String title;
  final String body;
  final String? subtitle;
  final Map<String, dynamic>? payload;
  final DateTime timestamp;
  final bool isRead;
  final String? actionUrl; // Deep link or navigation path
  final String? iconPath;
  final String? imagePath;
  final String? soundPath;

  const NotificationData({
    required this.id,
    required this.type,
    required this.category,
    required this.priority,
    required this.title,
    required this.body,
    this.subtitle,
    this.payload,
    required this.timestamp,
    this.isRead = false,
    this.actionUrl,
    this.iconPath,
    this.imagePath,
    this.soundPath,
  });

  factory NotificationData.fromJson(Map<String, dynamic> json) =>
      _$NotificationDataFromJson(json);

  Map<String, dynamic> toJson() => _$NotificationDataToJson(this);

  NotificationData copyWith({
    String? id,
    NotificationType? type,
    NotificationCategory? category,
    NotificationPriority? priority,
    String? title,
    String? body,
    String? subtitle,
    Map<String, dynamic>? payload,
    DateTime? timestamp,
    bool? isRead,
    String? actionUrl,
    String? iconPath,
    String? imagePath,
    String? soundPath,
  }) {
    return NotificationData(
      id: id ?? this.id,
      type: type ?? this.type,
      category: category ?? this.category,
      priority: priority ?? this.priority,
      title: title ?? this.title,
      body: body ?? this.body,
      subtitle: subtitle ?? this.subtitle,
      payload: payload ?? this.payload,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      actionUrl: actionUrl ?? this.actionUrl,
      iconPath: iconPath ?? this.iconPath,
      imagePath: imagePath ?? this.imagePath,
      soundPath: soundPath ?? this.soundPath,
    );
  }

  /// Get formatted timestamp for display
  String get formattedTimestamp {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }
}

/// Balance change notification specific data
@JsonSerializable()
class BalanceChangeNotificationData {
  final double previousBalance;
  final double newBalance;
  final double changeAmount;
  final String? transactionId;
  final bool isIncoming;

  const BalanceChangeNotificationData({
    required this.previousBalance,
    required this.newBalance,
    required this.changeAmount,
    this.transactionId,
    required this.isIncoming,
  });

  factory BalanceChangeNotificationData.fromJson(Map<String, dynamic> json) =>
      _$BalanceChangeNotificationDataFromJson(json);

  Map<String, dynamic> toJson() => _$BalanceChangeNotificationDataToJson(this);

  String get formattedChangeAmount {
    final sign = isIncoming ? '+' : '-';
    return '$sign${_formatAmount(changeAmount)} BTCZ';
  }

  String _formatAmount(double amount) {
    if (amount == 0) return '0.00000000';

    // Show up to 8 decimal places, removing trailing zeros
    String formatted = amount.abs().toStringAsFixed(8);
    formatted = formatted.replaceAll(RegExp(r'0*$'), '');
    formatted = formatted.replaceAll(RegExp(r'\.$'), '');

    return formatted;
  }
}

/// Message notification specific data
@JsonSerializable()
class MessageNotificationData {
  final String transactionId;
  final String message;
  final String? fromAddress;
  final double amount;
  final DateTime transactionTime;

  const MessageNotificationData({
    required this.transactionId,
    required this.message,
    this.fromAddress,
    required this.amount,
    required this.transactionTime,
  });

  factory MessageNotificationData.fromJson(Map<String, dynamic> json) =>
      _$MessageNotificationDataFromJson(json);

  Map<String, dynamic> toJson() => _$MessageNotificationDataToJson(this);

  String get formattedAmount {
    return '+${Formatters.formatBtczTrim(amount, showSymbol: false)} BTCZ';
  }

  String _formatAmount(double amount) {
    if (amount == 0) return '0.00000000';

    // Show up to 8 decimal places, removing trailing zeros
    String formatted = amount.abs().toStringAsFixed(8);
    formatted = formatted.replaceAll(RegExp(r'0*$'), '');
    formatted = formatted.replaceAll(RegExp(r'\.$'), '');

    return formatted;
  }

  String get shortFromAddress {
    if (fromAddress == null || fromAddress!.length <= 16) return fromAddress ?? 'Unknown';
    return '${fromAddress!.substring(0, 8)}...${fromAddress!.substring(fromAddress!.length - 8)}';
  }
}
