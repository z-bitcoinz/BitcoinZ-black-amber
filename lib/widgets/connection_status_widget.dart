import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/wallet_provider.dart';

/// Widget to show connection and sync status
class ConnectionStatusWidget extends StatelessWidget {
  const ConnectionStatusWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<WalletProvider>(
      builder: (context, provider, child) {
        final isConnected = provider.isConnected;
        final isSyncing = provider.isSyncing;
        final syncProgress = provider.syncProgress;
        final batchNum = provider.batchNum;
        final batchTotal = provider.batchTotal;
        
        // Determine what to show
        String statusText;
        Color statusColor;
        IconData statusIcon;
        bool showSpinner = false;
        
        if (isSyncing && syncProgress < 100) {
          // Show sync progress inline (not as overlay)
          if (batchTotal > 0) {
            statusText = 'Batch ${batchNum}/${batchTotal}';
          } else {
            statusText = 'Syncing';
          }
          statusColor = Colors.blue;
          statusIcon = Icons.sync;
          showSpinner = true;
        } else if (!isConnected) {
          // Show disconnected status
          statusText = provider.connectionStatus;
          statusColor = Colors.orange;
          statusIcon = Icons.wifi_off;
        } else {
          // Connected and not syncing - hide widget
          return const SizedBox.shrink();
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
              const SizedBox(width: 6),
              Text(
                statusText,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (isSyncing && syncProgress > 0) ...[
                const SizedBox(width: 4),
                Text(
                  '${syncProgress.toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 11,
                    color: statusColor.withOpacity(0.8),
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