import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/wallet_provider.dart';
import '../../models/transaction_model.dart';
import '../../utils/responsive.dart';
// import '../../services/btcz_cli_service.dart'; // Removed - CLI no longer used

enum TransactionFilter { all, sent, received, confirming }

class PaginatedTransactionHistoryScreen extends StatefulWidget {
  const PaginatedTransactionHistoryScreen({super.key});

  @override
  State<PaginatedTransactionHistoryScreen> createState() => _PaginatedTransactionHistoryScreenState();
}

class _PaginatedTransactionHistoryScreenState extends State<PaginatedTransactionHistoryScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  
  String _searchQuery = '';
  TransactionFilter _currentFilter = TransactionFilter.all;
  bool _isRefreshing = false;
  Map<String, int> _transactionStats = {};
  
  // Block height caching
  int? _cachedBlockHeight;
  DateTime? _blockHeightCacheTime;
  final Duration _blockHeightCacheDuration = const Duration(seconds: 30);
  // final BtczCliService _cliService = BtczCliService(); // Removed - CLI no longer used

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
    
    // Setup scroll listener for pagination
    _scrollController.addListener(_onScroll);
    
    // Load initial data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200) {
      // Load more when near the bottom
      final walletProvider = Provider.of<WalletProvider>(context, listen: false);
      if (walletProvider.hasMoreTransactions && !walletProvider.isLoadingMore) {
        walletProvider.loadMoreTransactions();
      }
    }
  }

  Future<void> _loadInitialData() async {
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    
    // Load transaction stats
    _transactionStats = await walletProvider.getTransactionStats();
    
    // Don't call loadTransactionsPage - use BitcoinZ Blue approach
    // Transactions are already loaded by BitcoinZ Blue RPC system
    if (kDebugMode) print('📄 Using BitcoinZ Blue approach - transactions already loaded via RPC');
    
    if (mounted) setState(() {});
  }

  Future<void> _refreshTransactions() async {
    if (_isRefreshing) return;
    
    setState(() {
      _isRefreshing = true;
    });

    try {
      final walletProvider = Provider.of<WalletProvider>(context, listen: false);
      
      // BitcoinZ Blue approach: Let RPC system handle refresh automatically
      // Just refresh stats, don't interfere with live transaction data
      _transactionStats = await walletProvider.getTransactionStats();
      
      if (kDebugMode) print('📄 Transaction refresh completed (BitcoinZ Blue RPC handles live updates)');
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to refresh transaction stats: $e'),
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

  void _onSearchChanged(String query) {
    if (_searchQuery != query) {
      setState(() {
        _searchQuery = query;
      });
      
      // BitcoinZ Blue approach: Just update local filter, no database calls
      if (kDebugMode) print('📄 Search query updated: "$query" (filtering locally)');
      
      // The build method will filter transactions locally based on _searchQuery
      // No need for database calls - much faster and simpler
    }
  }

  void _onFilterChanged(TransactionFilter filter) {
    if (_currentFilter != filter) {
      setState(() {
        _currentFilter = filter;
      });
      
      // BitcoinZ Blue approach: Just update local filter, no database calls
      if (kDebugMode) print('📄 Filter changed to: $filter (filtering locally)');
      
      // The build method will filter transactions locally based on _currentFilter
      // No need for database calls - much faster and simpler
    }
  }

  /// Get current block height with caching
  Future<int?> _getCurrentBlockHeight() async {
    final now = DateTime.now();
    
    // Return cached value if still valid
    if (_cachedBlockHeight != null && 
        _blockHeightCacheTime != null && 
        now.difference(_blockHeightCacheTime!).compareTo(_blockHeightCacheDuration) < 0) {
      return _cachedBlockHeight;
    }
    
    // Fetch new block height
    try {
      // CLI service removed - return null for now
      final int? blockHeight = null; // await _cliService.getCurrentBlockHeight();
      if (blockHeight != null) {
        _cachedBlockHeight = blockHeight;
        _blockHeightCacheTime = now;
      }
      return blockHeight;
    } catch (e) {
      print('⚠️  Failed to fetch current block height: $e');
      return _cachedBlockHeight; // Return cached value if available
    }
  }

  /// Calculate real confirmations based on block heights
  int? _calculateRealConfirmations(int? txBlockHeight, int? currentBlockHeight) {
    if (txBlockHeight == null || currentBlockHeight == null) return null;
    return currentBlockHeight - txBlockHeight + 1;
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
            icon: const Icon(Icons.refresh),
            onPressed: _refreshTransactions,
            tooltip: 'Refresh Transactions',
          ),
        ],
      ),
      body: SafeArea(
        child: Consumer<WalletProvider>(
          builder: (context, walletProvider, child) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                children: [
                  // Search and Filter Section
                  Padding(
                    padding: ResponsiveUtils.getScreenPadding(context),
                    child: Column(
                      children: [
                        // Search Bar
                        Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(ResponsiveUtils.getCardBorderRadius(context)),
                            border: Border.all(
                              color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                            ),
                          ),
                          child: TextField(
                            controller: _searchController,
                            onChanged: _onSearchChanged,
                            decoration: InputDecoration(
                              hintText: 'Search transactions...',
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear),
                                      onPressed: () {
                                        _searchController.clear();
                                        _onSearchChanged('');
                                      },
                                    )
                                  : null,
                              border: InputBorder.none,
                              contentPadding: ResponsiveUtils.getInputFieldPadding(context),
                            ),
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                        
                        SizedBox(height: ResponsiveUtils.isSmallScreen(context) ? 12 : 16),
                        
                        // Filter Chips
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: TransactionFilter.values.map((filter) {
                              final isSelected = _currentFilter == filter;
                              final count = _getFilterCount(filter);
                              
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: FilterChip(
                                  label: Text('${_getFilterLabel(filter)} ($count)'),
                                  selected: isSelected,
                                  onSelected: (_) => _onFilterChanged(filter),
                                  selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                                  checkmarkColor: Theme.of(context).colorScheme.primary,
                                  labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
                                    color: isSelected 
                                        ? Theme.of(context).colorScheme.primary 
                                        : Theme.of(context).colorScheme.onSurface,
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: ResponsiveUtils.isSmallScreen(context) ? 16 : 20),
                  
                  // Transaction List
                  Expanded(
                    child: _buildTransactionList(walletProvider),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTransactionList(WalletProvider walletProvider) {
    // Filter transactions locally (BitcoinZ Blue approach)
    List<TransactionModel> filteredTransactions = walletProvider.transactions;
    
    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filteredTransactions = filteredTransactions.where((tx) {
        return tx.txid.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               (tx.toAddress?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
               (tx.fromAddress?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
               (tx.memo?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
      }).toList();
    }
    
    // Apply type filter
    if (_currentFilter != TransactionFilter.all) {
      filteredTransactions = filteredTransactions.where((tx) {
        switch (_currentFilter) {
          case TransactionFilter.sent:
            return tx.type == 'sent';
          case TransactionFilter.received:
            return tx.type == 'received';  
          case TransactionFilter.confirming:
            return tx.isConfirming;
          case TransactionFilter.all:
          default:
            return true;
        }
      }).toList();
    }
    
    if (walletProvider.isLoading && filteredTransactions.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading transactions...'),
          ],
        ),
      );
    }

    if (filteredTransactions.isEmpty && !walletProvider.isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No transactions found for "$_searchQuery"'
                  : 'No transactions yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Try a different search term'
                  : 'Your transactions will appear here',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshTransactions,
      child: ListView.builder(
        controller: _scrollController,
        padding: ResponsiveUtils.getScreenPadding(context),
        itemCount: filteredTransactions.length, // Use filtered list
        itemBuilder: (context, index) {
          final transaction = filteredTransactions[index];
          return _buildTransactionItem(transaction, index);
        },
      ),
    );
  }

  Widget _buildLoadingIndicator(WalletProvider walletProvider) {
    if (walletProvider.isLoadingMore) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: const Center(
          child: Column(
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 8),
              Text('Loading more transactions...'),
            ],
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildTransactionItem(TransactionModel transaction, int index) {
    final isReceived = transaction.isReceived;
    final isSent = transaction.isSent;
    final isPending = transaction.isPending;

    return Container(
      margin: EdgeInsets.only(
        bottom: ResponsiveUtils.isSmallScreen(context) ? 8 : 12,
      ),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ResponsiveUtils.getCardBorderRadius(context)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(ResponsiveUtils.getCardBorderRadius(context)),
          onTap: () => _showTransactionDetails(transaction),
          child: Padding(
            padding: EdgeInsets.all(ResponsiveUtils.getHorizontalPadding(context)),
            child: Row(
              children: [
                // Transaction Icon
                Container(
                  width: ResponsiveUtils.getIconSize(context, base: 40),
                  height: ResponsiveUtils.getIconSize(context, base: 40),
                  decoration: BoxDecoration(
                    color: _getTransactionColor(transaction).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(ResponsiveUtils.getCardBorderRadius(context) * 0.5),
                  ),
                  child: Icon(
                    _getTransactionIcon(transaction),
                    color: _getTransactionColor(transaction),
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
                            _getTransactionTitle(transaction),
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${isReceived ? '+' : '-'}${transaction.amount.toStringAsFixed(8)} BTCZ',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: _getTransactionColor(transaction),
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 4),
                      
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              _formatAddress(transaction.toAddress ?? transaction.fromAddress ?? 'Unknown'),
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                fontFamily: 'monospace',
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            DateFormat('MMM dd, HH:mm').format(transaction.timestamp),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                      
                      if ((transaction.confirmations ?? 0) == 0) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            SizedBox(
                              width: 8,
                              height: 8,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Confirming',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: Colors.orange,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ] else if ((transaction.confirmations ?? 0) >= 1) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Confirmed',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: Colors.green,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showTransactionDetails(TransactionModel transaction) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(ResponsiveUtils.getCardBorderRadius(context)),
        ),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.3,
        expand: false,
        builder: (context, scrollController) {
          return _buildTransactionDetailsSheet(transaction, scrollController);
        },
      ),
    );
  }

  Widget _buildTransactionDetailsSheet(TransactionModel transaction, ScrollController scrollController) {
    return Container(
      padding: ResponsiveUtils.getScreenPadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          
          Text(
            'Transaction Details',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const SizedBox(height: 20),
          
          Expanded(
            child: ListView(
              controller: scrollController,
              children: [
                _buildDetailRow('Transaction ID', transaction.txid, copyable: true),
                _buildDetailRow('Amount', '${transaction.amount.toStringAsFixed(8)} BTCZ'),
                _buildDetailRow('Type', _getTransactionTitle(transaction)),
                _buildDetailRow('Date', DateFormat('EEEE, MMMM dd, yyyy at HH:mm:ss').format(transaction.timestamp)),
                _buildDetailRow('Status', transaction.isPending ? 'Confirming' : 'Confirmed'),
                if (!transaction.isPending)
                  _buildConfirmationRow(transaction),
                if (transaction.fee != null)
                  _buildDetailRow('Fee', '${transaction.fee!.toStringAsFixed(8)} BTCZ'),
                if (transaction.fromAddress != null)
                  _buildDetailRow('From', transaction.fromAddress!, copyable: true),
                if (transaction.toAddress != null)
                  _buildDetailRow('To', transaction.toAddress!, copyable: true),
                if (transaction.memo?.isNotEmpty == true)
                  _buildDetailRow('Memo', transaction.memo!),
                if (transaction.blockHeight != null)
                  _buildDetailRow('Block Height', transaction.blockHeight.toString()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool copyable = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontFamily: copyable ? 'monospace' : null,
                  ),
                ),
              ),
              if (copyable)
                IconButton(
                  icon: const Icon(Icons.copy, size: 18),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: value));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('$label copied to clipboard'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmationRow(TransactionModel transaction) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Confirmations',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          // Use the pre-calculated confirmations from the transaction model
          Builder(
            builder: (context) {
              final confirmations = transaction.confirmations ?? 0;
              
              String confirmationText;
              if (confirmations == 0) {
                confirmationText = 'Unconfirmed';
              } else if (confirmations < 6) {
                confirmationText = '$confirmations (Confirming...)';
              } else {
                // Show actual confirmation count for fully confirmed transactions
                confirmationText = confirmations.toString();
              }

              return Text(
                confirmationText,
                style: Theme.of(context).textTheme.bodyMedium,
              );
            },
          ),
        ],
      ),
    );
  }

  String _getFilterLabel(TransactionFilter filter) {
    switch (filter) {
      case TransactionFilter.all:
        return 'All';
      case TransactionFilter.sent:
        return 'Sent';
      case TransactionFilter.received:
        return 'Received';
      case TransactionFilter.confirming:
        return 'Confirming';
    }
  }

  int _getFilterCount(TransactionFilter filter) {
    // Use live transaction data instead of database stats (BitcoinZ Blue approach)
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    final transactions = walletProvider.transactions;
    
    switch (filter) {
      case TransactionFilter.all:
        return transactions.length;
      case TransactionFilter.sent:
        return transactions.where((tx) => tx.type == 'sent').length;
      case TransactionFilter.received:
        return transactions.where((tx) => tx.type == 'received').length;
      case TransactionFilter.confirming:
        return transactions.where((tx) => tx.isConfirming).length;
    }
  }

  String _getTransactionTitle(TransactionModel transaction) {
    if (transaction.isSent) return 'Sent';
    if (transaction.isReceived) return 'Received';
    return 'Transaction';
  }

  IconData _getTransactionIcon(TransactionModel transaction) {
    if (transaction.isPending) return Icons.schedule;
    if (transaction.isSent) return Icons.arrow_upward;
    if (transaction.isReceived) return Icons.arrow_downward;
    return Icons.sync_alt;
  }

  Color _getTransactionColor(TransactionModel transaction) {
    if (transaction.isPending) return Colors.orange;
    if (transaction.isSent) return Colors.red;
    if (transaction.isReceived) return Colors.green;
    return Theme.of(context).colorScheme.primary;
  }

  String _formatAddress(String address) {
    if (address.length <= 20) return address;
    return '${address.substring(0, 10)}...${address.substring(address.length - 10)}';
  }
  
  String _getConfirmationText(TransactionModel transaction) {
    final confirmations = transaction.confirmations ?? 0;
    if (confirmations >= 6) {
      return '$confirmations+ (Fully Confirmed)';
    } else if (confirmations > 0) {
      return '$confirmations (Confirming...)';
    } else {
      return '0 (Unconfirmed)';
    }
  }
}