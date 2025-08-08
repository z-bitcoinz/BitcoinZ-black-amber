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
      'lastUpdated': instance.lastUpdated?.toIso8601String(),
    };
