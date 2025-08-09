// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transaction_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TransactionModel _$TransactionModelFromJson(Map<String, dynamic> json) =>
    TransactionModel(
      txid: json['txid'] as String,
      amount: (json['amount'] as num).toDouble(),
      blockHeight: (json['block_height'] as num?)?.toInt(),
      timestamp: DateTime.parse(json['timestamp'] as String),
      memo: json['memo'] as String?,
      type: json['tx_type'] as String,
      fromAddress: json['from_address'] as String?,
      toAddress: json['to_address'] as String?,
      confirmations: (json['confirmations'] as num?)?.toInt(),
      fee: (json['fee'] as num?)?.toDouble(),
      memoRead: json['memo_read'] as bool? ?? false,
    );

Map<String, dynamic> _$TransactionModelToJson(TransactionModel instance) =>
    <String, dynamic>{
      'txid': instance.txid,
      'amount': instance.amount,
      'block_height': instance.blockHeight,
      'timestamp': instance.timestamp.toIso8601String(),
      'memo': instance.memo,
      'tx_type': instance.type,
      'from_address': instance.fromAddress,
      'to_address': instance.toAddress,
      'confirmations': instance.confirmations,
      'fee': instance.fee,
      'memo_read': instance.memoRead,
    };
