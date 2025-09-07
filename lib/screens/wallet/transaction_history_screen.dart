import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/currency_provider.dart';
import '../../models/transaction.dart';
import '../../utils/responsive.dart';

import '../../utils/formatters.dart';
class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  final _searchController = TextEditingController();
  String _searchQuery = '';
  TransactionFilter _currentFilter = TransactionFilter.all;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshTransactions() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
    });

    try {
      final walletProvider = Provider.of<WalletProvider>(context, listen: false);
      await walletProvider.refreshTransactions();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to refresh transactions: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  List<Transaction> _filterTransactions(List<Transaction> transactions) {
    var filtered = transactions;

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((tx) {
        final query = _searchQuery.toLowerCase();
        return tx.txid.toLowerCase().contains(query) ||
               tx.toAddress?.toLowerCase().contains(query) == true ||
               tx.fromAddress?.toLowerCase().contains(query) == true ||
               tx.memo?.toLowerCase().contains(query) == true;
      }).toList();
    }

    // Apply type filter
    switch (_currentFilter) {
      case TransactionFilter.received:
        filtered = filtered.where((tx) => tx.type == TransactionType.received).toList();
        break;
      case TransactionFilter.sent:
        filtered = filtered.where((tx) => tx.type == TransactionType.sent).toList();
        break;
      case TransactionFilter.confirming:
        filtered = filtered.where((tx) => tx.status == TransactionStatus.confirming).toList();
        break;
      case TransactionFilter.all:
        break;
    }

    return filtered;
  }

  void _showTransactionDetails(Transaction transaction) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TransactionDetailSheet(transaction: transaction),
    );
  }

  void _copyToClipboard(String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.lightImpact();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction History'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: _isRefreshing
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  )
                : const Icon(Icons.refresh),
            onPressed: _refreshTransactions,
            tooltip: 'Refresh Transactions',
          ),
        ],
      ),
      body: SafeArea(
        child: Consumer<WalletProvider>(
          builder: (context, walletProvider, child) {
            final allTransactions = walletProvider.transactions;
            final filteredTransactions = _filterTransactions(allTransactions.map((tx) => tx.toTransaction()).toList());

            return Padding(
              padding: ResponsiveUtils.getScreenPadding(context),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  children: [
                    // Search Bar
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: ResponsiveUtils.getHorizontalPadding(context) * 0.75,
                        vertical: ResponsiveUtils.isSmallScreen(context) ? 8 : 12,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(ResponsiveUtils.getCardBorderRadius(context)),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.search,
                            color: Theme.of(context).colorScheme.outline,
                            size: ResponsiveUtils.getIconSize(context, base: 20),
                          ),
                          SizedBox(width: ResponsiveUtils.isSmallMobile(context) ? 8 : 12),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText: 'Search transactions...',
                                border: InputBorder.none,
                                hintStyle: TextStyle(
                                  color: Theme.of(context).colorScheme.outline.withOpacity(0.6),
                                  fontSize: ResponsiveUtils.getBodyTextSize(context),
                                ),
                              ),
                              style: TextStyle(
                                fontSize: ResponsiveUtils.getBodyTextSize(context),
                              ),
                              onChanged: (value) {
                                setState(() {
                                  _searchQuery = value;
                                });
                              },
                            ),
                          ),
                          if (_searchQuery.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                });
                              },
                              child: Icon(
                                Icons.clear,
                                color: Theme.of(context).colorScheme.outline,
                                size: ResponsiveUtils.getIconSize(context, base: 18),
                              ),
                            ),
                        ],
                      ),
                    ),

                    SizedBox(height: ResponsiveUtils.isSmallScreen(context) ? 16 : 20),

                    // Filter Tabs
                    Container(
                      height: ResponsiveUtils.isSmallScreen(context) ? 48 : 56,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(ResponsiveUtils.getCardBorderRadius(context)),
                      ),
                      child: Row(
                        children: TransactionFilter.values.map((filter) {
                          final isSelected = _currentFilter == filter;
                          return Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _currentFilter = filter;
                                });
                              },
                              child: Container(
                                margin: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.primary
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(ResponsiveUtils.getCardBorderRadius(context) * 0.75),
                                ),
                                child: Center(
                                  child: Text(
                                    filter.displayName,
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.white
                                          : Theme.of(context).colorScheme.onSurface,
                                      fontSize: ResponsiveUtils.getBodyTextSize(context) * 0.9,
                                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    SizedBox(height: ResponsiveUtils.isSmallScreen(context) ? 16 : 20),

                    // Transaction List
                    Expanded(
                      child: filteredTransactions.isEmpty
                          ? _buildEmptyState()
                          : RefreshIndicator(
                              onRefresh: _refreshTransactions,
                              child: ListView.separated(
                                itemCount: filteredTransactions.length,
                                separatorBuilder: (context, index) => SizedBox(
                                  height: ResponsiveUtils.isSmallScreen(context) ? 8 : 12,
                                ),
                                itemBuilder: (context, index) {
                                  final transaction = filteredTransactions[index];
                                  return _buildTransactionTile(transaction);
                                },
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    String message = 'No transactions found';
    IconData icon = Icons.receipt_long_outlined;

    switch (_currentFilter) {
      case TransactionFilter.received:
        message = 'No received transactions';
        icon = Icons.call_received;
        break;
      case TransactionFilter.sent:
        message = 'No sent transactions';
        icon = Icons.call_made;
        break;
      case TransactionFilter.confirming:
        message = 'No confirming transactions';
        icon = Icons.pending_outlined;
        break;
      case TransactionFilter.all:
        if (_searchQuery.isNotEmpty) {
          message = 'No transactions match your search';
          icon = Icons.search_off;
        }
        break;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: ResponsiveUtils.getIconSize(context, base: 64),
            color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
          ),
          SizedBox(height: ResponsiveUtils.isSmallScreen(context) ? 16 : 24),
          Text(
            message,
            style: TextStyle(
              fontSize: ResponsiveUtils.getTitleTextSize(context),
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          if (_searchQuery.isNotEmpty) ...[
            SizedBox(height: ResponsiveUtils.isSmallScreen(context) ? 8 : 12),
            TextButton(
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _searchQuery = '';
                });
              },
              child: const Text('Clear search'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTransactionTile(Transaction transaction) {
    final isReceived = transaction.type == TransactionType.received;
    final amount = transaction.amount.abs();
    final formattedAmount = '${isReceived ? '+' : '-'}${Formatters.formatBtczTrim(amount, showSymbol: false)} BTCZ';

    Color statusColor;
    IconData statusIcon;

    switch (transaction.status) {
      case TransactionStatus.confirmed:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case TransactionStatus.confirming:
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
        break;
      case TransactionStatus.failed:
        statusColor = Colors.red;
        statusIcon = Icons.error;
        break;
    }

    return GestureDetector(
      onTap: () => _showTransactionDetails(transaction),
      child: Container(
        padding: EdgeInsets.all(ResponsiveUtils.getHorizontalPadding(context)),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(ResponsiveUtils.getCardBorderRadius(context)),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                // Transaction Type Icon
                Container(
                  width: ResponsiveUtils.getIconSize(context, base: 40),
                  height: ResponsiveUtils.getIconSize(context, base: 40),
                  decoration: BoxDecoration(
                    color: (isReceived ? Colors.green : Colors.blue).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isReceived ? Icons.call_received : Icons.call_made,
                    color: isReceived ? Colors.green : Colors.blue,
                    size: ResponsiveUtils.getIconSize(context, base: 20),
                  ),
                ),

                SizedBox(width: ResponsiveUtils.isSmallMobile(context) ? 12 : 16),

                // Transaction Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isReceived ? 'Received' : 'Sent',
                            style: TextStyle(
                              fontSize: ResponsiveUtils.getBodyTextSize(context),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Consumer<CurrencyProvider>(
                            builder: (context, currencyProvider, _) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    formattedAmount,
                                    style: TextStyle(
                                      fontSize: ResponsiveUtils.getBodyTextSize(context),
                                      fontWeight: FontWeight.bold,
                                      color: isReceived ? Colors.green : Colors.red,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                  // Show fiat amount if price available
                                  if (currencyProvider.currentPrice != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      currencyProvider.formatFiatAmount(amount),
                                      style: TextStyle(
                                        fontSize: ResponsiveUtils.getBodyTextSize(context) * 0.75,
                                        color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ],
                              );
                            },
                          ),
                        ],
                      ),

                      SizedBox(height: ResponsiveUtils.isSmallScreen(context) ? 4 : 6),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              DateFormat('MMM dd, yyyy • HH:mm').format(transaction.timestamp),
                              style: TextStyle(
                                fontSize: ResponsiveUtils.getBodyTextSize(context) * 0.85,
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              Icon(
                                statusIcon,
                                color: statusColor,
                                size: ResponsiveUtils.getIconSize(context, base: 14),
                              ),
                              SizedBox(width: ResponsiveUtils.isSmallMobile(context) ? 4 : 6),
                              Text(
                                transaction.status.displayName,
                                style: TextStyle(
                                  fontSize: ResponsiveUtils.getBodyTextSize(context) * 0.85,
                                  color: statusColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Memo preview for shielded transactions
            if (transaction.memo != null && transaction.memo!.isNotEmpty) ...[
              SizedBox(height: ResponsiveUtils.isSmallScreen(context) ? 8 : 12),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(ResponsiveUtils.getHorizontalPadding(context) * 0.75),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(ResponsiveUtils.getCardBorderRadius(context) * 0.5),
                ),
                child: Text(
                  transaction.memo!.length > 50
                      ? '${transaction.memo!.substring(0, 50)}...'
                      : transaction.memo!,
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getBodyTextSize(context) * 0.85,
                    color: Theme.of(context).colorScheme.primary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Transaction Detail Sheet
class TransactionDetailSheet extends StatelessWidget {
  final Transaction transaction;

  const TransactionDetailSheet({
    super.key,
    required this.transaction,
  });

  void _copyToClipboard(BuildContext context, String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.lightImpact();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isReceived = transaction.type == TransactionType.received;
    final amount = transaction.amount.abs();

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.background,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(ResponsiveUtils.getCardBorderRadius(context)),
        ),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            margin: EdgeInsets.symmetric(vertical: ResponsiveUtils.isSmallScreen(context) ? 8 : 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: ResponsiveUtils.getScreenPadding(context),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Transaction Details',
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getTitleTextSize(context),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: ResponsiveUtils.getScreenPadding(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Amount and Status
                  Center(
                    child: Column(
                      children: [
                        Text(
                          '${isReceived ? '+' : '-'}${Formatters.formatBtczTrim(amount, showSymbol: false)}',
                          style: TextStyle(
                            fontSize: ResponsiveUtils.getTitleTextSize(context) * 1.5,
                            fontWeight: FontWeight.bold,
                            color: isReceived ? Colors.green : Colors.red,
                            fontFamily: 'monospace',
                          ),
                        ),
                        SizedBox(height: ResponsiveUtils.isSmallScreen(context) ? 4 : 8),
                        Text(
                          'BTCZ',
                          style: TextStyle(
                            fontSize: ResponsiveUtils.getBodyTextSize(context),
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: ResponsiveUtils.isSmallScreen(context) ? 24 : 32),

                  // Transaction Info
                  _buildDetailRow(context, 'Type', isReceived ? 'Received' : 'Sent'),
                  _buildDetailRow(context, 'Status', transaction.status.displayName),
                  _buildDetailRow(context, 'Date', DateFormat('MMM dd, yyyy').format(transaction.timestamp)),
                  _buildDetailRow(context, 'Time', DateFormat('HH:mm:ss').format(transaction.timestamp)),
                  _buildDetailRow(context, 'Confirmations', '${transaction.confirmations}'),

                  if (transaction.fee != null && transaction.fee! > 0)
                    _buildDetailRow(context, 'Network Fee', '${Formatters.formatBtczTrim(transaction.fee!, showSymbol: false)} BTCZ'),

                  // Transaction ID
                  SizedBox(height: ResponsiveUtils.isSmallScreen(context) ? 16 : 24),
                  Text(
                    'Transaction ID',
                    style: TextStyle(
                      fontSize: ResponsiveUtils.getBodyTextSize(context),
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  SizedBox(height: ResponsiveUtils.isSmallScreen(context) ? 8 : 12),
                  GestureDetector(
                    onTap: () => _copyToClipboard(context, transaction.txid, 'Transaction ID copied'),
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(ResponsiveUtils.getHorizontalPadding(context) * 0.75),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(ResponsiveUtils.getCardBorderRadius(context) * 0.75),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              transaction.txid,
                              style: TextStyle(
                                fontSize: ResponsiveUtils.getBodyTextSize(context) * 0.9,
                                fontFamily: 'monospace',
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(width: ResponsiveUtils.isSmallMobile(context) ? 8 : 12),
                          Icon(
                            Icons.copy,
                            size: ResponsiveUtils.getIconSize(context, base: 16),
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Addresses
                  if (transaction.fromAddress != null) ...[
                    SizedBox(height: ResponsiveUtils.isSmallScreen(context) ? 16 : 24),
                    Text(
                      'From Address',
                      style: TextStyle(
                        fontSize: ResponsiveUtils.getBodyTextSize(context),
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    SizedBox(height: ResponsiveUtils.isSmallScreen(context) ? 8 : 12),
                    GestureDetector(
                      onTap: () => _copyToClipboard(context, transaction.fromAddress!, 'From address copied'),
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(ResponsiveUtils.getHorizontalPadding(context) * 0.75),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(ResponsiveUtils.getCardBorderRadius(context) * 0.75),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                          ),
                        ),
                        child: Text(
                          transaction.fromAddress!,
                          style: TextStyle(
                            fontSize: ResponsiveUtils.getBodyTextSize(context) * 0.9,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ),
                  ],

                  if (transaction.toAddress != null) ...[
                    SizedBox(height: ResponsiveUtils.isSmallScreen(context) ? 16 : 24),
                    Text(
                      'To Address',
                      style: TextStyle(
                        fontSize: ResponsiveUtils.getBodyTextSize(context),
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    SizedBox(height: ResponsiveUtils.isSmallScreen(context) ? 8 : 12),
                    GestureDetector(
                      onTap: () => _copyToClipboard(context, transaction.toAddress!, 'To address copied'),
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(ResponsiveUtils.getHorizontalPadding(context) * 0.75),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(ResponsiveUtils.getCardBorderRadius(context) * 0.75),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                          ),
                        ),
                        child: Text(
                          transaction.toAddress!,
                          style: TextStyle(
                            fontSize: ResponsiveUtils.getBodyTextSize(context) * 0.9,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ),
                  ],

                  // Memo
                  if (transaction.memo != null && transaction.memo!.isNotEmpty) ...[
                    SizedBox(height: ResponsiveUtils.isSmallScreen(context) ? 16 : 24),
                    Text(
                      'Memo',
                      style: TextStyle(
                        fontSize: ResponsiveUtils.getBodyTextSize(context),
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    SizedBox(height: ResponsiveUtils.isSmallScreen(context) ? 8 : 12),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(ResponsiveUtils.getHorizontalPadding(context) * 0.75),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(ResponsiveUtils.getCardBorderRadius(context) * 0.75),
                      ),
                      child: Text(
                        transaction.memo!,
                        style: TextStyle(
                          fontSize: ResponsiveUtils.getBodyTextSize(context),
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ],

                  SizedBox(height: ResponsiveUtils.getVerticalPadding(context)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: ResponsiveUtils.isSmallScreen(context) ? 8 : 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: ResponsiveUtils.getBodyTextSize(context),
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: ResponsiveUtils.getBodyTextSize(context),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}