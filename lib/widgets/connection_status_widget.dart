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
  String _displayedETA = ''; // UI-only stable ETA tracking
  int _lastETAMinutes = 0; // Track ETA in minutes for monotonic decrease

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

  /// Parse ETA string to minutes for comparison
  int _parseETAToMinutes(String eta) {
    if (eta.isEmpty || eta == 'Calculating...' || eta == 'Almost done') {
      return 0;
    }

    try {
      // Parse formats like "12m remaining", "2h 30m remaining", "1h remaining"
      final RegExp minutesRegex = RegExp(r'(\d+)m');
      final RegExp hoursRegex = RegExp(r'(\d+)h');

      int totalMinutes = 0;

      final hoursMatch = hoursRegex.firstMatch(eta);
      if (hoursMatch != null) {
        totalMinutes += int.parse(hoursMatch.group(1)!) * 60;
      }

      final minutesMatch = minutesRegex.firstMatch(eta);
      if (minutesMatch != null) {
        totalMinutes += int.parse(minutesMatch.group(1)!);
      }

      return totalMinutes;
    } catch (e) {
      return 0;
    }
  }

  /// Get stable ETA for UI display - prevents disappearing and going up
  String _getDisplayETA(WalletProvider provider) {
    final currentETA = provider.syncETA;

    // If not syncing, reset displayed ETA
    if (!provider.isSyncing) {
      _displayedETA = currentETA;
      _lastETAMinutes = 0;
      return currentETA;
    }

    // If current ETA is empty or "Calculating...", keep last valid ETA
    if (currentETA.isEmpty || currentETA == 'Calculating...') {
      return _displayedETA; // Keep showing last valid ETA
    }

    // Parse current ETA to minutes
    final currentMinutes = _parseETAToMinutes(currentETA);

    // If we have no previous ETA, use current one
    if (_displayedETA.isEmpty || _lastETAMinutes == 0) {
      _displayedETA = currentETA;
      _lastETAMinutes = currentMinutes;
      return currentETA;
    }

    // STRICT MONOTONIC DECREASE: Only update if new ETA is LOWER
    if (currentMinutes > 0 && currentMinutes < _lastETAMinutes) {
      _displayedETA = currentETA;
      _lastETAMinutes = currentMinutes;
    }
    // NEVER allow ETA to go up - ignore ALL increases, no matter how small or large
    // This prevents: 8m → 15m, 10m → 12m, etc.
    // Keep showing the lowest ETA we've seen

    return _displayedETA;
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
          // Show sync progress - BLUE (only when actively syncing) with monotonic progress and stable ETA
          final displayETA = _getDisplayETA(provider);

          String baseStatus;
          if (displayProgress > 0) {
            if (totalBatches > 0) {
              baseStatus = 'Syncing ${displayProgress.toStringAsFixed(0)}% (Batch $currentBatch/$totalBatches)';
            } else {
              baseStatus = 'Syncing ${displayProgress.toStringAsFixed(0)}%';
            }
          } else if (totalBatches > 0) {
            // Show batch info when no detailed progress available
            baseStatus = 'Syncing (Batch $currentBatch/$totalBatches)';
          } else {
            baseStatus = 'Syncing';
          }

          // Add stable ETA if available
          if (displayETA.isNotEmpty && displayETA != 'Calculating...') {
            statusText = '$baseStatus • $displayETA';
          } else {
            statusText = baseStatus;
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