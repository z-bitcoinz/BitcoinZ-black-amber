import 'package:flutter/foundation.dart';
import 'package:json_annotation/json_annotation.dart';
import '../utils/constants.dart';

part 'balance_model.g.dart';

@JsonSerializable()
class BalanceModel {
  final double transparent;
  final double shielded;
  final double total;
  final double unconfirmed;
  final double unconfirmedTransparent;
  final double unconfirmedShielded;
  
  // Verified balance fields (funds with sufficient confirmations)
  final double verifiedTransparent;
  final double verifiedShielded;
  
  // Unverified balance fields (funds waiting for confirmations)
  final double unverifiedTransparent;
  final double unverifiedShielded;
  
  // Spendable balance fields (funds available for spending)
  final double spendableTransparent;
  final double spendableShielded;
  
  // Pending change from recent sends (not yet in mempool/blockchain)
  final double pendingChange;
  
  final DateTime? lastUpdated;

  const BalanceModel({
    required this.transparent,
    required this.shielded,
    required this.total,
    this.unconfirmed = 0.0,
    this.unconfirmedTransparent = 0.0,
    this.unconfirmedShielded = 0.0,
    this.verifiedTransparent = 0.0,
    this.verifiedShielded = 0.0,
    this.unverifiedTransparent = 0.0,
    this.unverifiedShielded = 0.0,
    this.spendableTransparent = 0.0,
    this.spendableShielded = 0.0,
    this.pendingChange = 0.0,
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
      unconfirmedTransparent: 0.0,
      unconfirmedShielded: 0.0,
      verifiedTransparent: 0.0,
      verifiedShielded: 0.0,
      unverifiedTransparent: 0.0,
      unverifiedShielded: 0.0,
      spendableTransparent: 0.0,
      spendableShielded: 0.0,
      pendingChange: 0.0,
    );
  }

  /// Get confirmed balance (total - unconfirmed)
  double get confirmed => total - unconfirmed;

  /// Get spendable balance (actually spendable funds, not just confirmed)
  double get spendable => spendableTransparent + spendableShielded;
  
  /// Get effective spendable balance (includes pending change from recent sends)
  double get effectiveSpendable => spendable + pendingChange;
  
  /// Get verified balance (funds with sufficient confirmations)
  double get verified => verifiedTransparent + verifiedShielded;
  
  /// Get unverified balance (funds waiting for confirmations)
  double get unverified => unverifiedTransparent + unverifiedShielded;
  
  /// Get pure incoming balance (unconfirmed minus change returning)
  double get pureIncoming => unconfirmed - unverified;

  /// Check if wallet has any balance
  bool get hasBalance => total > 0;

  /// Check if wallet has transparent balance
  bool get hasTransparentBalance => transparent > 0;

  /// Check if wallet has shielded balance
  bool get hasShieldedBalance => shielded > 0;

  /// Check if wallet has unconfirmed balance
  bool get hasUnconfirmedBalance => unconfirmed > 0;
  
  /// Check if wallet has unconfirmed transparent balance
  bool get hasUnconfirmedTransparentBalance => unconfirmedTransparent > 0;
  
  /// Check if wallet has unconfirmed shielded balance
  bool get hasUnconfirmedShieldedBalance => unconfirmedShielded > 0;

  /// Check if wallet has incoming unconfirmed transparent balance (excludes outgoing change)
  bool get hasIncomingUnconfirmedTransparentBalance {
    // Calculate pure incoming transparent: unconfirmed minus any unverified (change) amounts
    final incomingTransparent = unconfirmedTransparent - unverifiedTransparent;
    return incomingTransparent > 0;
  }
  
  /// Check if wallet has incoming unconfirmed shielded balance (excludes outgoing change)
  bool get hasIncomingUnconfirmedShieldedBalance {
    // Calculate pure incoming shielded: unconfirmed minus any unverified (change) amounts
    final incomingShielded = unconfirmedShielded - unverifiedShielded;
    return incomingShielded > 0;
  }

  /// Get balance in zatoshis
  int get totalZatoshis => (total * AppConstants.zatoshisPerBtcz).round();
  int get transparentZatoshis => (transparent * AppConstants.zatoshisPerBtcz).round();
  int get shieldedZatoshis => (shielded * AppConstants.zatoshisPerBtcz).round();
  int get unconfirmedZatoshis => (unconfirmed * AppConstants.zatoshisPerBtcz).round();
  int get spendableZatoshis => (spendable * AppConstants.zatoshisPerBtcz).round();
  int get verifiedZatoshis => (verified * AppConstants.zatoshisPerBtcz).round();
  int get unverifiedZatoshis => (unverified * AppConstants.zatoshisPerBtcz).round();
  int get spendableTransparentZatoshis => (spendableTransparent * AppConstants.zatoshisPerBtcz).round();
  int get spendableShieldedZatoshis => (spendableShielded * AppConstants.zatoshisPerBtcz).round();

  /// Format balance for display
  String get formattedTotal => _formatBalance(total);
  String get formattedTransparent => _formatBalance(transparent);
  String get formattedShielded => _formatBalance(shielded);
  String get formattedUnconfirmed => _formatBalance(unconfirmed);
  String get formattedUnconfirmedTransparent => _formatBalance(unconfirmedTransparent);
  String get formattedUnconfirmedShielded => _formatBalance(unconfirmedShielded);
  String get formattedSpendable => _formatBalance(spendable);
  String get formattedVerified => _formatBalance(verified);
  String get formattedUnverified => _formatBalance(unverified);
  String get formattedPureIncoming => _formatBalance(pureIncoming);
  String get formattedVerifiedTransparent => _formatBalance(verifiedTransparent);
  String get formattedVerifiedShielded => _formatBalance(verifiedShielded);
  String get formattedUnverifiedTransparent => _formatBalance(unverifiedTransparent);
  String get formattedUnverifiedShielded => _formatBalance(unverifiedShielded);
  String get formattedSpendableTransparent => _formatBalance(spendableTransparent);
  String get formattedSpendableShielded => _formatBalance(spendableShielded);
  String get formattedPendingChange => _formatBalance(pendingChange);
  String get formattedEffectiveSpendable => _formatBalance(effectiveSpendable);

