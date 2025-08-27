import 'package:flutter/material.dart';
import 'transaction_model.dart';
import 'transaction_category.dart';

/// Time period for analytics calculations
enum AnalyticsPeriod {
  oneMonth,
  threeMonths,
  sixMonths,
  oneYear,
  all,
}

/// Analytics data point for time series
class AnalyticsDataPoint {
  final DateTime date;
  final double income;
  final double expenses;
  final double netFlow;
  final int transactionCount;

  const AnalyticsDataPoint({
    required this.date,
    required this.income,
    required this.expenses,
    required this.netFlow,
    required this.transactionCount,
  });

  @override
  String toString() => 'AnalyticsDataPoint(date: $date, income: $income, expenses: $expenses, netFlow: $netFlow)';
}

/// Category analytics data
class CategoryAnalytics {
  final TransactionCategoryType categoryType;
  final String categoryName;
  final double totalAmount;
  final double percentage;
  final int transactionCount;
  final Color color;
  final List<TransactionModel> transactions;

  const CategoryAnalytics({
    required this.categoryType,
    required this.categoryName,
    required this.totalAmount,
    required this.percentage,
    required this.transactionCount,
    required this.color,
    required this.transactions,
  });

  @override
  String toString() => 'CategoryAnalytics(category: $categoryName, amount: $totalAmount, percentage: $percentage%)';
}

/// Comprehensive financial analytics data
class FinancialAnalytics {
  final AnalyticsPeriod period;
  final DateTime startDate;
  final DateTime endDate;
  final List<TransactionModel> transactions;
  
  // Summary metrics
  final double totalIncome;
  final double totalExpenses;
  final double netFlow;
  final double averageTransactionAmount;
  final int totalTransactions;
  
  // Category breakdown
  final List<CategoryAnalytics> categoryBreakdown;
  final Map<TransactionCategoryType, double> categoryTotals;
  
  // Time series data
  final List<AnalyticsDataPoint> dailyData;
  final List<AnalyticsDataPoint> weeklyData;
  final List<AnalyticsDataPoint> monthlyData;
  
  // Trends and insights
  final double incomeGrowthRate;
  final double expenseGrowthRate;
  final TransactionCategoryType topIncomeCategory;
  final TransactionCategoryType topExpenseCategory;
  final double savingsRate; // (Income - Expenses) / Income * 100

  const FinancialAnalytics({
    required this.period,
    required this.startDate,
    required this.endDate,
    required this.transactions,
    required this.totalIncome,
    required this.totalExpenses,
    required this.netFlow,
    required this.averageTransactionAmount,
    required this.totalTransactions,
    required this.categoryBreakdown,
    required this.categoryTotals,
    required this.dailyData,
    required this.weeklyData,
    required this.monthlyData,
    required this.incomeGrowthRate,
    required this.expenseGrowthRate,
    required this.topIncomeCategory,
    required this.topExpenseCategory,
    required this.savingsRate,
  });

