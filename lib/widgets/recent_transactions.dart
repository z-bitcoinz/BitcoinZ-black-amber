import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../providers/wallet_provider.dart';
import '../services/btcz_cli_service.dart';
import '../utils/responsive.dart';

class RecentTransactions extends StatefulWidget {
  final int limit;

  const RecentTransactions({
    super.key,
    this.limit = 10,
  });

  @override
  State<RecentTransactions> createState() => _RecentTransactionsState();
}

class _RecentTransactionsState extends State<RecentTransactions> {
  // Block height caching
  int? _cachedBlockHeight;
  DateTime? _blockHeightCacheTime;
  final Duration _blockHeightCacheDuration = const Duration(seconds: 30);
  final BtczCliService _cliService = BtczCliService();

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
      final blockHeight = await _cliService.getCurrentBlockHeight();
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
    return Consumer<WalletProvider>(
      builder: (context, walletProvider, child) {
        final recentTransactions = walletProvider.transactions
            .take(widget.limit)
            .toList();

        if (recentTransactions.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.receipt_long,
                  size: 48,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(height: 16),
                Text(
                  'No transactions yet',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your transaction history will appear here',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline.withOpacity(0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
            ),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: recentTransactions.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
            ),
            itemBuilder: (context, index) {
              final transaction = recentTransactions[index];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                onTap: () => _showTransactionDetails(transaction),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: transaction.isReceived 
                        ? Colors.green.withOpacity(0.1)
                        : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    transaction.isReceived 
                        ? Icons.arrow_downward
                        : Icons.arrow_upward,
                    color: transaction.isReceived 
                        ? Colors.green
                        : Colors.orange,
                    size: 20,
                  ),
                ),
                title: Text(
                  transaction.isReceived ? 'Received' : 'Sent',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  _getDisplayAddress(transaction),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      transaction.displayAmount,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: transaction.isReceived 
                            ? Colors.green
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    _buildStatusWidget(transaction, context),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  String _getDisplayAddress(transaction) {
    String? address;
    
    if (transaction.isReceived) {
      // For received transactions, show sender (from) address if available, otherwise our address
      address = transaction.fromAddress ?? transaction.toAddress;
    } else if (transaction.isSent) {
      // For sent transactions, show recipient (to) address
      address = transaction.toAddress;
    }
    
    if (address == null || address.isEmpty) {
      return 'Unknown';
    }
    
    return _formatAddress(address);
  }

  String _formatAddress(String address) {
    if (address.length <= 16) return address;
    return '${address.substring(0, 8)}...${address.substring(address.length - 8)}';
  }

  Widget _buildStatusWidget(transaction, BuildContext context) {
    final confirmations = transaction.confirmations ?? 0;
    
    if (confirmations == 0) {
      // 0 confirmations = Confirming (with progress circle)
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
            ),
          ),
          SizedBox(width: 4),
          Text(
            'Confirming',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.orange,
            ),
          ),
        ],
      );
    } else {
      // 1+ confirmations = Confirmed (with green dot)
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          SizedBox(width: 4),
          Text(
            'Confirmed',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.green,
            ),
          ),
        ],
      );
    }
  }

  void _showTransactionDetails(transaction) {
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

  Widget _buildTransactionDetailsSheet(transaction, ScrollController scrollController) {
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
                _buildDetailRow('Type', transaction.isReceived ? 'Received' : 'Sent'),
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

  Widget _buildConfirmationRow(transaction) {
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
          FutureBuilder<int?>(
            future: _getCurrentBlockHeight(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Row(
                  children: [
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Loading...',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                );
              }

              final currentBlockHeight = snapshot.data;
              final realConfirmations = _calculateRealConfirmations(
                transaction.blockHeight, 
                currentBlockHeight
              );

              String confirmationText;
              if (realConfirmations != null) {
                confirmationText = 'Confirmed ($realConfirmations)';
              } else {
                // Fallback to stored confirmations or default text
                final storedConfirmations = transaction.confirmations ?? 0;
                if (storedConfirmations >= 6) {
                  confirmationText = 'Confirmed (6+)';
                } else if (storedConfirmations > 0) {
                  confirmationText = '$storedConfirmations (Confirming...)';
                } else {
                  confirmationText = 'Unconfirmed';
                }
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
}