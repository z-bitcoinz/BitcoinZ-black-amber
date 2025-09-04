// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

NotificationSettings _$NotificationSettingsFromJson(
        Map<String, dynamic> json) =>
    NotificationSettings(
      enabled: json['enabled'] as bool? ?? true,
      balanceChangeEnabled: json['balanceChangeEnabled'] as bool? ?? true,
      messageNotificationsEnabled:
          json['messageNotificationsEnabled'] as bool? ?? true,
      soundEnabled: json['soundEnabled'] as bool? ?? true,
      soundType:
          $enumDecodeNullable(_$NotificationSoundEnumMap, json['soundType']) ??
              NotificationSound.defaultSound,
      vibrationEnabled: json['vibrationEnabled'] as bool? ?? true,
      showInForeground: json['showInForeground'] as bool? ?? true,
      showWhenLocked: json['showWhenLocked'] as bool? ?? false,
      quietHoursStart: (json['quietHoursStart'] as num?)?.toInt() ?? 22,
      quietHoursEnd: (json['quietHoursEnd'] as num?)?.toInt() ?? 7,
      quietHoursEnabled: json['quietHoursEnabled'] as bool? ?? false,
    );

Map<String, dynamic> _$NotificationSettingsToJson(
        NotificationSettings instance) =>
    <String, dynamic>{
      'enabled': instance.enabled,
      'balanceChangeEnabled': instance.balanceChangeEnabled,
      'messageNotificationsEnabled': instance.messageNotificationsEnabled,
      'soundEnabled': instance.soundEnabled,
      'soundType': _$NotificationSoundEnumMap[instance.soundType]!,
      'vibrationEnabled': instance.vibrationEnabled,
      'showInForeground': instance.showInForeground,
      'showWhenLocked': instance.showWhenLocked,
      'quietHoursStart': instance.quietHoursStart,
      'quietHoursEnd': instance.quietHoursEnd,
      'quietHoursEnabled': instance.quietHoursEnabled,
    };

const _$NotificationSoundEnumMap = {
  NotificationSound.none: 'none',
  NotificationSound.defaultSound: 'defaultSound',
  NotificationSound.coin: 'coin',
  NotificationSound.message: 'message',
  NotificationSound.alert: 'alert',
  NotificationSound.success: 'success',
  NotificationSound.custom: 'custom',
};

NotificationData _$NotificationDataFromJson(Map<String, dynamic> json) =>
    NotificationData(
      id: json['id'] as String,
      type: $enumDecode(_$NotificationTypeEnumMap, json['type']),
      category: $enumDecode(_$NotificationCategoryEnumMap, json['category']),
      priority: $enumDecode(_$NotificationPriorityEnumMap, json['priority']),
      title: json['title'] as String,
      body: json['body'] as String,
      subtitle: json['subtitle'] as String?,
      payload: json['payload'] as Map<String, dynamic>?,
      timestamp: DateTime.parse(json['timestamp'] as String),
      isRead: json['isRead'] as bool? ?? false,
      actionUrl: json['actionUrl'] as String?,
      iconPath: json['iconPath'] as String?,
      imagePath: json['imagePath'] as String?,
      soundPath: json['soundPath'] as String?,
    );

Map<String, dynamic> _$NotificationDataToJson(NotificationData instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': _$NotificationTypeEnumMap[instance.type]!,
      'category': _$NotificationCategoryEnumMap[instance.category]!,
      'priority': _$NotificationPriorityEnumMap[instance.priority]!,
      'title': instance.title,
      'body': instance.body,
      'subtitle': instance.subtitle,
      'payload': instance.payload,
      'timestamp': instance.timestamp.toIso8601String(),
      'isRead': instance.isRead,
      'actionUrl': instance.actionUrl,
      'iconPath': instance.iconPath,
      'imagePath': instance.imagePath,
      'soundPath': instance.soundPath,
    };

const _$NotificationTypeEnumMap = {
  NotificationType.balanceChange: 'balanceChange',
  NotificationType.messageReceived: 'messageReceived',
};

const _$NotificationCategoryEnumMap = {
  NotificationCategory.financial: 'financial',
  NotificationCategory.messages: 'messages',
};

const _$NotificationPriorityEnumMap = {
  NotificationPriority.low: 'low',
  NotificationPriority.normal: 'normal',
  NotificationPriority.high: 'high',
  NotificationPriority.urgent: 'urgent',
};

BalanceChangeNotificationData _$BalanceChangeNotificationDataFromJson(
        Map<String, dynamic> json) =>
    BalanceChangeNotificationData(
      previousBalance: (json['previousBalance'] as num).toDouble(),
      newBalance: (json['newBalance'] as num).toDouble(),
      changeAmount: (json['changeAmount'] as num).toDouble(),
      transactionId: json['transactionId'] as String?,
      isIncoming: json['isIncoming'] as bool,
    );

Map<String, dynamic> _$BalanceChangeNotificationDataToJson(
        BalanceChangeNotificationData instance) =>
    <String, dynamic>{
      'previousBalance': instance.previousBalance,
      'newBalance': instance.newBalance,
      'changeAmount': instance.changeAmount,
      'transactionId': instance.transactionId,
      'isIncoming': instance.isIncoming,
    };

MessageNotificationData _$MessageNotificationDataFromJson(
        Map<String, dynamic> json) =>
    MessageNotificationData(
      transactionId: json['transactionId'] as String,
      message: json['message'] as String,
      fromAddress: json['fromAddress'] as String?,
      amount: (json['amount'] as num).toDouble(),
      transactionTime: DateTime.parse(json['transactionTime'] as String),
    );

Map<String, dynamic> _$MessageNotificationDataToJson(
        MessageNotificationData instance) =>
    <String, dynamic>{
      'transactionId': instance.transactionId,
      'message': instance.message,
      'fromAddress': instance.fromAddress,
      'amount': instance.amount,
      'transactionTime': instance.transactionTime.toIso8601String(),
    };
