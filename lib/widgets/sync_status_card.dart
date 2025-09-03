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
      final progress = provider.syncProgress;
      final currentBatch = provider.currentBatch;
      final totalBatches = provider.totalBatches;
      final eta = provider.syncETA;

      if (progress > 0) {
        String status = 'Syncing ${progress.toStringAsFixed(0)}%';

        // Add batch info if available
        if (totalBatches > 0) {
          status += ' (Batch $currentBatch/$totalBatches)';
        }

        // Add ETA if available
        if (eta.isNotEmpty && eta != 'Calculating...') {
          status += ' • $eta';
        }

        return status;
      } else {
        return 'Starting sync...';
      }
    }

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
                                    const SizedBox(height: 4),

                                    // Overall progress bar
                                    Container(
                                      height: 4.0,
                                      decoration: BoxDecoration(
                                        color: Colors.grey[300],
                                        borderRadius: BorderRadius.circular(2.0),
                                      ),
                                      child: FractionallySizedBox(
                                        alignment: Alignment.centerLeft,
                                        widthFactor: (provider.syncProgress / 100.0).clamp(0.0, 1.0),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Colors.blue,
                                            borderRadius: BorderRadius.circular(2.0),
                                          ),
                                        ),
                                      ),
                                    ),

                                    const SizedBox(height: 4),

                                    // Progress details
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '${provider.syncProgress.toStringAsFixed(1)}% complete',
                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                          ),
                                        ),
                                        if (provider.syncETA.isNotEmpty && provider.syncETA != 'Calculating...')
                                          Text(
                                            provider.syncETA,
                                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                            ),
                                          ),
                                      ],
                                    ),

                                    // Batch progress if available
                                    if (provider.totalBatches > 0) ...[
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Text(
                                            'Batch ${provider.currentBatch}/${provider.totalBatches}',
                                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                                              fontSize: 11,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Container(
                                              height: 2.0,
                                              decoration: BoxDecoration(
                                                color: Colors.grey[200],
                                                borderRadius: BorderRadius.circular(1.0),
                                              ),
                                              child: FractionallySizedBox(
                                                alignment: Alignment.centerLeft,
                                                widthFactor: (provider.batchProgress / 100.0).clamp(0.0, 1.0),
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    color: Colors.orange[400],
                                                    borderRadius: BorderRadius.circular(1.0),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            '${provider.batchProgress.toStringAsFixed(0)}%',
                                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
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