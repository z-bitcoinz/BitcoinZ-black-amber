import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_selector/file_selector.dart';
import 'dart:io';
import '../../providers/wallet_provider.dart';
import '../../models/transaction_model.dart';
import '../../models/transaction_category.dart';
import '../../models/analytics_data.dart';
import '../../widgets/analytics_charts.dart';
import '../../widgets/analytics_summary_cards.dart';
import '../settings/analytics_help_screen.dart';



/// Financial analytics dashboard with comprehensive insights
class FinancialAnalyticsScreen extends StatefulWidget {
  const FinancialAnalyticsScreen({super.key});

  @override
  State<FinancialAnalyticsScreen> createState() => _FinancialAnalyticsScreenState();
}

class _FinancialAnalyticsScreenState extends State<FinancialAnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  AnalyticsPeriod _selectedPeriod = AnalyticsPeriod.threeMonths;
  bool _isLoading = true;

  // Analytics data
  FinancialAnalytics? _analytics;
  List<String> _insights = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAnalyticsData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    // Clean up temporary export files
    _cleanupTempFiles();
    super.dispose();
  }

  Future<void> _loadAnalyticsData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final walletProvider = Provider.of<WalletProvider>(context, listen: false);

      // Generate comprehensive analytics
      _analytics = await walletProvider.getFinancialAnalytics(period: _selectedPeriod);

      // Get financial insights
      _insights = await walletProvider.getFinancialInsights(period: _selectedPeriod);

    } catch (e) {
      print('Error loading analytics data: $e');
      _analytics = null;
      _insights = ['Unable to load analytics data'];
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Financial Analytics'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const AnalyticsHelpScreen(),
                ),
              );
            },
            tooltip: 'Help & Guide',
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _analytics != null ? _shareAnalytics : null,
            tooltip: 'Share Analytics',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'export_csv':
                  _exportToCSV();
                  break;
                case 'export_summary':
                  _exportSummary();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'export_csv',
                child: Row(
                  children: [
                    Icon(Icons.table_chart),
                    SizedBox(width: 8),
                    Text('Export CSV'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'export_summary',
                child: Row(
                  children: [
                    Icon(Icons.summarize),
                    SizedBox(width: 8),
                    Text('Export Summary'),
                  ],
                ),
              ),
            ],
          ),
          PopupMenuButton<AnalyticsPeriod>(
            icon: const Icon(Icons.date_range),
            onSelected: (period) {
              setState(() {
                _selectedPeriod = period;
              });
              _loadAnalyticsData();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: AnalyticsPeriod.oneMonth,
                child: Text('1 Month'),
              ),
              const PopupMenuItem(
                value: AnalyticsPeriod.threeMonths,
                child: Text('3 Months'),
              ),
              const PopupMenuItem(
                value: AnalyticsPeriod.sixMonths,
                child: Text('6 Months'),
              ),
              const PopupMenuItem(
                value: AnalyticsPeriod.oneYear,
                child: Text('1 Year'),
              ),
              const PopupMenuItem(
                value: AnalyticsPeriod.all,
                child: Text('All Time'),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.pie_chart), text: 'Overview'),
            Tab(icon: Icon(Icons.show_chart), text: 'Trends'),
            Tab(icon: Icon(Icons.category), text: 'Categories'),
            Tab(icon: Icon(Icons.compare_arrows), text: 'Flow'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _analytics == null
              ? const Center(child: Text('No analytics data available'))
              : Column(
                  children: [
                    // Period selector only (no summary cards here)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text(
                        _getPeriodDisplayName(),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),

                    // Tab content - now takes full available space
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildOverviewTab(),
                          _buildTrendsTab(),
                          _buildCategoriesTab(),
                          _buildFlowTab(),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }



  Widget _buildOverviewTab() {
    if (_analytics == null || _analytics!.categoryBreakdown.isEmpty) {
      return const Center(
        child: Text('No transactions in selected period'),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary cards - only on Overview tab
          AnalyticsSummaryCards(analytics: _analytics!),

          const SizedBox(height: 24),

          // Quick stats widget
          QuickStatsWidget(analytics: _analytics!),

          const SizedBox(height: 24),

          // Category pie chart
          CategoryPieChart(
            categories: _analytics!.categoryBreakdown,
            size: 250,
            showLegend: true,
          ),

          const SizedBox(height: 24),

          // Financial insights
          AnalyticsInsights(insights: _insights),

          // Bottom padding for better scrolling
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildTrendsTab() {
    if (_analytics == null) {
      return const Center(child: Text('No data available'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header for trends
          Text(
            'Financial Trends Analysis',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 16),

          // Monthly trends line chart
          TrendsLineChart(
            dataPoints: _analytics!.monthlyData,
            title: 'Monthly Income vs Expenses',
            showIncome: true,
            showExpenses: true,
            showNetFlow: false,
          ),

          const SizedBox(height: 32),

          // Net flow trends
          TrendsLineChart(
            dataPoints: _analytics!.monthlyData,
            title: 'Net Cash Flow Trends',
            showIncome: false,
            showExpenses: false,
            showNetFlow: true,
            lineColor: _analytics!.netFlow >= 0 ? Colors.green : Colors.red,
          ),

          const SizedBox(height: 32),

          // Growth rate indicators
          _buildGrowthIndicators(),

          // Bottom padding for better scrolling
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildCategoriesTab() {
    if (_analytics == null || _analytics!.categoryBreakdown.isEmpty) {
      return const Center(child: Text('No category data available'));
    }

    return Column(
      children: [
        // Header section
        Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Category Breakdown',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${_analytics!.categoryBreakdown.length} categories with transactions',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),

        // Scrollable category list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _analytics!.categoryBreakdown.length + 1, // +1 for bottom padding
            itemBuilder: (context, index) {
              // Bottom padding item
              if (index == _analytics!.categoryBreakdown.length) {
                return const SizedBox(height: 32);
              }

              final category = _analytics!.categoryBreakdown[index];

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Icon(
                    TransactionCategorizer.getCategoryTypeIcon(category.categoryType),
                    color: category.color,
                  ),
                  title: Text(category.categoryName),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${category.percentage.toStringAsFixed(1)}% of total'),
                      Text('${category.transactionCount} transactions'),
                    ],
                  ),
                  trailing: Text(
                    '${category.totalAmount.toStringAsFixed(2)} BTCZ',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: category.color,
                    ),
                  ),
                  onTap: () {
                    // Could navigate to detailed category view
                    _showCategoryDetails(category);
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFlowTab() {
    if (_analytics == null) {
      return const Center(child: Text('No data available'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header for flow analysis
          Text(
            'Cash Flow Analysis',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 16),

          // Income vs Expenses comparison
          ComparisonBarChart(
            data: {
              'Income': _analytics!.totalIncome,
              'Expenses': _analytics!.totalExpenses,
            },
            title: 'Income vs Expenses',
            barColor: Theme.of(context).colorScheme.primary,
          ),

          const SizedBox(height: 32),

          // Top categories comparison
          if (_analytics!.categoryBreakdown.isNotEmpty) ...[
            ComparisonBarChart(
              data: Map.fromEntries(
                _analytics!.categoryBreakdown
                    .take(5)
                    .map((cat) => MapEntry(cat.categoryName, cat.totalAmount)),
              ),
              title: 'Top 5 Categories',
              barColor: Colors.orange,
            ),

            const SizedBox(height: 32),
          ],

          // Cash flow metrics
          _buildCashFlowMetrics(),

          // Bottom padding for better scrolling
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildGrowthIndicators() {
    if (_analytics == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Growth Indicators',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildGrowthCard(
                    'Income Growth',
                    _analytics!.incomeGrowthRate,
                    Icons.trending_up,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildGrowthCard(
                    'Expense Growth',
                    _analytics!.expenseGrowthRate,
                    Icons.trending_down,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrowthCard(String title, double growthRate, IconData icon) {
    final isPositive = growthRate >= 0;
    final color = isPositive ? Colors.green : Colors.red;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            title,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${isPositive ? '+' : ''}${growthRate.toStringAsFixed(1)}%',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCashFlowMetrics() {
    if (_analytics == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cash Flow Metrics',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildMetricRow('Net Cash Flow', '${_analytics!.netFlow.toStringAsFixed(2)} BTCZ'),
            _buildMetricRow('Savings Rate', '${_analytics!.savingsRate.toStringAsFixed(1)}%'),
            _buildMetricRow('Average Transaction', '${_analytics!.averageTransactionAmount.toStringAsFixed(2)} BTCZ'),
            _buildMetricRow('Total Transactions', '${_analytics!.totalTransactions}'),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _showCategoryDetails(CategoryAnalytics category) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(category.categoryName),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total Amount: ${category.totalAmount.toStringAsFixed(2)} BTCZ'),
            Text('Percentage: ${category.percentage.toStringAsFixed(1)}%'),
            Text('Transactions: ${category.transactionCount}'),
            const SizedBox(height: 16),
            Text(
              'Recent Transactions:',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ...category.transactions.take(3).map((tx) => Text(
              '${tx.amount.toStringAsFixed(2)} BTCZ - ${DateFormat('MMM dd').format(tx.timestamp)}',
              style: Theme.of(context).textTheme.bodySmall,
            )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _getPeriodDisplayName() {
    switch (_selectedPeriod) {
      case AnalyticsPeriod.oneMonth:
        return 'Last Month';
      case AnalyticsPeriod.threeMonths:
        return 'Last 3 Months';
      case AnalyticsPeriod.sixMonths:
        return 'Last 6 Months';
      case AnalyticsPeriod.oneYear:
        return 'Last Year';
      case AnalyticsPeriod.all:
        return 'All Time';
    }
  }

  // Export and Sharing Methods

  Future<void> _shareAnalytics() async {
    if (_analytics == null) return;

    // Check if widget is still mounted before using context
    if (!mounted) return;

    try {
      // Generate quick summary for sharing
      final summary = _generateAnalyticsSummary();

      // Share as text (no file needed for quick summary)
      await Share.share(
        summary,
        subject: 'BitcoinZ Financial Analytics - ${_getPeriodDisplayName()}',
      );

      // Also copy to clipboard as backup
      Clipboard.setData(ClipboardData(text: summary));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Analytics summary shared successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // Fallback to clipboard only
      final summary = _generateAnalyticsSummary();
      Clipboard.setData(ClipboardData(text: summary));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Analytics summary copied to clipboard'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }



  /// Clean up temporary export files (called when screen is disposed)
  Future<void> _cleanupTempFiles() async {
    try {
      final directory = await getTemporaryDirectory();
      final tempFiles = directory.listSync()
          .whereType<File>()
          .where((file) => file.path.contains('bitcoinz_analytics') || file.path.contains('bitcoinz_financial_report'));

      for (final file in tempFiles) {
        try {
          await file.delete();
        } catch (e) {
          // Ignore individual file deletion errors
        }
      }
    } catch (e) {
      // Ignore cleanup errors
    }
  }

  Future<void> _exportToCSV() async {
    if (_analytics == null) return;

    // Check if widget is still mounted before using context
    if (!mounted) return;

    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text('Creating CSV file...'),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );

      // Generate CSV content
      final csv = _generateCSVData();

      // Create default file name
      final fileName = 'bitcoinz_analytics_${_getPeriodDisplayName().replaceAll(' ', '_').toLowerCase()}_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.csv';

      // macOS-specific native file save dialog
      if (Platform.isMacOS) {
        final FileSaveLocation? result = await getSaveLocation(
          suggestedName: fileName,
          acceptedTypeGroups: [
            const XTypeGroup(
              label: 'CSV files',
              extensions: ['csv'],
            ),
          ],
        );

        if (result != null) {
          // User selected a location, save the file directly
          final file = File(result.path);
          await file.writeAsString(csv);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('CSV file saved successfully!'),
                    Text(
                      'Saved to: ${result.path}',
                      style: const TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                  ],
                ),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 4),
                action: SnackBarAction(
                  label: 'Share',
                  textColor: Colors.white,
                  onPressed: () => _shareFile(result.path),
                ),
              ),
            );
          }
          return;
        } else {
          // User cancelled the save dialog, fall back to share dialog
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Save cancelled. Opening share dialog...'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
      }

      // For non-macOS platforms or if macOS save was cancelled, use share dialog
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(csv);

      // Share the file (allows user to save it anywhere)
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'BitcoinZ Financial Analytics - ${_getPeriodDisplayName()}',
        subject: 'BitcoinZ Analytics Export CSV',
      );

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('CSV file created and ready to save!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      // Show error message (check mounted again)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _exportSummary() async {
    if (_analytics == null) return;

    // Check if widget is still mounted before using context
    if (!mounted) return;

    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text('Creating financial report...'),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );

      // Generate detailed summary content
      final summary = _generateDetailedSummary();

      // Create default file name
      final fileName = 'bitcoinz_financial_report_${_getPeriodDisplayName().replaceAll(' ', '_').toLowerCase()}_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.txt';

      // macOS-specific native file save dialog
      if (Platform.isMacOS) {
        final FileSaveLocation? result = await getSaveLocation(
          suggestedName: fileName,
          acceptedTypeGroups: [
            const XTypeGroup(
              label: 'Text files',
              extensions: ['txt'],
            ),
          ],
        );

        if (result != null) {
          // User selected a location, save the file directly
          final file = File(result.path);
          await file.writeAsString(summary);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Financial report saved successfully!'),
                    Text(
                      'Saved to: ${result.path}',
                      style: const TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                  ],
                ),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 4),
                action: SnackBarAction(
                  label: 'Share',
                  textColor: Colors.white,
                  onPressed: () => _shareFile(result.path),
                ),
              ),
            );
          }
          return;
        } else {
          // User cancelled the save dialog, fall back to share dialog
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Save cancelled. Opening share dialog...'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
      }

      // For non-macOS platforms or if macOS save was cancelled, use share dialog
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(summary);

      // Share the file (allows user to save it anywhere)
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'BitcoinZ Detailed Financial Report - ${_getPeriodDisplayName()}',
        subject: 'BitcoinZ Financial Report',
      );

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Financial report created and ready to save!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      // Show error message (check mounted again)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  // Helper function to share an already saved file
  Future<void> _shareFile(String filePath) async {
    try {
      await Share.shareXFiles(
        [XFile(filePath)],
        text: 'BitcoinZ Analytics Export',
        subject: 'BitcoinZ Analytics Export',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Share failed: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  String _generateAnalyticsSummary() {
    if (_analytics == null) return '';

    final buffer = StringBuffer();
    buffer.writeln('BitcoinZ Wallet - Financial Analytics');
    buffer.writeln('Period: ${_getPeriodDisplayName()}');
    buffer.writeln('Generated: ${DateFormat('MMM dd, yyyy HH:mm').format(DateTime.now())}');
    buffer.writeln('');
    buffer.writeln('📊 SUMMARY');
    buffer.writeln('Total Income: ${_analytics!.totalIncome.toStringAsFixed(2)} BTCZ');
    buffer.writeln('Total Expenses: ${_analytics!.totalExpenses.toStringAsFixed(2)} BTCZ');
    buffer.writeln('Net Flow: ${_analytics!.netFlow.toStringAsFixed(2)} BTCZ');
    buffer.writeln('Savings Rate: ${_analytics!.savingsRate.toStringAsFixed(1)}%');
    buffer.writeln('Total Transactions: ${_analytics!.totalTransactions}');
    buffer.writeln('');
    buffer.writeln('📈 TOP CATEGORIES');
    for (int i = 0; i < _analytics!.categoryBreakdown.length && i < 5; i++) {
      final category = _analytics!.categoryBreakdown[i];
      buffer.writeln('${i + 1}. ${category.categoryName}: ${category.totalAmount.toStringAsFixed(2)} BTCZ (${category.percentage.toStringAsFixed(1)}%)');
    }
    buffer.writeln('');
    buffer.writeln('💡 INSIGHTS');
    for (final insight in _insights) {
      buffer.writeln('• $insight');
    }

    return buffer.toString();
  }

  String _generateCSVData() {
    if (_analytics == null) return '';

    final buffer = StringBuffer();

    // File header with metadata
    buffer.writeln('BitcoinZ Wallet - Financial Analytics Export');
    buffer.writeln('Generated: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}');
    buffer.writeln('Period: ${_getPeriodDisplayName()}');
    buffer.writeln('Analysis Period: ${DateFormat('yyyy-MM-dd').format(_analytics!.startDate)} to ${DateFormat('yyyy-MM-dd').format(_analytics!.endDate)}');
    buffer.writeln('');

    // Summary section
    buffer.writeln('SUMMARY');
    buffer.writeln('Metric,Value,Unit');
    buffer.writeln('Total Income,${_analytics!.totalIncome.toStringAsFixed(2)},BTCZ');
    buffer.writeln('Total Expenses,${_analytics!.totalExpenses.toStringAsFixed(2)},BTCZ');
    buffer.writeln('Net Flow,${_analytics!.netFlow.toStringAsFixed(2)},BTCZ');
    buffer.writeln('Savings Rate,${_analytics!.savingsRate.toStringAsFixed(1)},%');
    buffer.writeln('Average Transaction,${_analytics!.averageTransactionAmount.toStringAsFixed(2)},BTCZ');
    buffer.writeln('Total Transactions,${_analytics!.totalTransactions},Count');
    buffer.writeln('Income Growth Rate,${_analytics!.incomeGrowthRate.toStringAsFixed(1)},%');
    buffer.writeln('Expense Growth Rate,${_analytics!.expenseGrowthRate.toStringAsFixed(1)},%');
    buffer.writeln('');

    // Category breakdown
    buffer.writeln('CATEGORY BREAKDOWN');
    buffer.writeln('Category Name,Amount (BTCZ),Percentage (%),Transaction Count,Category Type');
    for (final category in _analytics!.categoryBreakdown) {
      buffer.writeln('${category.categoryName},${category.totalAmount.toStringAsFixed(2)},${category.percentage.toStringAsFixed(2)},${category.transactionCount},${category.categoryType.toString().split('.').last}');
    }

    buffer.writeln('');
    buffer.writeln('MONTHLY TRENDS');
    buffer.writeln('Month,Income (BTCZ),Expenses (BTCZ),Net Flow (BTCZ),Transaction Count,Savings Rate (%)');

    // Monthly data with calculated savings rate
    for (final dataPoint in _analytics!.monthlyData) {
      final savingsRate = dataPoint.income > 0 ? ((dataPoint.income - dataPoint.expenses) / dataPoint.income * 100) : 0.0;
      buffer.writeln('${DateFormat('yyyy-MM').format(dataPoint.date)},${dataPoint.income.toStringAsFixed(2)},${dataPoint.expenses.toStringAsFixed(2)},${dataPoint.netFlow.toStringAsFixed(2)},${dataPoint.transactionCount},${savingsRate.toStringAsFixed(1)}');
    }

    return buffer.toString();
  }

  String _generateDetailedSummary() {
    if (_analytics == null) return '';

    final buffer = StringBuffer();
    buffer.writeln('BitcoinZ Wallet - Detailed Financial Report');
    buffer.writeln('=' * 50);
    buffer.writeln('Period: ${_getPeriodDisplayName()}');
    buffer.writeln('Analysis Date: ${DateFormat('MMMM dd, yyyy').format(DateTime.now())}');
    buffer.writeln('Report Period: ${DateFormat('MMM dd, yyyy').format(_analytics!.startDate)} - ${DateFormat('MMM dd, yyyy').format(_analytics!.endDate)}');
    buffer.writeln('');

    buffer.writeln('EXECUTIVE SUMMARY');
    buffer.writeln('-' * 20);
    buffer.writeln('Total Income: ${_analytics!.totalIncome.toStringAsFixed(2)} BTCZ');
    buffer.writeln('Total Expenses: ${_analytics!.totalExpenses.toStringAsFixed(2)} BTCZ');
    buffer.writeln('Net Cash Flow: ${_analytics!.netFlow.toStringAsFixed(2)} BTCZ');
    buffer.writeln('Savings Rate: ${_analytics!.savingsRate.toStringAsFixed(1)}%');
    buffer.writeln('Average Transaction: ${_analytics!.averageTransactionAmount.toStringAsFixed(2)} BTCZ');
    buffer.writeln('Total Transactions: ${_analytics!.totalTransactions}');
    buffer.writeln('');

    buffer.writeln('GROWTH ANALYSIS');
    buffer.writeln('-' * 20);
    buffer.writeln('Income Growth Rate: ${_analytics!.incomeGrowthRate.toStringAsFixed(1)}%');
    buffer.writeln('Expense Growth Rate: ${_analytics!.expenseGrowthRate.toStringAsFixed(1)}%');
    buffer.writeln('');

    buffer.writeln('CATEGORY BREAKDOWN');
    buffer.writeln('-' * 20);
    for (int i = 0; i < _analytics!.categoryBreakdown.length; i++) {
      final category = _analytics!.categoryBreakdown[i];
      buffer.writeln('${i + 1}. ${category.categoryName}');
      buffer.writeln('   Amount: ${category.totalAmount.toStringAsFixed(2)} BTCZ');
      buffer.writeln('   Percentage: ${category.percentage.toStringAsFixed(1)}%');
      buffer.writeln('   Transactions: ${category.transactionCount}');
      buffer.writeln('');
    }

    buffer.writeln('FINANCIAL INSIGHTS');
    buffer.writeln('-' * 20);
    for (final insight in _insights) {
      buffer.writeln('• $insight');
    }
    buffer.writeln('');

    buffer.writeln('MONTHLY TRENDS');
    buffer.writeln('-' * 20);
    for (final dataPoint in _analytics!.monthlyData) {
      buffer.writeln('${DateFormat('MMMM yyyy').format(dataPoint.date)}:');
      buffer.writeln('  Income: ${dataPoint.income.toStringAsFixed(2)} BTCZ');
      buffer.writeln('  Expenses: ${dataPoint.expenses.toStringAsFixed(2)} BTCZ');
      buffer.writeln('  Net Flow: ${dataPoint.netFlow.toStringAsFixed(2)} BTCZ');
      buffer.writeln('  Transactions: ${dataPoint.transactionCount}');
      buffer.writeln('');
    }

    return buffer.toString();
  }
}
