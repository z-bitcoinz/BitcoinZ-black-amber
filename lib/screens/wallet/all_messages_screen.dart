import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/wallet_provider.dart';
import '../../models/transaction_model.dart';
import '../../models/message_label.dart';
import '../../widgets/message_label_dialog.dart';
import '../../utils/responsive.dart';

/// Dedicated screen showing all transactions with messages/memos
class AllMessagesScreen extends StatefulWidget {
  const AllMessagesScreen({super.key});

  @override
  State<AllMessagesScreen> createState() => _AllMessagesScreenState();
}

class _AllMessagesScreenState extends State<AllMessagesScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _searchQuery = '';
  bool _showUnreadOnly = false;
  List<TransactionModel> _filteredTransactions = [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMessagesWithTransactions();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
      _filterTransactions();
    });
  }

  Future<void> _loadMessagesWithTransactions() async {
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    
    // Get all transactions with memos
    final allTransactions = walletProvider.transactions;
    final transactionsWithMemos = allTransactions.where((tx) => tx.hasMemo).toList();
    
    // Sort by timestamp (newest first)
    transactionsWithMemos.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    
    setState(() {
      _filteredTransactions = transactionsWithMemos;
      _filterTransactions();
    });
  }

  void _filterTransactions() {
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    final allTransactions = walletProvider.transactions;
    var transactionsWithMemos = allTransactions.where((tx) => tx.hasMemo).toList();
    
    // Apply unread filter
    if (_showUnreadOnly) {
      transactionsWithMemos = transactionsWithMemos.where((tx) {
        return !walletProvider.getTransactionMemoReadStatus(tx.txid, tx.memoRead);
      }).toList();
    }
    
    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      transactionsWithMemos = transactionsWithMemos.where((tx) {
        final memo = tx.memo?.toLowerCase() ?? '';
        final txid = tx.txid.toLowerCase();
        final address = (tx.toAddress ?? tx.fromAddress ?? '').toLowerCase();

        return memo.contains(_searchQuery) ||
               txid.contains(_searchQuery) ||
               address.contains(_searchQuery);
      }).toList();
    }
    
    // Sort by timestamp (newest first)
    transactionsWithMemos.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    
    setState(() {
      _filteredTransactions = transactionsWithMemos;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Messages'),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_showUnreadOnly ? Icons.mark_email_read : Icons.mark_email_unread),
            onPressed: () {
              setState(() {
                _showUnreadOnly = !_showUnreadOnly;
                _filterTransactions();
              });
            },
            tooltip: _showUnreadOnly ? 'Show All Messages' : 'Show Unread Only',
          ),
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'mark_all_read',
                child: Row(
                  children: [
                    Icon(Icons.mark_email_read),
                    SizedBox(width: 8),
                    Text('Mark All as Read'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'mark_all_unread',
                child: Row(
                  children: [
                    Icon(Icons.mark_email_unread),
                    SizedBox(width: 8),
                    Text('Mark All as Unread'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search messages...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
              ),
            ),
          ),
          
          // Filter chips
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                FilterChip(
                  label: Text('Unread Only (${_getUnreadCount()})'),
                  selected: _showUnreadOnly,
                  onSelected: (selected) {
                    setState(() {
                      _showUnreadOnly = selected;
                      _filterTransactions();
                    });
                  },
                ),
                const SizedBox(width: 8),
                Text(
                  '${_filteredTransactions.length} messages',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Messages list
          Expanded(
            child: _filteredTransactions.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filteredTransactions.length,
                    itemBuilder: (context, index) {
                      final transaction = _filteredTransactions[index];
                      return _buildMessageItem(transaction, index);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _showUnreadOnly ? Icons.mark_email_read : Icons.message,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            _showUnreadOnly ? 'No unread messages' : 'No messages found',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _showUnreadOnly 
                ? 'All your messages have been read'
                : _searchQuery.isNotEmpty 
                    ? 'Try adjusting your search terms'
                    : 'Transactions with memos will appear here',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMessageItem(TransactionModel transaction, int index) {
    return Consumer<WalletProvider>(
      builder: (context, walletProvider, _) {
        final isUnread = !walletProvider.getTransactionMemoReadStatus(transaction.txid, transaction.memoRead);
        final amount = transaction.amount; // Already in BTCZ
        final isIncoming = transaction.isReceived;
        
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: isUnread ? 2 : 1,
          child: InkWell(
            onTap: () => _showMessageDetails(transaction),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: isUnread 
                    ? Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.3))
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row
                  Row(
                    children: [
                      // Transaction type icon
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (isIncoming ? Colors.green : Colors.red).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          isIncoming ? Icons.call_received : Icons.call_made,
                          color: isIncoming ? Colors.green : Colors.red,
                          size: 20,
                        ),
                      ),
                      
                      const SizedBox(width: 12),
                      
                      // Amount and status
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${isIncoming ? '+' : '-'}${amount.toStringAsFixed(8)} BTCZ',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: isIncoming ? Colors.green : Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              DateFormat('MMM dd, yyyy • HH:mm').format(transaction.timestamp),
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Unread indicator
                      if (isUnread)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      
                      // Menu button
                      PopupMenuButton<String>(
                        onSelected: (value) => _handleTransactionAction(value, transaction),
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: isUnread ? 'mark_read' : 'mark_unread',
                            child: Row(
                              children: [
                                Icon(isUnread ? Icons.mark_email_read : Icons.mark_email_unread),
                                const SizedBox(width: 8),
                                Text(isUnread ? 'Mark as Read' : 'Mark as Unread'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'manage_labels',
                            child: Row(
                              children: [
                                Icon(Icons.label),
                                SizedBox(width: 8),
                                Text('Manage Labels'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Message content
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      transaction.memo ?? '',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        height: 1.4,
                        fontWeight: isUnread ? FontWeight.w500 : FontWeight.normal,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Labels
                  FutureBuilder<List<MessageLabel>>(
                    future: walletProvider.getMessageLabels(transaction.txid),
                    builder: (context, snapshot) {
                      if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                        return Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: snapshot.data!.map((label) => _buildSmallLabelChip(label)).toList(),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSmallLabelChip(MessageLabel label) {
    final color = Color(int.parse(label.labelColor.substring(1), radix: 16) + 0xFF000000);
    final textColor = _getContrastColor(color);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label.labelName,
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Color _getContrastColor(Color color) {
    final luminance = (0.299 * color.red + 0.587 * color.green + 0.114 * color.blue) / 255;
    return luminance > 0.5 ? Colors.black : Colors.white;
  }

  int _getUnreadCount() {
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    return _filteredTransactions.where((tx) {
      return !walletProvider.getTransactionMemoReadStatus(tx.txid, tx.memoRead);
    }).length;
  }

  void _showMessageDetails(TransactionModel transaction) {
    // Mark as read when viewing
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    walletProvider.markMemoAsRead(transaction.txid);
    
    // Show transaction details (you can customize this)
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Transaction Details',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text('TXID: ${transaction.txid}'),
              const SizedBox(height: 8),
              Text('Amount: ${(transaction.amount / 100000000).toStringAsFixed(8)} BTCZ'),
              const SizedBox(height: 8),
              Text('Date: ${DateFormat('MMM dd, yyyy • HH:mm').format(transaction.timestamp)}'),
              const SizedBox(height: 16),
              Text(
                'Message:',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  transaction.memo ?? '',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleMenuAction(String action) async {
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    
    switch (action) {
      case 'mark_all_read':
        for (final transaction in _filteredTransactions) {
          await walletProvider.markMemoAsRead(transaction.txid);
        }
        setState(() {
          _filterTransactions();
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('All messages marked as read')),
          );
        }
        break;
      case 'mark_all_unread':
        for (final transaction in _filteredTransactions) {
          await walletProvider.markMemoAsUnread(transaction.txid);
        }
        setState(() {
          _filterTransactions();
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('All messages marked as unread')),
          );
        }
        break;
    }
  }

  void _handleTransactionAction(String action, TransactionModel transaction) async {
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    
    switch (action) {
      case 'mark_read':
        await walletProvider.markMemoAsRead(transaction.txid);
        setState(() {
          _filterTransactions();
        });
        break;
      case 'mark_unread':
        await walletProvider.markMemoAsUnread(transaction.txid);
        setState(() {
          _filterTransactions();
        });
        break;
      case 'manage_labels':
        final existingLabels = await walletProvider.getMessageLabels(transaction.txid);
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => MessageLabelDialog(
              txid: transaction.txid,
              currentMemo: transaction.memo,
              existingLabels: existingLabels,
              onLabelAdded: (label) async {
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
        break;
    }
  }
}
