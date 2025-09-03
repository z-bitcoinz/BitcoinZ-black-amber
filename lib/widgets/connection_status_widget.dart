import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/wallet_provider.dart';

/// Widget to show connection and sync status
class ConnectionStatusWidget extends StatefulWidget {
  const ConnectionStatusWidget({super.key});

  @override
  State<ConnectionStatusWidget> createState() => _ConnectionStatusWidgetState();
}

class _ConnectionStatusWidgetState extends State<ConnectionStatusWidget> {
  double _displayedProgress = 0.0; // UI-only monotonic progress tracking

  /// Get monotonic progress for UI display - prevents backwards jumps
  double _getDisplayProgress(WalletProvider provider) {
    final currentProgress = provider.syncProgress;

    // If not syncing, reset displayed progress
    if (!provider.isSyncing) {
      _displayedProgress = currentProgress;
      return currentProgress;
    }

    // Only update displayed progress if it's higher (monotonic)
    if (currentProgress > _displayedProgress) {
      _displayedProgress = currentProgress;
    }

    return _displayedProgress;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WalletProvider>(
      builder: (context, provider, child) {
        final isConnected = provider.isConnected;
        final isSyncing = provider.isSyncing;
        final displayProgress = _getDisplayProgress(provider); // Use monotonic progress
        final currentBatch = provider.currentBatch;
        final totalBatches = provider.totalBatches;
        
        // Determine what to show
        String statusText;
        Color statusColor;
        IconData statusIcon;
        bool showSpinner = false;
        
        if (!isConnected) {
          // Show disconnected status - RED
          statusText = provider.connectionStatus;
          statusColor = Colors.red;
          statusIcon = Icons.wifi_off;
        } else if (isSyncing) {
          // Show sync progress - BLUE (only when actively syncing) with monotonic progress
          if (totalBatches > 0) {
            statusText = 'Syncing ${displayProgress.toStringAsFixed(0)}% (Batch $currentBatch/$totalBatches)';
          } else {
            statusText = 'Syncing ${displayProgress.toStringAsFixed(0)}%';
          }
          statusColor = Colors.blue;
          statusIcon = Icons.sync;
          showSpinner = true;
        } else {
          // Connected and not syncing - GREEN (ready state)
          // Don't show text for ready state - the green check icon is sufficient
          statusText = '';
          statusColor = Colors.green;
          statusIcon = Icons.check_circle;
        }
        
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: statusColor.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showSpinner) ...[
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                  ),
                ),
              ] else ...[
                Icon(
                  statusIcon,
                  size: 16,
                  color: statusColor,
                ),
              ],
              if (statusText.isNotEmpty) ...[
                const SizedBox(width: 6),
                Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],

            ],
          ),
        );
      },
    );
  }
}