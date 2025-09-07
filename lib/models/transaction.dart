/// Transaction model for BitcoinZ Mobile Wallet
///
/// Represents a transaction with all necessary fields for display
/// and processing in the mobile wallet interface.
import '../utils/formatters.dart';
class Transaction {
  final String txid;
  final double amount;

  final int? blockHeight;
  final DateTime timestamp;
  final String? memo;
  final TransactionType type;
  final TransactionStatus status;
  final String? fromAddress;
  final String? toAddress;
  final double? fee;

  const Transaction({
    required this.txid,
    required this.amount,
    this.blockHeight,
    required this.timestamp,
    this.memo,
    required this.type,
    required this.status,
    this.fromAddress,
    this.toAddress,
    this.fee,
  });

  /// Create Transaction from JSON data
  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      txid: json['txid'] as String,
      amount: (json['amount'] as num).toDouble(),
      blockHeight: json['block_height'] as int?,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (json['timestamp'] as int) * 1000,
      ),
      memo: json['memo'] as String?,
      type: TransactionType.fromString(json['tx_type'] as String? ?? 'received'),
      status: TransactionStatus.fromString(json['status'] as String? ?? 'confirmed'),
      fromAddress: json['from_address'] as String?,
      toAddress: json['to_address'] as String?,
      fee: json['fee'] != null ? (json['fee'] as num).toDouble() : null,
    );
  }

  /// Convert Transaction to JSON
  Map<String, dynamic> toJson() {
    return {
      'txid': txid,
      'amount': amount,
      'block_height': blockHeight,
      'timestamp': timestamp.millisecondsSinceEpoch ~/ 1000,
      'memo': memo,
      'tx_type': type.toString(),
      'status': status.toString(),
      'from_address': fromAddress,
      'to_address': toAddress,
      'fee': fee,
    };
  }

  /// Get formatted amount with proper sign
  String get formattedAmount {
    final sign = type == TransactionType.sent ? '-' : '+';
    return '$sign${Formatters.formatBtczTrim(amount, showSymbol: false)} BTCZ';
  }

  /// Get short transaction ID for display
  String get shortTxid {
    if (txid.length <= 16) return txid;
    return '${txid.substring(0, 8)}...${txid.substring(txid.length - 8)}';
  }

  /// Check if transaction is confirmed
  bool get isConfirmed {
    return status == TransactionStatus.confirmed && blockHeight != null;
  }

  /// Get confirmations count (mock implementation)
  int get confirmations {
    if (!isConfirmed) return 0;
    // In a real implementation, this would calculate based on current block height
    return 6; // Mock: assume 6 confirmations
  }

  @override
  String toString() {
    return 'Transaction(txid: $shortTxid, amount: $formattedAmount, type: $type, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Transaction && other.txid == txid;
  }

  @override
  int get hashCode => txid.hashCode;
}

/// Transaction types
enum TransactionType {
  sent,
  received,
  pending;

  static TransactionType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'sent':
        return TransactionType.sent;
      case 'received':
        return TransactionType.received;
      case 'pending':
        return TransactionType.pending;
      default:
        return TransactionType.received;
    }
  }

  @override
  String toString() {
    switch (this) {
      case TransactionType.sent:
        return 'sent';
      case TransactionType.received:
        return 'received';
      case TransactionType.pending:
        return 'pending';
    }
  }
}

/// Transaction status
enum TransactionStatus {
  confirming,
  confirmed,
  failed;

  static TransactionStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'pending':
      case 'confirming':
        return TransactionStatus.confirming;
      case 'confirmed':
        return TransactionStatus.confirmed;
      case 'failed':
        return TransactionStatus.failed;
      default:
        return TransactionStatus.confirmed;
    }
  }

  /// Get display name for UI
  String get displayName {
    switch (this) {
      case TransactionStatus.confirming:
        return 'Confirming';
      case TransactionStatus.confirmed:
        return 'Confirmed';
      case TransactionStatus.failed:
        return 'Failed';
    }
  }

  @override
  String toString() {
    switch (this) {
      case TransactionStatus.confirming:
        return 'confirming';
      case TransactionStatus.confirmed:
        return 'confirmed';
      case TransactionStatus.failed:
        return 'failed';
    }
  }
}

/// Transaction filter for history screen
enum TransactionFilter {
  all,
  received,
  sent,
  confirming;

  /// Get display name for UI
  String get displayName {
    switch (this) {
      case TransactionFilter.all:
        return 'All';
      case TransactionFilter.received:
        return 'Received';
      case TransactionFilter.sent:
        return 'Sent';
      case TransactionFilter.confirming:
        return 'Confirming';
    }
  }
}