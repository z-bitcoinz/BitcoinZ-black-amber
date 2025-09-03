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
          // Show sync progress - BLUE (only when actively syncing)
          statusText = 'Syncing';
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