// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'wallet_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WalletModel _$WalletModelFromJson(Map<String, dynamic> json) => WalletModel(
      walletId: json['wallet_id'] as String,
      transparentAddresses: (json['transparent_addresses'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      shieldedAddresses: (json['shielded_addresses'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
      birthdayHeight: (json['birthdayHeight'] as num?)?.toInt(),
    );

Map<String, dynamic> _$WalletModelToJson(WalletModel instance) =>
    <String, dynamic>{
      'wallet_id': instance.walletId,
      'transparent_addresses': instance.transparentAddresses,
      'shielded_addresses': instance.shieldedAddresses,
      'createdAt': instance.createdAt?.toIso8601String(),
      'birthdayHeight': instance.birthdayHeight,
    };
