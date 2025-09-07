import 'dart:async';
import 'package:flutter/foundation.dart';
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
  double _displayedProgress = 0.0; // UI-only monotonic progress tracking
  String _displayedETA = ''; // UI-only stable ETA tracking
  int _lastETAMinutes = 0; // Track ETA in minutes for monotonic decrease

  // Delayed UI display to prevent flickering
  Timer? _showDelayTimer;
  bool _allowSyncUIDisplay = false;
  bool _isAppStartup = true;
  DateTime? _appStartTime;

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

    // Track app startup time for delay logic
    _appStartTime = DateTime.now();
    if (kDebugMode) print('🎯 SYNC UI: App startup detected at $_appStartTime');
  }

  @override
  void dispose() {
    _showDelayTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  /// Start delay timer for sync UI display
  void _startSyncUIDelay() {
    if (_showDelayTimer?.isActive == true) return; // Already running

    const delayDuration = Duration(seconds: 3); // 3 second delay
    if (kDebugMode) print('🎯 SYNC UI: Starting ${delayDuration.inSeconds}s delay timer');

    _showDelayTimer = Timer(delayDuration, () {
      if (mounted) {
        setState(() {
          _allowSyncUIDisplay = true;
          _isAppStartup = false;
        });
        if (kDebugMode) print('🎯 SYNC UI: Delay complete - allowing sync UI display');
      }
    });
  }

  /// Cancel sync UI delay timer
  void _cancelSyncUIDelay() {
    if (_showDelayTimer?.isActive == true) {
      _showDelayTimer!.cancel();
      if (kDebugMode) print('🎯 SYNC UI: Cancelled delay timer');
    }
    _showDelayTimer = null;
  }

  /// Check if we should show sync UI based on delay logic
  bool _shouldShowSyncUI(WalletProvider provider) {
    if (!provider.isSyncing) return false;

    // Check if app has been running for more than 10 seconds (not startup anymore)
    if (_appStartTime != null && DateTime.now().difference(_appStartTime!).inSeconds > 10) {
      _isAppStartup = false;
    }

    // Always show immediately if not during app startup
    if (!_isAppStartup) {
      _allowSyncUIDisplay = true;
      return true;
    }

    // During app startup, check if we have significant sync work
    final blocksRemaining = provider.totalBlocks - provider.syncedBlocks;
    final hasSignificantWork = blocksRemaining > 100 || provider.totalBlocks == 0;

    // If significant work and we haven't started delay timer, start it
    if (hasSignificantWork && !_allowSyncUIDisplay && _showDelayTimer?.isActive != true) {
      _startSyncUIDelay();
    }

    // Only show if delay has completed or if this looks like a restoration
    final isRestorationLike = provider.totalBatches > 0; // Has batch info = restoration
    return _allowSyncUIDisplay || isRestorationLike;
  }

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
      final displayProgress = _getDisplayProgress(provider); // Use monotonic progress
      final displayETA = _getDisplayETA(provider); // Use stable ETA

      if (displayProgress > 0 || provider.totalBatches > 0) {
        // Clean single-line format: "Syncing 47% • 12m remaining"
        String status;

        if (displayProgress > 0) {
          status = 'Syncing ${displayProgress.toStringAsFixed(0)}%';
        } else if (provider.totalBatches > 0) {
          // Show batch info when no detailed progress available
          status = 'Syncing (Batch ${provider.currentBatch}/${provider.totalBatches})';
        } else {
          status = 'Syncing';
        }

        // Add stable ETA if available (only once, here)
        if (displayETA.isNotEmpty && displayETA != 'Calculating...') {
          status += ' • $displayETA';
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
        // Smart sync UI display with delay to prevent flickering
        bool shouldShow = false;

        if (!provider.isConnected) {
          shouldShow = true; // Always show when disconnected
          if (kDebugMode) print('🎯 SYNC UI: Showing - disconnected');
        } else if (provider.isSyncing) {
          // Use delayed display logic for sync UI
          shouldShow = _shouldShowSyncUI(provider);
          if (kDebugMode && shouldShow != provider.isSyncing) {
            print('🎯 SYNC UI: ${shouldShow ? "Showing" : "Hiding"} sync UI (delay logic)');
          }
        } else {
          // Not syncing - cancel any pending delay and reset state
          _cancelSyncUIDelay();
          if (_allowSyncUIDisplay) {
            // Use post-frame callback to avoid setState during build
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _allowSyncUIDisplay = false;
                });
              }
            });
          }
        }

        if (!shouldShow) {
          return const SizedBox.shrink();
        }

        // UI-only: hide the tile during initial "Starting sync..." phase (no progress/batch info)
        if (provider.isSyncing &&
            _getDisplayProgress(provider) <= 0 &&
            provider.totalBatches == 0) {
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
                                  if (provider.isSyncing && (provider.syncProgress > 0 || provider.totalBatches > 0) && provider.syncProgress < 100) ...[
                                    const SizedBox(height: 6),

                                    // LINE 1: Current batch progress (if available)
                                    if (provider.totalBatches > 0) ...[
                                      // Batch info and percentage
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Batch ${provider.currentBatch}/${provider.totalBatches}',
                                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                              fontSize: 12,
                                            ),
                                          ),
                                          Text(
                                            '${provider.batchProgress.toStringAsFixed(0)}%',
                                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),

                                      const SizedBox(height: 3),

                                      // Batch progress bar (orange) - uses raw batch progress
                                      Container(
                                        height: 3.0,
                                        decoration: BoxDecoration(
                                          color: Colors.grey[200],
                                          borderRadius: BorderRadius.circular(1.5),
                                        ),
                                        child: FractionallySizedBox(
                                          alignment: Alignment.centerLeft,
                                          widthFactor: (provider.batchProgress / 100.0).clamp(0.0, 1.0),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: Colors.orange[400],
                                              borderRadius: BorderRadius.circular(1.5),
                                            ),
                                          ),
                                        ),
                                      ),

                                      const SizedBox(height: 8),
                                    ],

                                    // LINE 2: Overall sync progress
                                    // Overall progress percentage (no ETA here - it's in the title)
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Overall Progress',
                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          '${_getDisplayProgress(provider).toStringAsFixed(0)}%', // Use monotonic progress
                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 3),

                                    // Overall progress bar (blue, more prominent) - uses monotonic progress
                                    Container(
                                      height: 4.0,
                                      decoration: BoxDecoration(
                                        color: Colors.grey[300],
                                        borderRadius: BorderRadius.circular(2.0),
                                      ),
                                      child: FractionallySizedBox(
                                        alignment: Alignment.centerLeft,
                                        widthFactor: (_getDisplayProgress(provider) / 100.0).clamp(0.0, 1.0),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Colors.blue,
                                            borderRadius: BorderRadius.circular(2.0),
                                          ),
                                        ),
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