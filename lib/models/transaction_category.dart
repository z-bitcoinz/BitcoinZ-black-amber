import 'package:flutter/material.dart';
import 'transaction_model.dart';

/// Comprehensive transaction categorization system
enum TransactionCategoryType {
  income,
  expenses,
  transfers,
  investments,
  other,
}

class TransactionCategory {
  final TransactionCategoryType type;
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final List<String> keywords;
  final double confidenceScore;

  const TransactionCategory({
    required this.type,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.keywords,
    this.confidenceScore = 0.0,
  });



  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TransactionCategory &&
        other.type == type &&
        other.name == name;
  }

  @override
  int get hashCode => type.hashCode ^ name.hashCode;

  @override
  String toString() => 'TransactionCategory(type: $type, name: $name)';
}

/// Smart transaction categorization service
class TransactionCategorizer {
  // Predefined categories with smart classification rules
  static const List<TransactionCategory> _predefinedCategories = [
    // INCOME CATEGORIES
    TransactionCategory(
      type: TransactionCategoryType.income,
      name: 'Salary',
      description: 'Regular salary payments and wages',
      icon: Icons.work,
      color: Color(0xFF4CAF50),
      keywords: ['salary', 'wage', 'payroll', 'income', 'payment', 'monthly', 'weekly'],
    ),
    TransactionCategory(
      type: TransactionCategoryType.income,
      name: 'Gift Received',
      description: 'Money received as gifts',
      icon: Icons.card_giftcard,
      color: Color(0xFFE91E63),
      keywords: ['gift', 'birthday', 'christmas', 'holiday', 'present', 'bonus'],
    ),
    TransactionCategory(
      type: TransactionCategoryType.income,
      name: 'Payment Received',
      description: 'Payments received for services or goods',
      icon: Icons.payment,
      color: Color(0xFF2196F3),
      keywords: ['payment', 'invoice', 'service', 'freelance', 'commission', 'refund'],
    ),
    TransactionCategory(
      type: TransactionCategoryType.income,
      name: 'Investment Return',
      description: 'Returns from investments, dividends, interest',
      icon: Icons.trending_up,
      color: Color(0xFF00BCD4),
      keywords: ['dividend', 'interest', 'return', 'profit', 'yield', 'staking', 'reward'],
    ),

    // EXPENSE CATEGORIES
    TransactionCategory(
      type: TransactionCategoryType.expenses,
      name: 'Purchase',
      description: 'General purchases and shopping',
      icon: Icons.shopping_cart,
      color: Color(0xFFFF9800),
      keywords: ['purchase', 'buy', 'shop', 'store', 'retail', 'order', 'product'],
    ),
    TransactionCategory(
      type: TransactionCategoryType.expenses,
      name: 'Bills & Utilities',
      description: 'Utility bills, rent, subscriptions',
      icon: Icons.receipt_long,
      color: Color(0xFF9C27B0),
      keywords: ['bill', 'utility', 'rent', 'subscription', 'electric', 'water', 'gas', 'internet'],
    ),
    TransactionCategory(
      type: TransactionCategoryType.expenses,
      name: 'Services',
      description: 'Professional services and fees',
      icon: Icons.build,
      color: Color(0xFF607D8B),
      keywords: ['service', 'fee', 'repair', 'maintenance', 'professional', 'consultation'],
    ),
    TransactionCategory(
      type: TransactionCategoryType.expenses,
      name: 'Food & Dining',
      description: 'Restaurant meals, food delivery, groceries',
      icon: Icons.restaurant,
      color: Color(0xFFFF5722),
      keywords: ['food', 'restaurant', 'dining', 'meal', 'grocery', 'delivery', 'coffee'],
    ),
    TransactionCategory(
      type: TransactionCategoryType.expenses,
      name: 'Transportation',
      description: 'Travel, fuel, public transport',
      icon: Icons.directions_car,
      color: Color(0xFF795548),
      keywords: ['transport', 'fuel', 'gas', 'taxi', 'uber', 'bus', 'train', 'travel'],
    ),

    // TRANSFER CATEGORIES
    TransactionCategory(
      type: TransactionCategoryType.transfers,
      name: 'Exchange',
      description: 'Cryptocurrency exchange transactions',
      icon: Icons.swap_horiz,
      color: Color(0xFF3F51B5),
      keywords: ['exchange', 'swap', 'trade', 'convert', 'binance', 'coinbase', 'kraken'],
    ),
    TransactionCategory(
      type: TransactionCategoryType.transfers,
      name: 'Wallet Transfer',
      description: 'Transfers between own wallets',
      icon: Icons.account_balance_wallet,
      color: Color(0xFF009688),
      keywords: ['transfer', 'move', 'wallet', 'internal', 'consolidate', 'migrate'],
    ),
    TransactionCategory(
      type: TransactionCategoryType.transfers,
      name: 'Bank Transfer',
      description: 'Transfers to/from bank accounts',
      icon: Icons.account_balance,
      color: Color(0xFF673AB7),
      keywords: ['bank', 'withdraw', 'deposit', 'fiat', 'cash out', 'cash in'],
    ),

    // INVESTMENT CATEGORIES
    TransactionCategory(
      type: TransactionCategoryType.investments,
      name: 'Trading',
      description: 'Active trading transactions',
      icon: Icons.show_chart,
      color: Color(0xFFFF6F00),
      keywords: ['trade', 'trading', 'buy', 'sell', 'market', 'order', 'position'],
    ),
    TransactionCategory(
      type: TransactionCategoryType.investments,
      name: 'Staking',
      description: 'Staking and delegation transactions',
      icon: Icons.lock,
      color: Color(0xFF8BC34A),
      keywords: ['stake', 'staking', 'delegate', 'validator', 'node', 'pool'],
    ),
    TransactionCategory(
      type: TransactionCategoryType.investments,
      name: 'DeFi',
      description: 'Decentralized finance transactions',
      icon: Icons.hub,
      color: Color(0xFFE91E63),
      keywords: ['defi', 'liquidity', 'yield', 'farming', 'pool', 'protocol', 'dex'],
    ),

    // OTHER CATEGORY
    TransactionCategory(
      type: TransactionCategoryType.other,
      name: 'Donation',
      description: 'Charitable donations and tips',
      icon: Icons.favorite,
      color: Color(0xFFF44336),
      keywords: ['donation', 'charity', 'tip', 'support', 'contribute', 'help'],
    ),
    TransactionCategory(
      type: TransactionCategoryType.other,
      name: 'Miscellaneous',
      description: 'Other uncategorized transactions',
      icon: Icons.more_horiz,
      color: Color(0xFF9E9E9E),
      keywords: [],
    ),
  ];

