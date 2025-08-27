import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/wallet_provider.dart';
import '../../models/address_label.dart';
import '../../models/transaction_model.dart';
import '../../models/analytics_data.dart';
import '../../widgets/analytics_charts.dart';
import '../../widgets/address_label_dialog.dart';
import '../settings/analytics_help_screen.dart';
import 'external_address_suggestions_screen.dart';

/// Address monitoring and analytics screen
class AddressMonitoringScreen extends StatefulWidget {
  const AddressMonitoringScreen({super.key});

  @override
  State<AddressMonitoringScreen> createState() => _AddressMonitoringScreenState();
}

class _AddressMonitoringScreenState extends State<AddressMonitoringScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  
  List<AddressLabel> _labeledAddresses = [];
  Map<String, List<TransactionModel>> _addressTransactions = {};
  Map<String, AnalyticsDataPoint> _addressAnalytics = {};
  AddressLabelCategory? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAddressData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAddressData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final walletProvider = Provider.of<WalletProvider>(context, listen: false);
      
      // Get all labeled addresses
      _labeledAddresses = await walletProvider.getAllAddressLabels(
        category: _selectedCategory,
        activeOnly: true,
      );
      
      // Get transactions for each labeled address
      _addressTransactions.clear();
      _addressAnalytics.clear();
      
      for (final label in _labeledAddresses) {
        final transactions = walletProvider.transactions
            .where((tx) =>
                tx.fromAddress == label.address ||
                tx.toAddress == label.address)
            .toList();
        
        _addressTransactions[label.address] = transactions;
        
        // Calculate analytics for this address
        double income = 0;
        double expenses = 0;
        
        for (final tx in transactions) {
          if (tx.isReceived && tx.toAddress == label.address) {
            income += tx.amount.abs();
          } else if (!tx.isReceived && tx.fromAddress == label.address) {
            expenses += tx.amount.abs();
          }
        }
        
        _addressAnalytics[label.address] = AnalyticsDataPoint(
          date: DateTime.now(),
          income: income,
          expenses: expenses,
          netFlow: income - expenses,
          transactionCount: transactions.length,
        );
      }
      
    } catch (e) {
      print('Error loading address data: $e');
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Address Monitoring'),
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
            icon: const Icon(Icons.auto_fix_high),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const ExternalAddressSuggestionsScreen(),
                ),
              ).then((_) => _loadAddressData()); // Reload data when returning
            },
            tooltip: 'Auto-suggest labels',
          ),
          PopupMenuButton<AddressLabelCategory?>(
            icon: const Icon(Icons.filter_list),
            onSelected: (category) {
              setState(() {
                _selectedCategory = category;
              });
              _loadAddressData();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: null,
                child: Text('All Categories'),
              ),
              ...AddressLabelCategory.values.map((category) => PopupMenuItem(
                value: category,
                child: Text(AddressLabelManager.getCategoryDisplayName(category)),
              )),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddLabelDialog,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.list), text: 'Addresses'),
            Tab(icon: Icon(Icons.analytics), text: 'Analytics'),
            Tab(icon: Icon(Icons.timeline), text: 'Activity'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildAddressesTab(),
                _buildAnalyticsTab(),
                _buildActivityTab(),
              ],
            ),
    );
  }

  Widget _buildAddressesTab() {
    if (_labeledAddresses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.label_off,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No labeled addresses',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Add labels to your addresses to start monitoring',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _showAddLabelDialog,
              icon: const Icon(Icons.add),
              label: const Text('Add Address Label'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _labeledAddresses.length,
      itemBuilder: (context, index) {
        final label = _labeledAddresses[index];
        final analytics = _addressAnalytics[label.address];
        final transactionCount = _addressTransactions[label.address]?.length ?? 0;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Color(int.parse(label.color.replaceFirst('#', '0xFF'))),
              child: Icon(
                AddressLabelManager.getIcon(label.type),
                color: Colors.white,
                size: 20,
              ),
            ),
            title: Text(label.labelName),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${label.address.substring(0, 12)}...${label.address.substring(label.address.length - 8)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      label.isOwned ? Icons.account_balance_wallet : Icons.swap_horiz,
                      size: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      label.isOwned ? 'Own Address' : 'External Address',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      Icons.receipt,
                      size: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$transactionCount transactions',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
            trailing: analytics != null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${analytics.netFlow.toStringAsFixed(2)} BTCZ',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: analytics.netFlow >= 0 ? Colors.green : Colors.red,
                        ),
                      ),
                      Text(
                        'Net Flow',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  )
                : null,
            onTap: () => _showAddressDetails(label),
          ),
        );
      },
    );
  }

  Widget _buildAnalyticsTab() {
    if (_labeledAddresses.isEmpty) {
      return const Center(
        child: Text('No labeled addresses to analyze'),
      );
    }

    // Aggregate data by category
    final Map<AddressLabelCategory, double> categoryTotals = {};
    final Map<AddressLabelCategory, int> categoryTransactionCounts = {};
    
    for (final label in _labeledAddresses) {
      final analytics = _addressAnalytics[label.address];
      if (analytics != null) {
        categoryTotals[label.category] = 
            (categoryTotals[label.category] ?? 0) + analytics.netFlow.abs();
        categoryTransactionCounts[label.category] = 
            (categoryTransactionCounts[label.category] ?? 0) + analytics.transactionCount;
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category breakdown
          Text(
            'Activity by Category',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          ComparisonBarChart(
            data: categoryTotals.map((key, value) => MapEntry(
              AddressLabelManager.getCategoryDisplayName(key),
              value,
            )),
            title: 'Total Activity by Category',
            barColor: Theme.of(context).colorScheme.primary,
          ),
          
          const SizedBox(height: 32),
          
          // Top performing addresses
          Text(
            'Top Active Addresses',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          ..._getTopAddresses().map((label) {
            final analytics = _addressAnalytics[label.address]!;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Color(int.parse(label.color.replaceFirst('#', '0xFF'))),
                  child: Icon(
                    AddressLabelManager.getIcon(label.type),
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                title: Text(label.labelName),
                subtitle: Text('${analytics.transactionCount} transactions'),
                trailing: Text(
                  '${analytics.netFlow.toStringAsFixed(2)} BTCZ',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: analytics.netFlow >= 0 ? Colors.green : Colors.red,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildActivityTab() {
    if (_labeledAddresses.isEmpty) {
      return const Center(
        child: Text('No labeled addresses to show activity'),
      );
    }

    // Get recent transactions from all labeled addresses
    final List<MapEntry<AddressLabel, TransactionModel>> recentActivity = [];
    
    for (final label in _labeledAddresses) {
      final transactions = _addressTransactions[label.address] ?? [];
      for (final tx in transactions) {
        recentActivity.add(MapEntry(label, tx));
      }
    }
    
    // Sort by timestamp (most recent first)
    recentActivity.sort((a, b) => b.value.timestamp.compareTo(a.value.timestamp));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: recentActivity.length,
      itemBuilder: (context, index) {
        final entry = recentActivity[index];
        final label = entry.key;
        final transaction = entry.value;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Color(int.parse(label.color.replaceFirst('#', '0xFF'))),
              child: Icon(
                transaction.isReceived ? Icons.arrow_downward : Icons.arrow_upward,
                color: Colors.white,
                size: 16,
              ),
            ),
            title: Text(label.labelName),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(DateFormat('MMM dd, yyyy HH:mm').format(transaction.timestamp)),
                if (transaction.memo?.isNotEmpty == true)
                  Text(
                    transaction.memo!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
            trailing: Text(
              '${transaction.isReceived ? '+' : '-'}${transaction.amount.abs().toStringAsFixed(2)} BTCZ',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: transaction.isReceived ? Colors.green : Colors.red,
              ),
            ),
          ),
        );
      },
    );
  }

  List<AddressLabel> _getTopAddresses() {
    final sortedLabels = List<AddressLabel>.from(_labeledAddresses);
    sortedLabels.sort((a, b) {
      final analyticsA = _addressAnalytics[a.address];
      final analyticsB = _addressAnalytics[b.address];
      
      if (analyticsA == null && analyticsB == null) return 0;
      if (analyticsA == null) return 1;
      if (analyticsB == null) return -1;
      
      return analyticsB.transactionCount.compareTo(analyticsA.transactionCount);
    });
    
    return sortedLabels.take(5).toList();
  }

  void _showAddressDetails(AddressLabel label) {
    final analytics = _addressAnalytics[label.address];
    final transactions = _addressTransactions[label.address] ?? [];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(label.labelName),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Address: ${label.address}'),
              const SizedBox(height: 8),
              Text('Category: ${AddressLabelManager.getCategoryDisplayName(label.category)}'),
              Text('Type: ${AddressLabelManager.getDisplayName(label.type)}'),
              if (label.description?.isNotEmpty == true) ...[
                const SizedBox(height: 8),
                Text('Description: ${label.description}'),
              ],
              if (analytics != null) ...[
                const SizedBox(height: 16),
                Text(
                  'Analytics:',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text('Income: ${analytics.income.toStringAsFixed(2)} BTCZ'),
                Text('Expenses: ${analytics.expenses.toStringAsFixed(2)} BTCZ'),
                Text('Net Flow: ${analytics.netFlow.toStringAsFixed(2)} BTCZ'),
                Text('Transactions: ${analytics.transactionCount}'),
              ],
              if (transactions.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Recent Transactions:',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ...transactions.take(3).map((tx) => Text(
                  '${tx.isReceived ? '+' : '-'}${tx.amount.abs().toStringAsFixed(2)} BTCZ - ${DateFormat('MMM dd').format(tx.timestamp)}',
                  style: Theme.of(context).textTheme.bodySmall,
                )),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showEditLabelDialog(label);
            },
            child: const Text('Edit'),
          ),
        ],
      ),
    );
  }

  void _showAddLabelDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => const AddressLabelDialog(),
    );

    if (result == true) {
      // Reload data if label was added successfully
      _loadAddressData();
    }
  }

  void _showEditLabelDialog(AddressLabel label) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AddressLabelDialog(existingLabel: label),
    );

    if (result == true) {
      // Reload data if label was updated/deleted successfully
      _loadAddressData();
    }
  }
}
