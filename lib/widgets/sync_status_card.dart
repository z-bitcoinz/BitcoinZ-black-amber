import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/wallet_provider.dart';
import 'sync_details_dialog.dart';

/// Enhanced sync status card that's always visible during sync
class SyncStatusCard extends StatefulWidget {
  const SyncStatusCard({super.key});

  @override
  State<SyncStatusCard> createState() => _SyncStatusCardState();
}

class _SyncStatusCardState extends State<SyncStatusCard> 
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Color _getStatusColor(BuildContext context, WalletProvider provider) {
    if (!provider.isConnected) return Colors.red;
    if (provider.isSyncing) return Colors.blue;
    // When connected and not syncing, show green (ready)
    return Colors.green;
  }

  IconData _getStatusIcon(WalletProvider provider) {
    if (!provider.isConnected) return Icons.wifi_off;
    if (provider.isSyncing) return Icons.sync;
    // When connected and not syncing, show check circle (ready)
    return Icons.check_circle;
  }

  String _formatSyncStatus(WalletProvider provider) {
    if (!provider.isConnected) {
      return 'Disconnected';
    }
    
    if (provider.isSyncing) {
      // Use enhanced sync message if available
      if (provider.syncMessage.isNotEmpty) {
        return provider.syncMessage;
      }
      
      // Fallback to batch display if enhanced message not available
      if (provider.batchTotal > 0) {
        return 'Syncing batch ${provider.batchNum}/${provider.batchTotal}';
      }
      if (provider.syncedBlocks > 0 && provider.totalBlocks > 0) {
        return 'Syncing ${provider.syncedBlocks}/${provider.totalBlocks} blocks';
      }
      return 'Syncing...';
    }
    
    // Don't show syncing status if not actually syncing
    return 'Ready';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WalletProvider>(
      builder: (context, provider, child) {
        // Only show when actually syncing or disconnected
        // Don't show "Ready" status - that's already in the header
        bool shouldShow = false;
        
        if (!provider.isConnected) {
          shouldShow = true; // Show when disconnected
        } else if (provider.isSyncing) {
          shouldShow = true; // Show while syncing
        }
        // Removed the "show for 5 seconds after sync" - we don't need to show "Ready"
        
        if (!shouldShow) {
          return const SizedBox.shrink();
        }

        // Start or stop pulse animation based on sync status
        if (provider.isSyncing && !_animationController.isAnimating) {
          _animationController.repeat(reverse: true);
        } else if (!provider.isSyncing && _animationController.isAnimating) {
          _animationController.stop();
          _animationController.reset();
        }

        final statusColor = _getStatusColor(context, provider);
        final statusIcon = _getStatusIcon(provider);
        final statusText = _formatSyncStatus(provider);

        return AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: provider.isSyncing ? _pulseAnimation.value : 1.0,
              child: Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: provider.isSyncing ? 4 : 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: statusColor.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: InkWell(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => const SyncDetailsDialog(),
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: provider.isSyncing
                                  ? SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                                      ),
                                    )
                                  : Icon(
                                      statusIcon,
                                      color: statusColor,
                                      size: 20,
                                    ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    statusText,
                                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: statusColor,
                                    ),
                                  ),
                                  if (provider.isSyncing && provider.syncProgress > 0 && provider.syncProgress < 100) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      '${provider.syncProgress.toStringAsFixed(1)}% complete',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right,
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                            ),
                          ],
                        ),
                        if (provider.isSyncing && provider.syncProgress > 0) ...[
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: provider.syncProgress / 100,
                              minHeight: 6,
                              backgroundColor: statusColor.withOpacity(0.1),
                              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                            ),
                          ),
                          if (provider.syncedBlocks > 0 && provider.totalBlocks > 0) ...[
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Blocks: ${provider.syncedBlocks}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                if (provider.batchTotal > 0)
                                  Text(
                                    'Batch: ${provider.batchNum}/${provider.batchTotal}',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                                    ),
                                  ),
                                Text(
                                  'Total: ${provider.totalBlocks}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}