  /// Get all predefined categories
  static List<TransactionCategory> get allCategories => _predefinedCategories;

  /// Get categories by type
  static List<TransactionCategory> getCategoriesByType(TransactionCategoryType type) {
    return _predefinedCategories.where((cat) => cat.type == type).toList();
  }

  /// Automatically categorize a transaction using smart classification
  static TransactionCategory categorizeTransaction(TransactionModel transaction) {
    final memo = transaction.memo?.toLowerCase() ?? '';
    final amount = transaction.amount;
    final isIncoming = transaction.isReceived;
    final address = (transaction.toAddress ?? transaction.fromAddress ?? '').toLowerCase();

    // Calculate confidence scores for each category
    final Map<TransactionCategory, double> scores = {};

    for (final category in _predefinedCategories) {
      double score = 0.0;

      // Basic direction scoring
      if (category.type == TransactionCategoryType.income && isIncoming) {
        score += 0.3;
      } else if (category.type == TransactionCategoryType.expenses && !isIncoming) {
        score += 0.3;
      } else if (category.type == TransactionCategoryType.transfers) {
        score += 0.1; // Neutral for transfers
      }

      // Keyword matching in memo
      if (memo.isNotEmpty) {
        for (final keyword in category.keywords) {
          if (memo.contains(keyword)) {
            score += 0.4; // High weight for keyword matches
            break; // Only count one keyword match per category
          }
        }
      }

      // Amount-based heuristics
      if (category.name == 'Salary' && amount >= 100000000 && isIncoming) { // >= 1 BTCZ
        score += 0.2;
      } else if (category.name == 'Gift Received' && amount < 100000000 && isIncoming) { // < 1 BTCZ
        score += 0.1;
      } else if (category.name == 'Purchase' && amount < 1000000000 && !isIncoming) { // < 10 BTCZ
        score += 0.1;
      }

      // Address-based heuristics (exchange patterns)
      if (category.name == 'Exchange' && address.length > 30) {
        score += 0.1; // Long addresses might be exchanges
      }

      scores[category] = score;
    }

    // Find the category with the highest score
    TransactionCategory bestCategory = _predefinedCategories.last; // Default to Miscellaneous
    double bestScore = 0.0;

    scores.forEach((category, score) {
      if (score > bestScore) {
        bestScore = score;
        bestCategory = category;
      }
    });

    // Return category with confidence score
    return TransactionCategory(
      type: bestCategory.type,
      name: bestCategory.name,
      description: bestCategory.description,
      icon: bestCategory.icon,
      color: bestCategory.color,
      keywords: bestCategory.keywords,
      confidenceScore: bestScore,
    );
  }

  /// Get category by name
  static TransactionCategory? getCategoryByName(String name) {
    try {
      return _predefinedCategories.firstWhere((cat) => cat.name == name);
    } catch (e) {
      return null;
    }
  }

  /// Get category type display name
  static String getCategoryTypeDisplayName(TransactionCategoryType type) {
    switch (type) {
      case TransactionCategoryType.income:
        return 'Income';
      case TransactionCategoryType.expenses:
        return 'Expenses';
      case TransactionCategoryType.transfers:
        return 'Transfers';
      case TransactionCategoryType.investments:
        return 'Investments';
      case TransactionCategoryType.other:
        return 'Other';
    }
  }

  /// Get category type color
  static Color getCategoryTypeColor(TransactionCategoryType type) {
    switch (type) {
      case TransactionCategoryType.income:
        return const Color(0xFF4CAF50);
      case TransactionCategoryType.expenses:
        return const Color(0xFFFF9800);
      case TransactionCategoryType.transfers:
        return const Color(0xFF2196F3);
      case TransactionCategoryType.investments:
        return const Color(0xFF9C27B0);
      case TransactionCategoryType.other:
        return const Color(0xFF9E9E9E);
    }
  }

  /// Get category type icon
  static IconData getCategoryTypeIcon(TransactionCategoryType type) {
    switch (type) {
      case TransactionCategoryType.income:
        return Icons.trending_up;
      case TransactionCategoryType.expenses:
        return Icons.trending_down;
      case TransactionCategoryType.transfers:
        return Icons.swap_horiz;
      case TransactionCategoryType.investments:
        return Icons.show_chart;
      case TransactionCategoryType.other:
        return Icons.more_horiz;
    }
  }
}