  /// Check if sufficient balance for amount
  bool hasSufficientBalance(double amount) {
    final sufficient = spendable >= amount;
    if (kDebugMode) {
      print('💰 BALANCE CHECK:');
      print('   Requested Amount: $amount BTCZ');
      print('   Spendable Balance: $spendable BTCZ');
      print('   Total Balance: $total BTCZ');
      print('   Transparent: $transparent BTCZ');
      print('   Shielded: $shielded BTCZ');
      print('   Unconfirmed: $unconfirmed BTCZ');
      print('   Sufficient: $sufficient');
      if (!sufficient) {
        print('   Shortfall: ${amount - spendable} BTCZ');
      }
    }
    return sufficient;
  }

  /// Check if sufficient transparent balance for amount
  bool hasSufficientTransparentBalance(double amount) => transparent >= amount;

  /// Check if sufficient shielded balance for amount
  bool hasSufficientShieldedBalance(double amount) => shielded >= amount;
  
  /// Check if sufficient spendable transparent balance for amount
  bool hasSufficientSpendableTransparentBalance(double amount) => spendableTransparent >= amount;

  /// Check if sufficient spendable shielded balance for amount
  bool hasSufficientSpendableShieldedBalance(double amount) => spendableShielded >= amount;
  
  /// Check if sufficient verified balance for amount
  bool hasSufficientVerifiedBalance(double amount) => verified >= amount;

  /// Get percentage of balance in each pool
  double get transparentPercentage => total > 0 ? (transparent / total) * 100 : 0;
  double get shieldedPercentage => total > 0 ? (shielded / total) * 100 : 0;

  /// Create a copy with updated values
  BalanceModel copyWith({
    double? transparent,
    double? shielded,
    double? total,
    double? unconfirmed,
    double? unconfirmedTransparent,
    double? unconfirmedShielded,
    double? verifiedTransparent,
    double? verifiedShielded,
    double? unverifiedTransparent,
    double? unverifiedShielded,
    double? spendableTransparent,
    double? spendableShielded,
    double? pendingChange,
    DateTime? lastUpdated,
  }) {
    return BalanceModel(
      transparent: transparent ?? this.transparent,
      shielded: shielded ?? this.shielded,
      total: total ?? this.total,
      unconfirmed: unconfirmed ?? this.unconfirmed,
      unconfirmedTransparent: unconfirmedTransparent ?? this.unconfirmedTransparent,
      unconfirmedShielded: unconfirmedShielded ?? this.unconfirmedShielded,
      verifiedTransparent: verifiedTransparent ?? this.verifiedTransparent,
      verifiedShielded: verifiedShielded ?? this.verifiedShielded,
      unverifiedTransparent: unverifiedTransparent ?? this.unverifiedTransparent,
      unverifiedShielded: unverifiedShielded ?? this.unverifiedShielded,
      spendableTransparent: spendableTransparent ?? this.spendableTransparent,
      spendableShielded: spendableShielded ?? this.spendableShielded,
      pendingChange: pendingChange ?? this.pendingChange,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  /// Update timestamp to now
  BalanceModel withCurrentTimestamp() {
    return copyWith(lastUpdated: DateTime.now());
  }

  /// Private helper to format balance
  /// Show full precision up to 8 decimals and trim trailing zeros (no asterisks)
  String _formatBalance(double balance) {
    if (balance == 0) return '0';

    // Format to 8 decimals (BTCZ precision), then trim trailing zeros and decimal point
    String formatted = balance.toStringAsFixed(8);
    if (formatted.contains('.')) {
      formatted = formatted.replaceAll(RegExp(r'0*$'), '');
      formatted = formatted.replaceAll(RegExp(r'\.$'), '');
    }
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
        other.verifiedTransparent == verifiedTransparent &&
        other.verifiedShielded == verifiedShielded &&
        other.unverifiedTransparent == unverifiedTransparent &&
        other.unverifiedShielded == unverifiedShielded &&
        other.spendableTransparent == spendableTransparent &&
        other.spendableShielded == spendableShielded &&
        other.pendingChange == pendingChange &&
        other.lastUpdated == lastUpdated;
  }

  @override
  int get hashCode {
    return transparent.hashCode ^
        shielded.hashCode ^
        total.hashCode ^
        unconfirmed.hashCode ^
        verifiedTransparent.hashCode ^
        verifiedShielded.hashCode ^
        unverifiedTransparent.hashCode ^
        unverifiedShielded.hashCode ^
        spendableTransparent.hashCode ^
        spendableShielded.hashCode ^
        pendingChange.hashCode ^
        lastUpdated.hashCode;
  }

  @override
  String toString() {
    return 'BalanceModel('
        'transparent: $transparent, '
        'shielded: $shielded, '
        'total: $total, '
        'unconfirmed: $unconfirmed, '
        'verified: $verified, '
        'unverified: $unverified, '
        'spendable: $spendable, '
        'pendingChange: $pendingChange, '
        'lastUpdated: $lastUpdated'
        ')';
  }
}