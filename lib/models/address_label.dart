import 'package:flutter/material.dart';
import 'package:json_annotation/json_annotation.dart';

part 'address_label.g.dart';

/// Address label categories for financial organization
enum AddressLabelCategory {
  income,
  expenses,
  savings,
  trading,
  external,
  other,
}

/// Address label types for better organization
enum AddressLabelType {
  // Income sources
  solarIncome,
  familyTransfers,
  salary,
  business,
  freelance,
  investment,
  
  // Expense categories
  bills,
  shopping,
  investmentPurchases,
  food,
  transportation,
  utilities,
  
  // Savings & Investment
  savings,
  emergencyFund,
  trading,
  staking,
  defi,
  
  // External addresses
  exchange,
  friend,
  merchant,
  service,
  donation,
  
  // Other
  personal,
  temporary,
  unknown,
  custom,
}

@JsonSerializable()
class AddressLabel {
  final int? id;
  final String address;
  final String labelName;
  final AddressLabelCategory category;
  final AddressLabelType type;
  final String? description;
  final String color;
  final bool isOwned; // true for own addresses, false for external
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AddressLabel({
    this.id,
    required this.address,
    required this.labelName,
    required this.category,
    required this.type,
    this.description,
    required this.color,
    required this.isOwned,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AddressLabel.fromJson(Map<String, dynamic> json) => _$AddressLabelFromJson(json);
  Map<String, dynamic> toJson() => _$AddressLabelToJson(this);

  AddressLabel copyWith({
    int? id,
    String? address,
    String? labelName,
    AddressLabelCategory? category,
    AddressLabelType? type,
    String? description,
    String? color,
    bool? isOwned,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AddressLabel(
      id: id ?? this.id,
      address: address ?? this.address,
      labelName: labelName ?? this.labelName,
      category: category ?? this.category,
      type: type ?? this.type,
      description: description ?? this.description,
      color: color ?? this.color,
      isOwned: isOwned ?? this.isOwned,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AddressLabel &&
        other.address == address &&
        other.labelName == labelName;
  }

  @override
  int get hashCode => address.hashCode ^ labelName.hashCode;

  @override
  String toString() => 'AddressLabel(address: $address, label: $labelName, category: $category)';
}

/// Address label management utilities
class AddressLabelManager {
  // Predefined label configurations
  static const Map<AddressLabelType, Map<String, dynamic>> _labelConfigs = {
    // Income sources
    AddressLabelType.solarIncome: {
      'name': 'Solar Income',
      'category': AddressLabelCategory.income,
      'color': '#4CAF50',
      'icon': Icons.wb_sunny,
      'description': 'Income from solar energy',
    },
    AddressLabelType.familyTransfers: {
      'name': 'Family Transfers',
      'category': AddressLabelCategory.income,
      'color': '#E91E63',
      'icon': Icons.family_restroom,
      'description': 'Money from family members',
    },
    AddressLabelType.salary: {
      'name': 'Salary',
      'category': AddressLabelCategory.income,
      'color': '#2196F3',
      'icon': Icons.work,
      'description': 'Regular salary payments',
    },
    AddressLabelType.business: {
      'name': 'Business',
      'category': AddressLabelCategory.income,
      'color': '#FF9800',
      'icon': Icons.business,
      'description': 'Business income',
    },
    AddressLabelType.freelance: {
      'name': 'Freelance',
      'category': AddressLabelCategory.income,
      'color': '#9C27B0',
      'icon': Icons.laptop,
      'description': 'Freelance work payments',
    },
    AddressLabelType.investment: {
      'name': 'Investment Returns',
      'category': AddressLabelCategory.income,
      'color': '#00BCD4',
      'icon': Icons.trending_up,
      'description': 'Investment returns and dividends',
    },

    // Expense categories
    AddressLabelType.bills: {
      'name': 'Bills',
      'category': AddressLabelCategory.expenses,
      'color': '#F44336',
      'icon': Icons.receipt_long,
      'description': 'Utility bills and recurring payments',
    },
    AddressLabelType.shopping: {
      'name': 'Shopping',
      'category': AddressLabelCategory.expenses,
      'color': '#FF5722',
      'icon': Icons.shopping_cart,
      'description': 'General shopping expenses',
    },
    AddressLabelType.investmentPurchases: {
      'name': 'Investment Purchases',
      'category': AddressLabelCategory.expenses,
      'color': '#673AB7',
      'icon': Icons.show_chart,
      'description': 'Money spent on investments',
    },
    AddressLabelType.food: {
      'name': 'Food & Dining',
      'category': AddressLabelCategory.expenses,
      'color': '#FF6F00',
      'icon': Icons.restaurant,
      'description': 'Food and restaurant expenses',
    },
    AddressLabelType.transportation: {
      'name': 'Transportation',
      'category': AddressLabelCategory.expenses,
      'color': '#795548',
      'icon': Icons.directions_car,
      'description': 'Transport and fuel costs',
    },
    AddressLabelType.utilities: {
      'name': 'Utilities',
      'category': AddressLabelCategory.expenses,
      'color': '#607D8B',
      'icon': Icons.electrical_services,
      'description': 'Utility services',
    },

    // Savings & Investment
    AddressLabelType.savings: {
      'name': 'Savings',
      'category': AddressLabelCategory.savings,
      'color': '#4CAF50',
      'icon': Icons.savings,
      'description': 'Personal savings account',
    },
    AddressLabelType.emergencyFund: {
      'name': 'Emergency Fund',
      'category': AddressLabelCategory.savings,
      'color': '#FF9800',
      'icon': Icons.security,
      'description': 'Emergency fund savings',
    },
    AddressLabelType.trading: {
      'name': 'Trading',
      'category': AddressLabelCategory.trading,
      'color': '#9C27B0',
      'icon': Icons.candlestick_chart,
      'description': 'Trading activities',
    },
    AddressLabelType.staking: {
      'name': 'Staking',
      'category': AddressLabelCategory.trading,
      'color': '#00BCD4',
      'icon': Icons.lock,
      'description': 'Staking rewards and activities',
    },
    AddressLabelType.defi: {
      'name': 'DeFi',
      'category': AddressLabelCategory.trading,
      'color': '#E91E63',
      'icon': Icons.hub,
      'description': 'DeFi protocol interactions',
    },

    // External addresses
    AddressLabelType.exchange: {
      'name': 'Exchange',
      'category': AddressLabelCategory.external,
      'color': '#3F51B5',
      'icon': Icons.swap_horiz,
      'description': 'Cryptocurrency exchange',
    },
    AddressLabelType.friend: {
      'name': 'Friend',
      'category': AddressLabelCategory.external,
      'color': '#E91E63',
      'icon': Icons.person,
      'description': 'Friend or family member',
    },
    AddressLabelType.merchant: {
      'name': 'Merchant',
      'category': AddressLabelCategory.external,
      'color': '#FF9800',
      'icon': Icons.store,
      'description': 'Online or physical merchant',
    },
    AddressLabelType.service: {
      'name': 'Service',
      'category': AddressLabelCategory.external,
      'color': '#607D8B',
      'icon': Icons.build,
      'description': 'Service provider',
    },
    AddressLabelType.donation: {
      'name': 'Donation',
      'category': AddressLabelCategory.external,
      'color': '#F44336',
      'icon': Icons.favorite,
      'description': 'Charitable donation',
    },

    // Other
    AddressLabelType.personal: {
      'name': 'Personal',
      'category': AddressLabelCategory.other,
      'color': '#9E9E9E',
      'icon': Icons.person_outline,
      'description': 'Personal use',
    },
    AddressLabelType.temporary: {
      'name': 'Temporary',
      'category': AddressLabelCategory.other,
      'color': '#FFEB3B',
      'icon': Icons.schedule,
      'description': 'Temporary address',
    },
    AddressLabelType.unknown: {
      'name': 'Unknown',
      'category': AddressLabelCategory.other,
      'color': '#9E9E9E',
      'icon': Icons.help_outline,
      'description': 'Unknown purpose',
    },
    AddressLabelType.custom: {
      'name': 'Custom',
      'category': AddressLabelCategory.other,
      'color': '#9E9E9E',
      'icon': Icons.label,
      'description': 'Custom label',
    },
  };

  /// Get label configuration for a specific type
  static Map<String, dynamic>? getLabelConfig(AddressLabelType type) {
    return _labelConfigs[type];
  }

  /// Get all label types for a category
  static List<AddressLabelType> getLabelTypesForCategory(AddressLabelCategory category) {
    return _labelConfigs.entries
        .where((entry) => entry.value['category'] == category)
        .map((entry) => entry.key)
        .toList();
  }

  /// Get display name for label type
  static String getDisplayName(AddressLabelType type) {
    return _labelConfigs[type]?['name'] ?? type.toString().split('.').last;
  }

  /// Get color for label type
  static String getColor(AddressLabelType type) {
    return _labelConfigs[type]?['color'] ?? '#9E9E9E';
  }

  /// Get icon for label type
  static IconData getIcon(AddressLabelType type) {
    return _labelConfigs[type]?['icon'] ?? Icons.label;
  }

  /// Get description for label type
  static String getDescription(AddressLabelType type) {
    return _labelConfigs[type]?['description'] ?? '';
  }

  /// Get category display name
  static String getCategoryDisplayName(AddressLabelCategory category) {
    switch (category) {
      case AddressLabelCategory.income:
        return 'Income Sources';
      case AddressLabelCategory.expenses:
        return 'Expenses';
      case AddressLabelCategory.savings:
        return 'Savings & Investment';
      case AddressLabelCategory.trading:
        return 'Trading & DeFi';
      case AddressLabelCategory.external:
        return 'External Addresses';
      case AddressLabelCategory.other:
        return 'Other';
    }
  }

  /// Get category color
  static Color getCategoryColor(AddressLabelCategory category) {
    switch (category) {
      case AddressLabelCategory.income:
        return const Color(0xFF4CAF50);
      case AddressLabelCategory.expenses:
        return const Color(0xFFF44336);
      case AddressLabelCategory.savings:
        return const Color(0xFF2196F3);
      case AddressLabelCategory.trading:
        return const Color(0xFF9C27B0);
      case AddressLabelCategory.external:
        return const Color(0xFF607D8B);
      case AddressLabelCategory.other:
        return const Color(0xFF9E9E9E);
    }
  }

  /// Create a new address label with defaults
  static AddressLabel createLabel({
    required String address,
    required String labelName,
    required AddressLabelType type,
    required bool isOwned,
    String? description,
    String? customColor,
  }) {
    final config = getLabelConfig(type);
    final now = DateTime.now();
    
    return AddressLabel(
      address: address,
      labelName: labelName,
      category: config?['category'] ?? AddressLabelCategory.other,
      type: type,
      description: description ?? config?['description'],
      color: customColor ?? config?['color'] ?? '#9E9E9E',
      isOwned: isOwned,
      createdAt: now,
      updatedAt: now,
    );
  }
}
