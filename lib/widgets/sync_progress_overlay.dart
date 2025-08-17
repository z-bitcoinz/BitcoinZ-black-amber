import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/wallet_provider.dart';

/// Sync progress overlay that displays like BitcoinZ Blue wallet
class SyncProgressOverlay extends StatelessWidget {
  const SyncProgressOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<WalletProvider>(
      builder: (context, provider, child) {
        // Debug: Log sync status
        if (kDebugMode && provider.isSyncing) {
          print('🔄 SyncProgressOverlay: Syncing = true, batch ${provider.batchNum}/${provider.batchTotal}, blocks ${provider.syncedBlocks}/${provider.totalBlocks}');
        }
        
        if (!provider.isSyncing) {
          return const SizedBox.shrink();
        }

        return Container(
          color: Colors.black54,
          child: Center(
            child: Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).dialogBackgroundColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title (BitcoinZ Blue style)
                  if (provider.batchTotal > 0) ...[
                    Text(
                      'Syncing batch ${provider.batchNum} of ${provider.batchTotal}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  
                  // Batch progress text (BitcoinZ Blue format)
                  if (provider.totalBlocks > 0) ...[
                    Text(
                      'Batch Progress: ${((provider.syncedBlocks * 100.0) / provider.totalBlocks).toStringAsFixed(2)}%. Total progress: ${provider.syncProgress.toStringAsFixed(2)}%.',
                      style: Theme.of(context).textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                  ],
                  
                  // Progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: provider.syncProgress / 100,
                      minHeight: 20,
                      backgroundColor: Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Block numbers  
                  if (provider.totalBlocks > 0) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Blocks: ${provider.syncedBlocks} / ${provider.totalBlocks}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  
                  // Spinning indicator
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Status message (BitcoinZ Blue style)
                  Text(
                    'Light wallet sync in progress... Usually takes just a few minutes',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}