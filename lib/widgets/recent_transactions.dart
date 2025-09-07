import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../providers/wallet_provider.dart';
import '../providers/currency_provider.dart';
// import '../services/btcz_cli_service.dart'; // Removed - CLI no longer used
import '../utils/responsive.dart';
import 'animated_confirming_text.dart';

import '../utils/formatters.dart';
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
  // final BtczCliService _cliService = BtczCliService(); // Removed - CLI no longer used

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
    return Consumer<WalletProvider>(
      builder: (context, walletProvider, child) {
        final recentTransactions = walletProvider.transactions
            .take(widget.limit)
            .toList();

        if (recentTransactions.isEmpty) {
          // Show loading skeleton if wallet is loading, empty state otherwise
          if (walletProvider.isLoading || !walletProvider.hasWallet) {
            return _buildTransactionSkeleton();
          }

          return ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF2A2A2A).withOpacity(0.95),
                    const Color(0xFF1F1F1F).withOpacity(0.9),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.08),
                  width: 1,
                ),
              ),
              child: Column(
              children: [
                Icon(
                  Icons.receipt_long,
                  size: 48,
                  color: Colors.white.withOpacity(0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  'No transactions yet',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
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
            ),
          );
        }

        // Simple list without decoration
        return MediaQuery.removePadding(
          context: context,
          removeTop: true,
          child: ListView.separated(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: recentTransactions.length,
            separatorBuilder: (context, index) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: Divider(
                height: 1,
                thickness: 0.5,
                color: Colors.white.withOpacity(0.1),
              ),
            ),
            itemBuilder: (context, index) {
              final transaction = recentTransactions[index];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                onTap: () => _showTransactionDetails(transaction),
                leading: Stack(
                  children: [
                    Container(
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
                    // Memo indicator
                    if (transaction.hasMemo)
                      Consumer<WalletProvider>(
                        builder: (context, walletProvider, _) {
                          // Get the actual memo read status from cache
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
                                    ? Colors.grey.withOpacity(0.5)
                                    : const Color(0xFFFF6B00),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFF1A1A1A),
                                  width: 1.5,
                                ),
                              ),
                              child: Icon(
                                Icons.message,
                                size: 10,
                                color: isRead
                                    ? Colors.white.withOpacity(0.5)
                                    : Colors.black87,
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
                title: Text(
                  transaction.isReceived ? 'Received' : 'Sent',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  _getDisplayAddress(transaction),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                trailing: Consumer<CurrencyProvider>(
                  builder: (context, currencyProvider, _) {
                    final confirmations = transaction.confirmations ?? 0;
                    final isConfirming = confirmations == 0;

                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Amount with status indicator
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Show animated confirming text for unconfirmed transactions
                            if (isConfirming) ...[
                              Container(
                                margin: const EdgeInsets.only(right: 8),
                                child: const AnimatedConfirmingText(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                            Text(
                              transaction.displayAmount,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: transaction.isReceived
                                    ? Colors.green
                                    : Colors.orange,
                              ),
                            ),
                          ],
                        ),
                        // Show fiat amount if price available, or status text
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
      // 1+ confirmations = Confirmed (checkmark only)
      return Icon(
        Icons.check_circle,
        size: 12,
        color: Colors.green,
      );
    }
  }

  void _showTransactionDetails(transaction) async {
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
                // Basic info first
                _buildDetailRow('Amount', '${Formatters.formatBtczTrim(transaction.amount, showSymbol: false)} BTCZ'),
                // Show fiat value in details
                Consumer<CurrencyProvider>(
                  builder: (context, currencyProvider, _) {
                    if (currencyProvider.currentPrice != null) {
                      final fiatAmount = currencyProvider.formatFiatAmount(transaction.amount.abs());
                      return _buildDetailRow('Value (${currencyProvider.selectedCurrency.code})', fiatAmount);
                    }
                    return const SizedBox.shrink();
                  },
                ),
                _buildDetailRow('Type', transaction.isReceived ? 'Received' : 'Sent'),

                // Memo prominently displayed if exists
                if (transaction.memo?.isNotEmpty == true)
                  _buildMemoCard(transaction.memo!),

                // Status and confirmations
                _buildDetailRow('Status', transaction.confirmations == 0 ? 'Unconfirmed' : (transaction.confirmations < 6 ? 'Confirming' : 'Confirmed')),
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
          // Use stored confirmations from transaction (already calculated by Rust service)
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

  /// Build skeleton loading animation for better UX
  Widget _buildTransactionSkeleton() {
    return MediaQuery.removePadding(
      context: context,
      removeTop: true,
      child: Column(
        children: List.generate(3, (index) => _buildSkeletonItem()), // Show 3 skeleton items
      ),
    );
  }

  Widget _buildSkeletonItem() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A).withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Skeleton icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Skeleton amount line
                Container(
                  width: 120,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 6),
                // Skeleton date line
                Container(
                  width: 80,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ],
            ),
          ),

          // Skeleton status
          Container(
            width: 60,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ],
      ),
    );
  }
}