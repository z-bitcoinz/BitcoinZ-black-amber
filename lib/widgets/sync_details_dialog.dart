import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/wallet_provider.dart';
import '../providers/network_provider.dart';

/// Detailed sync information dialog
class SyncDetailsDialog extends StatelessWidget {
  const SyncDetailsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<WalletProvider, NetworkProvider>(
      builder: (context, walletProvider, networkProvider, child) {
        final theme = Theme.of(context);
        
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.grey.shade800,
                width: 1,
              ),
            ),
            padding: const EdgeInsets.all(24),
            constraints: const BoxConstraints(maxWidth: 380),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Sync Details',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Colors.white70),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Connection Status
                _buildDetailRow(
                  context,
                  icon: Icons.wifi,
                  label: 'Connection',
                  value: walletProvider.isConnected ? 'Connected' : 'Disconnected',
                  valueColor: walletProvider.isConnected ? Colors.green : Colors.red,
                ),
                const SizedBox(height: 12),
                
                // Server
                _buildDetailRow(
                  context,
                  icon: Icons.dns,
                  label: 'Server',
                  value: networkProvider.currentServerInfo?.displayName ?? 'Unknown Server',
                ),
                const SizedBox(height: 12),
                
                // Sync Status
                _buildDetailRow(
                  context,
                  icon: Icons.sync,
                  label: 'Status',
                  value: walletProvider.isSyncing 
                    ? 'Syncing (${walletProvider.syncProgress.toStringAsFixed(1)}%)'
                    : 'Idle',
                  valueColor: walletProvider.isSyncing ? Colors.blue : null,
                ),
                
                if (walletProvider.isSyncing || walletProvider.syncedBlocks > 0) ...[
                  const SizedBox(height: 20),
                  Divider(color: Colors.grey.shade800),
                  const SizedBox(height: 20),
                  
                  Text(
                    'Sync Progress',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Simple sync status
                  Center(
                    child: Text(
                      walletProvider.isSyncing ? 'Syncing with blockchain...' : 'Sync complete',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                ],
                
                const SizedBox(height: 20),
                Divider(color: Colors.grey.shade800),
                const SizedBox(height: 20),
                
                // Wallet Info
                Text(
                  'Wallet Information',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                
                // Last Sync
                _buildDetailRow(
                  context,
                  icon: Icons.access_time,
                  label: 'Last Sync',
                  value: walletProvider.lastSyncTime != null
                    ? _formatLastSync(walletProvider.lastSyncTime!)
                    : 'Just now',
                ),
                
                const SizedBox(height: 24),
                
                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (!walletProvider.isSyncing) ...[
                      Container(
                        height: 36,
                        child: TextButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            walletProvider.syncWallet();
                          },
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('Force Sync'),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFFD2691E),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Container(
                      height: 36,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD2691E),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                        ),
                        child: const Text('Close'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: Colors.white.withOpacity(0.6),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.white70,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: valueColor ?? Colors.white,
          ),
        ),
      ],
    );
  }

  String _formatLastSync(DateTime lastSync) {
    final now = DateTime.now();
    final difference = now.difference(lastSync);
    
    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    }
  }
}