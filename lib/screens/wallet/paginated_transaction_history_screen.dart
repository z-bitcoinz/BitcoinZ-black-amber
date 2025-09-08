import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/currency_provider.dart';
import '../../models/transaction_model.dart';
import '../../models/message_label.dart';
import '../../models/transaction_category.dart';
import '../../widgets/message_label_dialog.dart';
import '../../widgets/transaction_category_chip.dart';
import '../../screens/wallet/all_messages_screen.dart';
import '../../utils/responsive.dart';
// import '../../services/btcz_cli_service.dart'; // Removed - CLI no longer used
import '../../utils/formatters.dart';

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
  bool _filterUnreadMemos = false; // Filter for unread memos from notification
  TransactionCategoryType? _selectedCategoryFilter;
  bool _showMessagesOnly = false;

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

    // Check if we should filter for unread memos (from notification icon)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null && args['filterUnreadMemos'] == true) {
        setState(() {
          _filterUnreadMemos = true;
        });
      }
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
    // Optimized scroll detection - load more when 80% scrolled
    final position = _scrollController.position;
    final threshold = position.maxScrollExtent * 0.8;

    if (position.pixels >= threshold) {
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

  void _handleFilterAction(String action) {
    setState(() {
      switch (action) {
        case 'messages_only':
          _showMessagesOnly = !_showMessagesOnly;
          _selectedCategoryFilter = null;
          _filterUnreadMemos = false;
          break;
        case 'unread_only':
          _filterUnreadMemos = !_filterUnreadMemos;
          _showMessagesOnly = false;
          _selectedCategoryFilter = null;
          break;
        case 'category_income':
          _selectedCategoryFilter = _selectedCategoryFilter == TransactionCategoryType.income
              ? null : TransactionCategoryType.income;
          _showMessagesOnly = false;
          _filterUnreadMemos = false;
          break;
        case 'category_expenses':
          _selectedCategoryFilter = _selectedCategoryFilter == TransactionCategoryType.expenses
              ? null : TransactionCategoryType.expenses;
          _showMessagesOnly = false;
          _filterUnreadMemos = false;
          break;
        case 'category_transfers':
          _selectedCategoryFilter = _selectedCategoryFilter == TransactionCategoryType.transfers
              ? null : TransactionCategoryType.transfers;
          _showMessagesOnly = false;
          _filterUnreadMemos = false;
          break;
        case 'category_investments':
          _selectedCategoryFilter = _selectedCategoryFilter == TransactionCategoryType.investments
              ? null : TransactionCategoryType.investments;
          _showMessagesOnly = false;
          _filterUnreadMemos = false;
          break;
        case 'category_other':
          _selectedCategoryFilter = _selectedCategoryFilter == TransactionCategoryType.other
              ? null : TransactionCategoryType.other;
          _showMessagesOnly = false;
          _filterUnreadMemos = false;
          break;
        case 'clear_filters':
          _selectedCategoryFilter = null;
          _showMessagesOnly = false;
          _filterUnreadMemos = false;
          _currentFilter = TransactionFilter.all;
          _searchController.clear();
          _searchQuery = '';
          break;
      }
    });
  }

  String _getAppBarTitle() {
    if (_filterUnreadMemos) return 'Unread Messages';
    if (_showMessagesOnly) return 'All Messages';
    if (_selectedCategoryFilter != null) {
      return '${TransactionCategorizer.getCategoryTypeDisplayName(_selectedCategoryFilter!)} Transactions';
    }
    return 'Transaction History';
  }

  bool _hasActiveFilters() {
    return _filterUnreadMemos || _showMessagesOnly || _selectedCategoryFilter != null;
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
        title: Text(_getAppBarTitle()),
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: _hasActiveFilters(), // Show back button when filtering
        actions: [
          // Messages button with unread count
          Consumer<WalletProvider>(
            builder: (context, walletProvider, _) {
              final unreadCount = walletProvider.unreadMessageCount;

              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.message),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AllMessagesScreen(),
                        ),
                      );
                    },
                    tooltip: 'View all messages',
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          '$unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),

          // Filter menu
          PopupMenuButton<String>(
            icon: Icon(
              Icons.filter_list,
              color: (_selectedCategoryFilter != null || _showMessagesOnly || _filterUnreadMemos)
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
            onSelected: _handleFilterAction,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'messages_only',
                child: Row(
                  children: [
                    Icon(
                      Icons.message,
                      color: _showMessagesOnly ? Theme.of(context).colorScheme.primary : null,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Messages Only',
                      style: TextStyle(
                        fontWeight: _showMessagesOnly ? FontWeight.bold : null,
                        color: _showMessagesOnly ? Theme.of(context).colorScheme.primary : null,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'unread_only',
                child: Row(
                  children: [
                    Icon(
                      Icons.mark_email_unread,
                      color: _filterUnreadMemos ? Theme.of(context).colorScheme.primary : null,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Unread Messages',
                      style: TextStyle(
                        fontWeight: _filterUnreadMemos ? FontWeight.bold : null,
                        color: _filterUnreadMemos ? Theme.of(context).colorScheme.primary : null,
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'category_income',
                child: Row(
                  children: [
                    Icon(
                      Icons.trending_up,
                      color: _selectedCategoryFilter == TransactionCategoryType.income
                          ? Colors.green : Colors.green.withOpacity(0.7),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Income',
                      style: TextStyle(
                        fontWeight: _selectedCategoryFilter == TransactionCategoryType.income
                            ? FontWeight.bold : null,
                        color: _selectedCategoryFilter == TransactionCategoryType.income
                            ? Colors.green : null,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'category_expenses',
                child: Row(
                  children: [
                    Icon(
                      Icons.trending_down,
                      color: _selectedCategoryFilter == TransactionCategoryType.expenses
                          ? Colors.orange : Colors.orange.withOpacity(0.7),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Expenses',
                      style: TextStyle(
                        fontWeight: _selectedCategoryFilter == TransactionCategoryType.expenses
                            ? FontWeight.bold : null,
                        color: _selectedCategoryFilter == TransactionCategoryType.expenses
                            ? Colors.orange : null,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'category_transfers',
                child: Row(
                  children: [
                    Icon(
                      Icons.swap_horiz,
                      color: _selectedCategoryFilter == TransactionCategoryType.transfers
                          ? Colors.blue : Colors.blue.withOpacity(0.7),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Transfers',
                      style: TextStyle(
                        fontWeight: _selectedCategoryFilter == TransactionCategoryType.transfers
                            ? FontWeight.bold : null,
                        color: _selectedCategoryFilter == TransactionCategoryType.transfers
                            ? Colors.blue : null,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'category_investments',
                child: Row(
                  children: [
                    Icon(
                      Icons.show_chart,
                      color: _selectedCategoryFilter == TransactionCategoryType.investments
                          ? Colors.purple : Colors.purple.withOpacity(0.7),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Investments',
                      style: TextStyle(
                        fontWeight: _selectedCategoryFilter == TransactionCategoryType.investments
                            ? FontWeight.bold : null,
                        color: _selectedCategoryFilter == TransactionCategoryType.investments
                            ? Colors.purple : null,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'category_other',
                child: Row(
                  children: [
                    Icon(
                      Icons.more_horiz,
                      color: _selectedCategoryFilter == TransactionCategoryType.other
                          ? Colors.grey : Colors.grey.withOpacity(0.7),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Other',
                      style: TextStyle(
                        fontWeight: _selectedCategoryFilter == TransactionCategoryType.other
                            ? FontWeight.bold : null,
                        color: _selectedCategoryFilter == TransactionCategoryType.other
                            ? Colors.grey : null,
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'clear_filters',
                child: Row(
                  children: [
                    Icon(Icons.clear),
                    SizedBox(width: 8),
                    Text('Clear Filters'),
                  ],
                ),
              ),
            ],
          ),

          if (_filterUnreadMemos)
            TextButton(
              onPressed: () {
                setState(() {
                  _filterUnreadMemos = false;
                });
              },
              child: const Text('Show All'),
            ),
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

                        // Filter Chips (hide when filtering unread memos)
                        if (!_filterUnreadMemos)
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
      floatingActionButton: Consumer<WalletProvider>(
        builder: (context, walletProvider, _) {
          final unreadCount = walletProvider.unreadMessageCount;
          final hasMessages = walletProvider.allMessageTransactions.isNotEmpty;

          if (!hasMessages) return const SizedBox.shrink();

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Quick actions for messages
              if (unreadCount > 0)
                FloatingActionButton.small(
                  heroTag: "mark_all_read",
                  onPressed: () async {
                    await walletProvider.markAllMessagesAsRead();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('All messages marked as read')),
                      );
                    }
                  },
                  backgroundColor: Colors.green,
                  child: const Icon(Icons.mark_email_read, color: Colors.white),
                  tooltip: 'Mark all as read',
                ),

              if (unreadCount > 0) const SizedBox(height: 8),

              // Main messages FAB
              FloatingActionButton(
                heroTag: "messages_main",
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AllMessagesScreen(),
                    ),
                  );
                },
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white, // ensure high-contrast icon
                child: Stack(
                  children: [
                    const Icon(Icons.message, color: Colors.white),
                    if (unreadCount > 0)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 12,
                            minHeight: 12,
                          ),
                          child: Text(
                            '$unreadCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
                tooltip: unreadCount > 0
                    ? 'View messages ($unreadCount unread)'
                    : 'View all messages',
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTransactionList(WalletProvider walletProvider) {
    // Filter transactions locally (BitcoinZ Blue approach)
    List<TransactionModel> filteredTransactions = walletProvider.transactions;

    // Apply messages only filter
    if (_showMessagesOnly) {
      filteredTransactions = filteredTransactions.where((tx) => tx.hasMemo).toList();
    }

    // Apply unread memo filter
    if (_filterUnreadMemos) {
      filteredTransactions = filteredTransactions.where((tx) {
        if (!tx.hasMemo) return false;
        // Use cached memo status to check if unread
        final isRead = walletProvider.getTransactionMemoReadStatus(
          tx.txid,
          tx.memoRead
        );
        return !isRead; // Only show unread memos
      }).toList();
    }

    // Apply category filter
    if (_selectedCategoryFilter != null) {
      // Use a simpler synchronous approach based on transaction properties
      filteredTransactions = filteredTransactions.where((tx) {
        switch (_selectedCategoryFilter!) {
          case TransactionCategoryType.income:
            return tx.isReceived;
          case TransactionCategoryType.expenses:
            return tx.isSent && !(tx.memo?.toLowerCase().contains('transfer') == true);
          case TransactionCategoryType.transfers:
            return tx.memo?.toLowerCase().contains('transfer') == true ||
                   tx.memo?.toLowerCase().contains('exchange') == true ||
                   tx.memo?.toLowerCase().contains('swap') == true;
          case TransactionCategoryType.investments:
            return tx.memo?.toLowerCase().contains('stake') == true ||
                   tx.memo?.toLowerCase().contains('trade') == true ||
                   tx.memo?.toLowerCase().contains('defi') == true;
          case TransactionCategoryType.other:
            return tx.memo?.toLowerCase().contains('donation') == true ||
                   tx.memo?.toLowerCase().contains('tip') == true;
        }
      }).toList();
    }

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filteredTransactions = filteredTransactions.where((tx) {
        return tx.txid.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               (tx.toAddress?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
               (tx.fromAddress?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
               (tx.memo?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
      }).toList();
    }

    // Apply type filter (only if not filtering unread memos)
    if (!_filterUnreadMemos && _currentFilter != TransactionFilter.all) {
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
        itemCount: filteredTransactions.length + (walletProvider.isLoadingMore ? 1 : 0),
        // Optimize for large lists
        cacheExtent: 1000, // Cache more items for smoother scrolling
        addAutomaticKeepAlives: false, // Don't keep items alive unnecessarily
        addRepaintBoundaries: true, // Improve repaint performance
        itemBuilder: (context, index) {
          // Show loading indicator at the end
          if (index >= filteredTransactions.length) {
            return _buildLoadingIndicator(walletProvider);
          }

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
                // Transaction Icon with memo indicator
                Stack(
                  children: [
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
                    // Memo indicator
                    if (transaction.hasMemo)
                      Consumer<WalletProvider>(
                        builder: (context, walletProvider, _) {
                          // Get the actual memo read status from cache (same as transaction list)
                          final isRead = walletProvider.getTransactionMemoReadStatus(
                            transaction.txid,
                            transaction.memoRead
                          );

                          return Positioned(
                            right: -2,
                            top: -2,
                            child: Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: isRead
                                    ? Theme.of(context).colorScheme.surfaceVariant
                                    : Colors.red,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.surface,
                                  width: 1.5,
                                ),
                              ),
                              child: Icon(
                                Icons.message,
                                size: 10,
                                color: isRead
                                    ? Theme.of(context).colorScheme.onSurfaceVariant
                                    : Colors.white,
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),

                // Label indicator (small icon next to transaction icon)
                Consumer<WalletProvider>(
                  builder: (context, walletProvider, _) {
                    return FutureBuilder<List<MessageLabel>>(
                      future: walletProvider.getMessageLabels(transaction.txid),
                      builder: (context, snapshot) {
                        if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                          final labels = snapshot.data!;
                          return Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Icon(
                              Icons.label,
                              size: 14,
                              color: Color(int.parse(labels.first.labelColor.substring(1), radix: 16) + 0xFF000000),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    );
                  },
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
                          Consumer<CurrencyProvider>(
                            builder: (context, currencyProvider, _) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${isReceived ? '+' : '-'}${Formatters.formatBtczTrim(transaction.amount, showSymbol: false)} BTCZ',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      color: _getTransactionColor(transaction),
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                  // Show fiat amount if price available
                                  if (currencyProvider.currentPrice != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      currencyProvider.formatFiatAmount(transaction.amount.abs()),
                                      style: TextStyle(
                                        fontSize: 11,
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
                            const Spacer(),
                            // Transaction category chip
                            Consumer<WalletProvider>(
                              builder: (context, walletProvider, _) {
                                return AsyncTransactionCategoryChip(
                                  categoryFuture: walletProvider.getTransactionCategory(transaction.txid),
                                  showIcon: false,
                                  fontSize: 9,
                                );
                              },
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

  void _showTransactionDetails(TransactionModel transaction) async {
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);

    // Mark memo as read if it has one and is unread (check cached status)
    if (transaction.hasMemo) {
      final isRead = walletProvider.getTransactionMemoReadStatus(
        transaction.txid,
        transaction.memoRead
      );
      if (!isRead) {
        await walletProvider.markMemoAsRead(transaction.txid);
      }
    }

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
                // Basic info first
                _buildDetailRow('Amount', '${Formatters.formatBtczTrim(transaction.amount, showSymbol: false)} BTCZ'),
                _buildDetailRow('Type', _getTransactionTitle(transaction)),

                // Memo prominently displayed if exists (same as main page)
                if (transaction.memo?.isNotEmpty == true)
                  _buildMemoCard(transaction.memo!),

                // Message labels section
                _buildMessageLabelsSection(transaction),

                // Status and confirmations
                _buildDetailRow('Status', transaction.isPending ? 'Confirming' : 'Confirmed'),
                if (!transaction.isPending)
                  _buildConfirmationRow(transaction),

                // Date and time
                _buildDetailRow('Date', DateFormat('EEEE, MMMM dd, yyyy at HH:mm:ss').format(transaction.timestamp)),

                // Addresses
                if (transaction.fromAddress != null)
                  _buildDetailRow('From', transaction.fromAddress!, copyable: true),
                if (transaction.toAddress != null)
                  _buildDetailRow('To', transaction.toAddress!, copyable: true),

                // Additional details
                if (transaction.fee != null)
                  _buildDetailRow('Fee', '${Formatters.formatBtczTrim(transaction.fee!, showSymbol: false)} BTCZ'),
                if (transaction.blockHeight != null)
                  _buildDetailRow('Block Height', transaction.blockHeight.toString()),

                // Transaction ID at the bottom for reference
                _buildDetailRow('Transaction ID', transaction.txid, copyable: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemoCard(String memo) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.message,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Memo',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            memo,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageLabelsSection(TransactionModel transaction) {
    return Consumer<WalletProvider>(
      builder: (context, walletProvider, _) {
        return FutureBuilder<List<MessageLabel>>(
          future: walletProvider.getMessageLabels(transaction.txid),
          builder: (context, snapshot) {
            final labels = snapshot.data ?? [];

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.label,
                        size: 20,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Labels',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.secondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () => _showLabelDialog(transaction, labels),
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text('Manage'),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (labels.isEmpty)
                    Text(
                      'No labels yet. Tap "Manage" to add labels.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: labels.map((label) => _buildLabelChip(label)).toList(),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLabelChip(MessageLabel label) {
    final color = Color(int.parse(label.labelColor.substring(1), radix: 16) + 0xFF000000);
    final textColor = _getContrastColor(color);

    return Chip(
      label: Text(
        label.labelName,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w500,
          fontSize: 12,
        ),
      ),
      backgroundColor: color,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  void _showLabelDialog(TransactionModel transaction, List<MessageLabel> existingLabels) {
    showDialog(
      context: context,
      builder: (context) => MessageLabelDialog(
        txid: transaction.txid,
        currentMemo: transaction.memo,
        existingLabels: existingLabels,
        onLabelAdded: (label) async {
          final walletProvider = Provider.of<WalletProvider>(context, listen: false);
          try {
            await walletProvider.addMessageLabel(label);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Added label "${label.labelName}"')),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to add label: $e')),
              );
            }
          }
        },
        onLabelRemoved: (label) async {
          final walletProvider = Provider.of<WalletProvider>(context, listen: false);
          try {
            await walletProvider.removeMessageLabel(label);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Removed label "${label.labelName}"')),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to remove label: $e')),
              );
            }
          }
        },
      ),
    );
  }

  Color _getContrastColor(Color color) {
    // Calculate luminance to determine if we need light or dark text
    final luminance = (0.299 * color.red + 0.587 * color.green + 0.114 * color.blue) / 255;
    return luminance > 0.5 ? Colors.black : Colors.white;
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