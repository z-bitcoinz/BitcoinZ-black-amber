import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/wallet_provider.dart';

/// Detailed sync information dialog
class SyncDetailsDialog extends StatelessWidget {
  const SyncDetailsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<WalletProvider>(
      builder: (context, provider, child) {
        final theme = Theme.of(context);
        
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.sync_alt,
                      color: theme.colorScheme.primary,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Sync Details',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                
                // Connection Status
                _buildDetailRow(
                  context,
                  icon: Icons.wifi,
                  label: 'Connection',
                  value: provider.isConnected ? 'Connected' : 'Disconnected',
                  valueColor: provider.isConnected ? Colors.green : Colors.red,
                ),
                const SizedBox(height: 12),
                
                // Server
                _buildDetailRow(
                  context,
                  icon: Icons.dns,
                  label: 'Server',
                  value: 'lightd.btcz.rocks:9067',
                ),
                const SizedBox(height: 12),
                
                // Sync Status
                _buildDetailRow(
                  context,
                  icon: Icons.sync,
                  label: 'Status',
                  value: provider.isSyncing 
                    ? 'Syncing (${provider.syncProgress.toStringAsFixed(1)}%)'
                    : 'Idle',
                  valueColor: provider.isSyncing ? Colors.blue : null,
                ),
                
                if (provider.isSyncing || provider.syncedBlocks > 0) ...[
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 20),
                  
                  Text(
                    'Sync Progress',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Progress Bar
                  if (provider.syncProgress > 0) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: provider.syncProgress / 100,
                        minHeight: 8,
                        backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        '${provider.syncProgress.toStringAsFixed(1)}%',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  
                  // Batch Info
                  if (provider.batchTotal > 0) ...[
                    _buildDetailRow(
                      context,
                      icon: Icons.layers,
                      label: 'Batch',
                      value: '${provider.batchNum} of ${provider.batchTotal}',
                    ),
                    const SizedBox(height: 12),
                  ],
                  
                  // Blocks Info
                  if (provider.totalBlocks > 0) ...[
                    _buildDetailRow(
                      context,
                      icon: Icons.grid_view,
                      label: 'Blocks Synced',
                      value: '${NumberFormat('#,###').format(provider.syncedBlocks)} / ${NumberFormat('#,###').format(provider.totalBlocks)}',
                    ),
                    const SizedBox(height: 12),
                  ],
                  
                  // Sync Message
                  if (provider.syncMessage.isNotEmpty) ...[
                    _buildDetailRow(
                      context,
                      icon: Icons.info_outline,
                      label: 'Message',
                      value: provider.syncMessage,
                    ),
                  ],
                ],
                
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 20),
                
                // Wallet Info
                Text(
                  'Wallet Information',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                
                // Last Sync
                _buildDetailRow(
                  context,
                  icon: Icons.access_time,
                  label: 'Last Sync',
                  value: provider.lastSyncTime != null
                    ? _formatLastSync(provider.lastSyncTime!)
                    : 'Never',
                ),
                
                const SizedBox(height: 24),
                
                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (!provider.isSyncing) ...[
                      TextButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          provider.syncWallet();
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Force Sync'),
                        style: TextButton.styleFrom(
                          foregroundColor: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Close'),
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
    final theme = Theme.of(context);
    
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: theme.colorScheme.onSurface.withOpacity(0.6),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: valueColor ?? theme.colorScheme.onSurface,
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