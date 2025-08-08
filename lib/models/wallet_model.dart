import 'package:json_annotation/json_annotation.dart';

part 'wallet_model.g.dart';

@JsonSerializable()
class WalletModel {
  @JsonKey(name: 'wallet_id')
  final String walletId;
  
  @JsonKey(name: 'transparent_addresses')
  final List<String> transparentAddresses;
  
  @JsonKey(name: 'shielded_addresses')
  final List<String> shieldedAddresses;
  
  final DateTime? createdAt;
  final int? birthdayHeight;

  const WalletModel({
    required this.walletId,
    required this.transparentAddresses,
    required this.shieldedAddresses,
    this.createdAt,
    this.birthdayHeight,
  });

  factory WalletModel.fromJson(Map<String, dynamic> json) => _$WalletModelFromJson(json);
  
  Map<String, dynamic> toJson() => _$WalletModelToJson(this);

  /// Get all addresses combined
  List<String> get allAddresses => [...transparentAddresses, ...shieldedAddresses];

  /// Get total number of addresses
  int get totalAddresses => transparentAddresses.length + shieldedAddresses.length;

  /// Check if wallet has transparent addresses
  bool get hasTransparentAddresses => transparentAddresses.isNotEmpty;

  /// Check if wallet has shielded addresses
  bool get hasShieldedAddresses => shieldedAddresses.isNotEmpty;

  /// Get primary transparent address (first one)
  String? get primaryTransparentAddress => 
      transparentAddresses.isNotEmpty ? transparentAddresses.first : null;

  /// Get primary shielded address (first one)
  String? get primaryShieldedAddress => 
      shieldedAddresses.isNotEmpty ? shieldedAddresses.first : null;

  /// Create a copy with updated values
  WalletModel copyWith({
    String? walletId,
    List<String>? transparentAddresses,
    List<String>? shieldedAddresses,
    DateTime? createdAt,
    int? birthdayHeight,
  }) {
    return WalletModel(
      walletId: walletId ?? this.walletId,
      transparentAddresses: transparentAddresses ?? this.transparentAddresses,
      shieldedAddresses: shieldedAddresses ?? this.shieldedAddresses,
      createdAt: createdAt ?? this.createdAt,
      birthdayHeight: birthdayHeight ?? this.birthdayHeight,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    
    return other is WalletModel &&
        other.walletId == walletId &&
        _listEquals(other.transparentAddresses, transparentAddresses) &&
        _listEquals(other.shieldedAddresses, shieldedAddresses) &&
        other.createdAt == createdAt &&
        other.birthdayHeight == birthdayHeight;
  }

  @override
  int get hashCode {
    return walletId.hashCode ^
        transparentAddresses.hashCode ^
        shieldedAddresses.hashCode ^
        createdAt.hashCode ^
        birthdayHeight.hashCode;
  }

  @override
  String toString() {
    return 'WalletModel('
        'walletId: $walletId, '
        'transparentAddresses: ${transparentAddresses.length}, '
        'shieldedAddresses: ${shieldedAddresses.length}, '
        'createdAt: $createdAt, '
        'birthdayHeight: $birthdayHeight'
        ')';
  }

  bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}