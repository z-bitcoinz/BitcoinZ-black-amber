class ContactModel {
  final int? id;
  final String name;
  final String address;
  final String type; // 'transparent' or 'shielded'
  final String? description;
  final String? pictureBase64; // Base64 encoded image data
  final bool isFavorite;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ContactModel({
    this.id,
    required this.name,
    required this.address,
    required this.type,
    this.description,
    this.pictureBase64,
    this.isFavorite = false,
    required this.createdAt,
    required this.updatedAt,
  });

  ContactModel copyWith({
    int? id,
    String? name,
    String? address,
    String? type,
    String? description,
    String? pictureBase64,
    bool? isFavorite,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ContactModel(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      type: type ?? this.type,
      description: description ?? this.description,
      pictureBase64: pictureBase64 ?? this.pictureBase64,
      isFavorite: isFavorite ?? this.isFavorite,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'type': type,
      'description': description,
      'picture_base64': pictureBase64,
      'is_favorite': isFavorite,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory ContactModel.fromJson(Map<String, dynamic> json) {
    return ContactModel(
      id: json['id'] as int?,
      name: json['name'] as String,
      address: json['address'] as String,
      type: json['type'] as String,
      description: json['description'] as String?,
      pictureBase64: json['picture_base64'] as String?,
      isFavorite: json['is_favorite'] as bool? ?? false,
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(json['updated_at'] as int),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContactModel &&
          runtimeType == other.runtimeType &&
          address == other.address;

  @override
  int get hashCode => address.hashCode;

  @override
  String toString() {
    return 'ContactModel{id: $id, name: $name, address: $address, type: $type, description: $description, isFavorite: $isFavorite}';
  }

  bool get isTransparent => type == 'transparent';
  bool get isShielded => type == 'shielded';

  String get displayName => name.isNotEmpty ? name : _shortenAddress();
  String get fullDisplayName => description?.isNotEmpty == true ? '$name ($description)' : name;

  String _shortenAddress() {
    if (address.length <= 16) return address;
    return '${address.substring(0, 8)}...${address.substring(address.length - 8)}';
  }
}