  /// Create analytics from transaction list
  static FinancialAnalytics fromTransactions({
    required List<TransactionModel> transactions,
    required AnalyticsPeriod period,
    DateTime? customStartDate,
    DateTime? customEndDate,
  }) {
    final now = DateTime.now();
    late DateTime startDate;
    late DateTime endDate;

    if (customStartDate != null && customEndDate != null) {
      startDate = customStartDate;
      endDate = customEndDate;
    } else {
      endDate = now;
      switch (period) {
        case AnalyticsPeriod.oneMonth:
          startDate = DateTime(now.year, now.month - 1, now.day);
          break;
        case AnalyticsPeriod.threeMonths:
          startDate = DateTime(now.year, now.month - 3, now.day);
          break;
        case AnalyticsPeriod.sixMonths:
          startDate = DateTime(now.year, now.month - 6, now.day);
          break;
        case AnalyticsPeriod.oneYear:
          startDate = DateTime(now.year - 1, now.month, now.day);
          break;
        case AnalyticsPeriod.all:
          startDate = transactions.isNotEmpty 
              ? transactions.map((t) => t.timestamp).reduce((a, b) => a.isBefore(b) ? a : b)
              : DateTime(2020, 1, 1);
          break;
      }
    }

    // Filter transactions by date range
    final filteredTransactions = transactions
        .where((tx) => tx.timestamp.isAfter(startDate) && tx.timestamp.isBefore(endDate))
        .toList();

    // Calculate basic metrics
    double totalIncome = 0;
    double totalExpenses = 0;
    final Map<TransactionCategoryType, double> categoryTotals = {};
    final Map<TransactionCategoryType, List<TransactionModel>> categoryTransactions = {};

    for (final transaction in filteredTransactions) {
      final amount = transaction.amount.abs();
      final category = TransactionCategorizer.categorizeTransaction(transaction);
      
      if (transaction.isReceived) {
        totalIncome += amount;
      } else {
        totalExpenses += amount;
      }

      categoryTotals[category.type] = (categoryTotals[category.type] ?? 0) + amount;
      categoryTransactions[category.type] = (categoryTransactions[category.type] ?? [])..add(transaction);
    }

    final netFlow = totalIncome - totalExpenses;
    final averageTransactionAmount = filteredTransactions.isNotEmpty 
        ? filteredTransactions.map((t) => t.amount.abs()).reduce((a, b) => a + b) / filteredTransactions.length
        : 0.0;
    final savingsRate = totalIncome > 0 ? (netFlow / totalIncome) * 100 : 0.0;

    // Create category breakdown
    final totalAmount = totalIncome + totalExpenses;
    final categoryBreakdown = categoryTotals.entries.map((entry) {
      final percentage = totalAmount > 0 ? (entry.value / totalAmount) * 100 : 0.0;
      return CategoryAnalytics(
        categoryType: entry.key,
        categoryName: TransactionCategorizer.getCategoryTypeDisplayName(entry.key),
        totalAmount: entry.value,
        percentage: percentage,
        transactionCount: categoryTransactions[entry.key]?.length ?? 0,
        color: TransactionCategorizer.getCategoryTypeColor(entry.key),
        transactions: categoryTransactions[entry.key] ?? [],
      );
    }).toList()..sort((a, b) => b.totalAmount.compareTo(a.totalAmount));

    // Find top categories
    final incomeCategories = categoryBreakdown.where((c) => 
        c.transactions.any((t) => t.isReceived)).toList();
    final expenseCategories = categoryBreakdown.where((c) => 
        c.transactions.any((t) => !t.isReceived)).toList();

    final topIncomeCategory = incomeCategories.isNotEmpty 
        ? incomeCategories.first.categoryType 
        : TransactionCategoryType.other;
    final topExpenseCategory = expenseCategories.isNotEmpty 
        ? expenseCategories.first.categoryType 
        : TransactionCategoryType.other;

    // Generate time series data
    final dailyData = _generateTimeSeriesData(filteredTransactions, 'daily', startDate, endDate);
    final weeklyData = _generateTimeSeriesData(filteredTransactions, 'weekly', startDate, endDate);
    final monthlyData = _generateTimeSeriesData(filteredTransactions, 'monthly', startDate, endDate);

    // Calculate growth rates (simplified - comparing first and last periods)
    double incomeGrowthRate = 0.0;
    double expenseGrowthRate = 0.0;
    
    if (monthlyData.length >= 2) {
      final firstMonth = monthlyData.first;
      final lastMonth = monthlyData.last;
      
      if (firstMonth.income > 0) {
        incomeGrowthRate = ((lastMonth.income - firstMonth.income) / firstMonth.income) * 100;
      }
      if (firstMonth.expenses > 0) {
        expenseGrowthRate = ((lastMonth.expenses - firstMonth.expenses) / firstMonth.expenses) * 100;
      }
    }

    return FinancialAnalytics(
      period: period,
      startDate: startDate,
      endDate: endDate,
      transactions: filteredTransactions,
      totalIncome: totalIncome,
      totalExpenses: totalExpenses,
      netFlow: netFlow,
      averageTransactionAmount: averageTransactionAmount,
      totalTransactions: filteredTransactions.length,
      categoryBreakdown: categoryBreakdown,
      categoryTotals: categoryTotals,
      dailyData: dailyData,
      weeklyData: weeklyData,
      monthlyData: monthlyData,
      incomeGrowthRate: incomeGrowthRate,
      expenseGrowthRate: expenseGrowthRate,
      topIncomeCategory: topIncomeCategory,
      topExpenseCategory: topExpenseCategory,
      savingsRate: savingsRate,
    );
  }

  /// Generate time series data points
  static List<AnalyticsDataPoint> _generateTimeSeriesData(
    List<TransactionModel> transactions,
    String interval,
    DateTime startDate,
    DateTime endDate,
  ) {
    final Map<String, List<TransactionModel>> groupedTransactions = {};
    
    for (final transaction in transactions) {
      String key;
      switch (interval) {
        case 'daily':
          key = '${transaction.timestamp.year}-${transaction.timestamp.month.toString().padLeft(2, '0')}-${transaction.timestamp.day.toString().padLeft(2, '0')}';
          break;
        case 'weekly':
          final weekStart = transaction.timestamp.subtract(Duration(days: transaction.timestamp.weekday - 1));
          key = '${weekStart.year}-W${((weekStart.difference(DateTime(weekStart.year, 1, 1)).inDays) / 7).ceil()}';
          break;
        case 'monthly':
          key = '${transaction.timestamp.year}-${transaction.timestamp.month.toString().padLeft(2, '0')}';
          break;
        default:
          key = transaction.timestamp.toIso8601String();
      }
      
      groupedTransactions[key] = (groupedTransactions[key] ?? [])..add(transaction);
    }

    return groupedTransactions.entries.map((entry) {
      double income = 0;
      double expenses = 0;
      
      for (final transaction in entry.value) {
        if (transaction.isReceived) {
          income += transaction.amount.abs();
        } else {
          expenses += transaction.amount.abs();
        }
      }
      
      return AnalyticsDataPoint(
        date: entry.value.first.timestamp,
        income: income,
        expenses: expenses,
        netFlow: income - expenses,
        transactionCount: entry.value.length,
      );
    }).toList()..sort((a, b) => a.date.compareTo(b.date));
  }

  @override
  String toString() => 'FinancialAnalytics(period: $period, income: $totalIncome, expenses: $totalExpenses, netFlow: $netFlow)';
}
