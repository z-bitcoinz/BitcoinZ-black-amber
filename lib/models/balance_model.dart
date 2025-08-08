import 'package:json_annotation/json_annotation.dart';
import '../utils/constants.dart';

part 'balance_model.g.dart';

@JsonSerializable()
class BalanceModel {
  final double transparent;
  final double shielded;
  final double total;
  final double unconfirmed;
  final DateTime? lastUpdated;

  const BalanceModel({
    required this.transparent,
    required this.shielded,
    required this.total,
    this.unconfirmed = 0.0,
    this.lastUpdated,
  });

  factory BalanceModel.fromJson(Map<String, dynamic> json) => _$BalanceModelFromJson(json);
  
  Map<String, dynamic> toJson() => _$BalanceModelToJson(this);

  /// Create an empty balance
  factory BalanceModel.empty() {
    return const BalanceModel(
      transparent: 0.0,
      shielded: 0.0,
      total: 0.0,
      unconfirmed: 0.0,
    );
  }

  /// Get confirmed balance (total - unconfirmed)
  double get confirmed => total - unconfirmed;

  /// Get spendable balance (confirmed balance)
  double get spendable => confirmed;

  /// Check if wallet has any balance
  bool get hasBalance => total > 0;

  /// Check if wallet has transparent balance
  bool get hasTransparentBalance => transparent > 0;

  /// Check if wallet has shielded balance
  bool get hasShieldedBalance => shielded > 0;

  /// Check if wallet has unconfirmed balance
  bool get hasUnconfirmedBalance => unconfirmed > 0;

  /// Get balance in zatoshis
  int get totalZatoshis => (total * AppConstants.zatoshisPerBtcz).round();
  int get transparentZatoshis => (transparent * AppConstants.zatoshisPerBtcz).round();
  int get shieldedZatoshis => (shielded * AppConstants.zatoshisPerBtcz).round();
  int get unconfirmedZatoshis => (unconfirmed * AppConstants.zatoshisPerBtcz).round();
  int get spendableZatoshis => (spendable * AppConstants.zatoshisPerBtcz).round();

  /// Format balance for display
  String get formattedTotal => _formatBalance(total);
  String get formattedTransparent => _formatBalance(transparent);
  String get formattedShielded => _formatBalance(shielded);
  String get formattedUnconfirmed => _formatBalance(unconfirmed);
  String get formattedSpendable => _formatBalance(spendable);

  /// Check if sufficient balance for amount
  bool hasSufficientBalance(double amount) => spendable >= amount;

  /// Check if sufficient transparent balance for amount
  bool hasSufficientTransparentBalance(double amount) => transparent >= amount;

  /// Check if sufficient shielded balance for amount
  bool hasSufficientShieldedBalance(double amount) => shielded >= amount;

  /// Get percentage of balance in each pool
  double get transparentPercentage => total > 0 ? (transparent / total) * 100 : 0;
  double get shieldedPercentage => total > 0 ? (shielded / total) * 100 : 0;

  /// Create a copy with updated values
  BalanceModel copyWith({
    double? transparent,
    double? shielded,
    double? total,
    double? unconfirmed,
    DateTime? lastUpdated,
  }) {
    return BalanceModel(
      transparent: transparent ?? this.transparent,
      shielded: shielded ?? this.shielded,
      total: total ?? this.total,
      unconfirmed: unconfirmed ?? this.unconfirmed,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  /// Update timestamp to now
  BalanceModel withCurrentTimestamp() {
    return copyWith(lastUpdated: DateTime.now());
  }

  /// Private helper to format balance
  String _formatBalance(double balance) {
    if (balance == 0) return '0.00000000';
    
    // Show up to 8 decimal places, removing trailing zeros
    String formatted = balance.toStringAsFixed(8);
    formatted = formatted.replaceAll(RegExp(r'0*$'), '');
    formatted = formatted.replaceAll(RegExp(r'\.$'), '');
    
    return formatted;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    
    return other is BalanceModel &&
        other.transparent == transparent &&
        other.shielded == shielded &&
        other.total == total &&
        other.unconfirmed == unconfirmed &&
        other.lastUpdated == lastUpdated;
  }

  @override
  int get hashCode {
    return transparent.hashCode ^
        shielded.hashCode ^
        total.hashCode ^
        unconfirmed.hashCode ^
        lastUpdated.hashCode;
  }

  @override
  String toString() {
    return 'BalanceModel('
        'transparent: $transparent, '
        'shielded: $shielded, '
        'total: $total, '
        'unconfirmed: $unconfirmed, '
        'lastUpdated: $lastUpdated'
        ')';
  }
}