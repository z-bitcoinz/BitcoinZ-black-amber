// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'balance_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BalanceModel _$BalanceModelFromJson(Map<String, dynamic> json) => BalanceModel(
      transparent: (json['transparent'] as num).toDouble(),
      shielded: (json['shielded'] as num).toDouble(),
      total: (json['total'] as num).toDouble(),
      unconfirmed: (json['unconfirmed'] as num?)?.toDouble() ?? 0.0,
      unconfirmedTransparent:
          (json['unconfirmedTransparent'] as num?)?.toDouble() ?? 0.0,
      unconfirmedShielded:
          (json['unconfirmedShielded'] as num?)?.toDouble() ?? 0.0,
      verifiedTransparent:
          (json['verifiedTransparent'] as num?)?.toDouble() ?? 0.0,
      verifiedShielded: (json['verifiedShielded'] as num?)?.toDouble() ?? 0.0,
      unverifiedTransparent:
          (json['unverifiedTransparent'] as num?)?.toDouble() ?? 0.0,
      unverifiedShielded:
          (json['unverifiedShielded'] as num?)?.toDouble() ?? 0.0,
      spendableTransparent:
          (json['spendableTransparent'] as num?)?.toDouble() ?? 0.0,
      spendableShielded: (json['spendableShielded'] as num?)?.toDouble() ?? 0.0,
      pendingChange: (json['pendingChange'] as num?)?.toDouble() ?? 0.0,
      lastUpdated: json['lastUpdated'] == null
          ? null
          : DateTime.parse(json['lastUpdated'] as String),
    );

Map<String, dynamic> _$BalanceModelToJson(BalanceModel instance) =>
    <String, dynamic>{
      'transparent': instance.transparent,
      'shielded': instance.shielded,
      'total': instance.total,
      'unconfirmed': instance.unconfirmed,
      'unconfirmedTransparent': instance.unconfirmedTransparent,
      'unconfirmedShielded': instance.unconfirmedShielded,
      'verifiedTransparent': instance.verifiedTransparent,
      'verifiedShielded': instance.verifiedShielded,
      'unverifiedTransparent': instance.unverifiedTransparent,
      'unverifiedShielded': instance.unverifiedShielded,
      'spendableTransparent': instance.spendableTransparent,
      'spendableShielded': instance.spendableShielded,
      'pendingChange': instance.pendingChange,
      'lastUpdated': instance.lastUpdated?.toIso8601String(),
    };
