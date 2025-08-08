class AddressModel {
  final String address;
  final String type; // 'transparent' or 'shielded'
  final String? label;
  final double balance;
  final bool isActive;

  const AddressModel({
    required this.address,
    required this.type,
    this.label,
    this.balance = 0.0,
    this.isActive = true,
  });

  AddressModel copyWith({
    String? address,
    String? type,
    String? label,
    double? balance,
    bool? isActive,
  }) {
    return AddressModel(
      address: address ?? this.address,
      type: type ?? this.type,
      label: label ?? this.label,
      balance: balance ?? this.balance,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'address': address,
      'type': type,
      'label': label,
      'balance': balance,
      'isActive': isActive,
    };
  }

  factory AddressModel.fromJson(Map<String, dynamic> json) {
    return AddressModel(
      address: json['address'] as String,
      type: json['type'] as String,
      label: json['label'] as String?,
      balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AddressModel &&
          runtimeType == other.runtimeType &&
          address == other.address;

  @override
  int get hashCode => address.hashCode;

  @override
  String toString() {
    return 'AddressModel{address: $address, type: $type, label: $label, balance: $balance, isActive: $isActive}';
  }

  bool get isTransparent => type == 'transparent';
  bool get isShielded => type == 'shielded';
  
  String get displayName => label?.isNotEmpty == true ? label! : _shortenAddress();
  
  String _shortenAddress() {
    if (address.length <= 16) return address;
    return '${address.substring(0, 8)}...${address.substring(address.length - 8)}';
  }
}