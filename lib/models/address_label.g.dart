// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'address_label.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AddressLabel _$AddressLabelFromJson(Map<String, dynamic> json) => AddressLabel(
      id: (json['id'] as num?)?.toInt(),
      address: json['address'] as String,
      labelName: json['labelName'] as String,
      category: $enumDecode(_$AddressLabelCategoryEnumMap, json['category']),
      type: $enumDecode(_$AddressLabelTypeEnumMap, json['type']),
      description: json['description'] as String?,
      color: json['color'] as String,
      isOwned: json['isOwned'] as bool,
      isActive: json['isActive'] as bool? ?? true,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$AddressLabelToJson(AddressLabel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'address': instance.address,
      'labelName': instance.labelName,
      'category': _$AddressLabelCategoryEnumMap[instance.category]!,
      'type': _$AddressLabelTypeEnumMap[instance.type]!,
      'description': instance.description,
      'color': instance.color,
      'isOwned': instance.isOwned,
      'isActive': instance.isActive,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };

const _$AddressLabelCategoryEnumMap = {
  AddressLabelCategory.income: 'income',
  AddressLabelCategory.expenses: 'expenses',
  AddressLabelCategory.savings: 'savings',
  AddressLabelCategory.trading: 'trading',
  AddressLabelCategory.external: 'external',
  AddressLabelCategory.other: 'other',
};

const _$AddressLabelTypeEnumMap = {
  AddressLabelType.solarIncome: 'solarIncome',
  AddressLabelType.familyTransfers: 'familyTransfers',
  AddressLabelType.salary: 'salary',
  AddressLabelType.business: 'business',
  AddressLabelType.freelance: 'freelance',
  AddressLabelType.investment: 'investment',
  AddressLabelType.bills: 'bills',
  AddressLabelType.shopping: 'shopping',
  AddressLabelType.investmentPurchases: 'investmentPurchases',
  AddressLabelType.food: 'food',
  AddressLabelType.transportation: 'transportation',
  AddressLabelType.utilities: 'utilities',
  AddressLabelType.savings: 'savings',
  AddressLabelType.emergencyFund: 'emergencyFund',
  AddressLabelType.trading: 'trading',
  AddressLabelType.staking: 'staking',
  AddressLabelType.defi: 'defi',
  AddressLabelType.exchange: 'exchange',
  AddressLabelType.friend: 'friend',
  AddressLabelType.merchant: 'merchant',
  AddressLabelType.service: 'service',
  AddressLabelType.donation: 'donation',
  AddressLabelType.personal: 'personal',
  AddressLabelType.temporary: 'temporary',
  AddressLabelType.unknown: 'unknown',
  AddressLabelType.custom: 'custom',
};
