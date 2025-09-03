import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/wallet_provider.dart';

/// Simple sync progress bar exactly like BitcoinZ Blue
class SyncProgressOverlay extends StatelessWidget {
  const SyncProgressOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<WalletProvider>(
      builder: (context, provider, child) {
        // Only show during sync
        if (!provider.isSyncing) {
          return const SizedBox.shrink();
        }

        // Simple progress bar with actual progress like BitcoinZ Blue
        final double progress = provider.syncProgress / 100.0;

        if (kDebugMode) {
          print('🎯 SyncProgressOverlay: Showing ${provider.syncProgress.toStringAsFixed(1)}% progress');
        }

        return Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            height: 3,
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0), // Show actual progress
              backgroundColor: Colors.grey.withOpacity(0.3),
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        );
      },
    );
  }
}