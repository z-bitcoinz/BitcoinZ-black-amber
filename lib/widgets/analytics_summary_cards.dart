import 'package:flutter/material.dart';
import '../models/analytics_data.dart';

/// Summary cards showing key financial metrics
class AnalyticsSummaryCards extends StatelessWidget {
  final FinancialAnalytics analytics;
  final AnalyticsPeriod? previousPeriod;

  const AnalyticsSummaryCards({
    super.key,
    required this.analytics,
    this.previousPeriod,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Primary metrics row
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                context,
                'Total Income',
                '${analytics.totalIncome.toStringAsFixed(2)} BTCZ',
                Icons.trending_up,
                Colors.green,
                _getIncomeChange(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                context,
                'Total Expenses',
                '${analytics.totalExpenses.toStringAsFixed(2)} BTCZ',
                Icons.trending_down,
                Colors.red,
                _getExpenseChange(),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 12),
        
        // Secondary metrics row
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                context,
                'Net Flow',
                '${analytics.netFlow.toStringAsFixed(2)} BTCZ',
                analytics.netFlow >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
                analytics.netFlow >= 0 ? Colors.green : Colors.red,
                null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                context,
                'Savings Rate',
                '${analytics.savingsRate.toStringAsFixed(1)}%',
                Icons.savings,
                _getSavingsRateColor(analytics.savingsRate),
                null,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 12),
        
        // Additional metrics row
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                context,
                'Transactions',
                '${analytics.totalTransactions}',
                Icons.receipt_long,
                Colors.blue,
                null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                context,
                'Avg Amount',
                '${analytics.averageTransactionAmount.toStringAsFixed(2)} BTCZ',
                Icons.calculate,
                Colors.purple,
                null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
    double? changePercentage,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (changePercentage != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  changePercentage >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 12,
                  color: changePercentage >= 0 ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 2),
                Text(
                  '${changePercentage.abs().toStringAsFixed(1)}%',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: changePercentage >= 0 ? Colors.green : Colors.red,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Color _getSavingsRateColor(double savingsRate) {
    if (savingsRate >= 20) return Colors.green;
    if (savingsRate >= 10) return Colors.orange;
    if (savingsRate >= 0) return Colors.blue;
    return Colors.red;
  }

  double? _getIncomeChange() {
    // This would be calculated by comparing with previous period
    // For now, return null (no change indicator)
    return analytics.incomeGrowthRate != 0 ? analytics.incomeGrowthRate : null;
  }

  double? _getExpenseChange() {
    // This would be calculated by comparing with previous period
    // For now, return null (no change indicator)
    return analytics.expenseGrowthRate != 0 ? analytics.expenseGrowthRate : null;
  }
}

/// Insights and recommendations widget
class AnalyticsInsights extends StatelessWidget {
  final List<String> insights;

  const AnalyticsInsights({
    super.key,
    required this.insights,
  });

  @override
  Widget build(BuildContext context) {
    if (insights.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.lightbulb,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Financial Insights',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...insights.map((insight) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(top: 6, right: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      insight,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }
}

/// Quick stats widget for dashboard
class QuickStatsWidget extends StatelessWidget {
  final FinancialAnalytics analytics;

  const QuickStatsWidget({
    super.key,
    required this.analytics,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primary.withOpacity(0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Financial Overview',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildQuickStat(
                  context,
                  'Net Worth',
                  '${analytics.netFlow.toStringAsFixed(2)} BTCZ',
                  analytics.netFlow >= 0 ? Icons.trending_up : Icons.trending_down,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildQuickStat(
                  context,
                  'Top Category',
                  analytics.categoryBreakdown.isNotEmpty 
                      ? analytics.categoryBreakdown.first.categoryName
                      : 'None',
                  Icons.category,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildQuickStat(
                  context,
                  'Savings Rate',
                  '${analytics.savingsRate.toStringAsFixed(1)}%',
                  Icons.savings,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildQuickStat(
                  context,
                  'Transactions',
                  '${analytics.totalTransactions}',
                  Icons.receipt,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStat(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.white70, size: 16),
            const SizedBox(width: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white70,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
