import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:ui';
import '../../providers/wallet_provider.dart';
import '../../providers/network_provider.dart';
import '../../widgets/balance_card.dart';
import '../../widgets/recent_transactions.dart';
import '../../widgets/connection_status_widget.dart';
import '../../widgets/sync_status_card.dart';
import '../main_screen.dart';
import 'paginated_transaction_history_screen.dart';
import '../settings/network_settings_screen.dart';

class WalletDashboardScreen extends StatefulWidget {
  const WalletDashboardScreen({super.key});

  @override
  State<WalletDashboardScreen> createState() => _WalletDashboardScreenState();
}

class _WalletDashboardScreenState extends State<WalletDashboardScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late AnimationController _connectionPulseController;
  late Animation<double> _connectionPulseAnimation;
  Timer? _autoSyncTimer;
  Timer? _connectionCheckTimer;
  
  // Auto-sync interval (default 30 seconds)
  static const Duration _autoSyncInterval = Duration(seconds: 30);

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    
    _connectionPulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _connectionPulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.3,
    ).animate(CurvedAnimation(
      parent: _connectionPulseController,
      curve: Curves.easeInOut,
    ));
    
    // Start auto-sync
    _startAutoSync();
    
    // Initial sync and connection check (parallel for better performance)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final walletProvider = Provider.of<WalletProvider>(context, listen: false);
      
      // Run sync and connection check in parallel for faster loading
      await Future.wait([
        _silentSync(),
        walletProvider.checkConnectionStatus(),
      ]);
      
      // Start periodic connection checks every 5 seconds
      _connectionCheckTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
        await walletProvider.checkConnectionStatus();
      });
    });
  }

  @override
  void dispose() {
    _connectionPulseController.dispose();
    _autoSyncTimer?.cancel();
    _connectionCheckTimer?.cancel();
    super.dispose();
  }
  
  void _startAutoSync() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = Timer.periodic(_autoSyncInterval, (_) {
      _silentSync();
    });
  }
  
  Future<void> _silentSync() async {
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    
    // Don't sync if disconnected - prevents auto-sync when offline
    if (!walletProvider.isConnected) {
      return;
    }
    
    // Start pulse animation during sync
    if (!_connectionPulseController.isAnimating) {
      _connectionPulseController.repeat(reverse: true);
    }
    
    try {
      // Use syncWalletInBackground to show sync UI
      await walletProvider.syncWalletInBackground();
    } catch (e) {
      // Silent fail - no user notification for auto-sync
    } finally {
      _connectionPulseController.reset();
    }
  }
  
  void _showUnreadMemos() {
    // Navigate to transaction history filtered by unread memos
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PaginatedTransactionHistoryScreen(),
        settings: const RouteSettings(
          arguments: {'filterUnreadMemos': true},
        ),
      ),
    );
  }
  
  void _showServerInfo() {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (context) => Consumer2<WalletProvider, NetworkProvider>(
        builder: (context, walletProvider, networkProvider, child) {
          final serverInfo = networkProvider.currentServerInfo;
          final isConnected = walletProvider.isConnected;
          
          return Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Stack(
                children: [
                  // Simple black background
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      color: Colors.black,
                      border: Border.all(
                        color: Colors.grey.shade800,
                        width: 1,
                      ),
                    ),
                    padding: const EdgeInsets.all(28),
                    child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Header with title and close button
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Connection Details',
                                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close, color: Colors.white70),
                                    onPressed: () => Navigator.of(context).pop(),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                  ),
                                ],
                              ),
                              
                              const SizedBox(height: 24),
                              
                              // Status Card
                              _buildStatusCard(context, isConnected, walletProvider.connectionStatus),
                              
                              const SizedBox(height: 12),
                              
                              // Server Information
                              _buildInfoCard(
                                context,
                                'Server Information',
                                [
                                  if (serverInfo?.name != null)
                                    _InfoItem(
                                      icon: Icons.dns,
                                      label: 'Server',
                                      value: serverInfo!.displayName,
                                    ),
                                  _InfoItem(
                                    icon: Icons.public,
                                    label: 'Network',
                                    value: serverInfo?.chainName == 'main' ? 'Mainnet' : 'Testnet',
                                  ),
                                  if (serverInfo?.version != null)
                                    _InfoItem(
                                      icon: Icons.info_outline,
                                      label: 'Version',
                                      value: serverInfo!.version ?? 'Unknown',
                                    ),
                                ],
                              ),
                              
                              const SizedBox(height: 8),
                              
                              // Blockchain Information
                              _buildInfoCard(
                                context,
                                'Blockchain Status',
                                [
                                  if (serverInfo?.latestBlockHeight != null)
                                    _InfoItem(
                                      icon: Icons.layers,
                                      label: 'Block Height',
                                      value: '#${serverInfo!.latestBlockHeight!.toString()}',
                                      valueColor: const Color(0xFFFFB800),
                                    ),
                                  if (walletProvider.lastConnectionCheck != null)
                                    _InfoItem(
                                      icon: Icons.access_time,
                                      label: 'Last Sync',
                                      value: _formatTime(walletProvider.lastConnectionCheck!),
                                    ),
                                  _InfoItem(
                                    icon: Icons.autorenew,
                                    label: 'Auto-sync',
                                    value: 'Every ${_autoSyncInterval.inSeconds}s',
                                    valueColor: Colors.blue,
                                  ),
                                ],
                              ),
                              
                              const SizedBox(height: 24),
                              
                              // Action Buttons
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildActionButton(
                                      context,
                                      'Settings',
                                      Icons.settings,
                                      Colors.grey.withOpacity(0.2),
                                      () {
                                        Navigator.of(context).pop();
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (context) => const NetworkSettingsScreen(),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _buildActionButton(
                                      context,
                                      'Sync Now',
                                      Icons.sync,
                                      Colors.grey.withOpacity(0.2),
                                      () {
                                        Navigator.of(context).pop();
                                        _silentSync();
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildInfoRow(BuildContext context, String label, String value, Color? valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: valueColor ?? Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
  
  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);
    
    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    } else {
      return number.toString();
    }
  }

  Widget _buildStatusCard(BuildContext context, bool isConnected, String connectionStatus) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: isConnected 
            ? const Color(0xFF1C1C1C) 
            : const Color(0xFF1C1C1C),
        border: Border.all(
          color: Colors.grey.shade800,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isConnected ? Colors.green : Colors.red,
              boxShadow: [
                BoxShadow(
                  color: (isConnected ? Colors.green : Colors.red).withOpacity(0.5),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isConnected ? 'Connected' : 'Disconnected',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isConnected ? Colors.green : Colors.red,
                ),
              ),
              Text(
                _getConnectionStatusMessage(isConnected, connectionStatus),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, String title, List<_InfoItem> items) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFF1C1C1C),
        border: Border.all(
          color: Colors.grey.shade800,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 10),
          ...items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return Column(
              children: [
                _buildInfoItem(context, item),
                if (index < items.length - 1) const SizedBox(height: 6),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildInfoItem(BuildContext context, _InfoItem item) {
    return GestureDetector(
      onTap: item.copyable ? () => _copyToClipboard(item.copyValue ?? item.value) : null,
      child: Row(
        children: [
          Icon(
            item.icon,
            size: 14,
            color: Colors.white.withOpacity(0.6),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              item.label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                item.value,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: item.valueColor ?? Colors.white,
                ),
              ),
              if (item.copyable) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.copy,
                  size: 12,
                  color: Colors.white.withOpacity(0.5),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactInfoCard(BuildContext context, String title, List<_InfoItem> items) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFF1C1C1C),
        border: Border.all(
          color: Colors.grey.shade800,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 10),
          // Group items into rows of 2
          for (int i = 0; i < items.length; i += 2) ...[
            Row(
              children: [
                Expanded(
                  child: _buildCompactInfoItem(context, items[i]),
                ),
                if (i + 1 < items.length) ...[
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildCompactInfoItem(context, items[i + 1]),
                  ),
                ],
              ],
            ),
            if (i + 2 < items.length) const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }

  Widget _buildCompactInfoItem(BuildContext context, _InfoItem item) {
    return GestureDetector(
      onTap: item.copyable ? () => _copyToClipboard(item.copyValue ?? item.value) : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            item.icon,
            size: 12,
            color: Colors.white.withOpacity(0.6),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              '${item.label}: ${item.value}',
              style: TextStyle(
                fontSize: 10,
                color: item.valueColor ?? Colors.white.withOpacity(0.8),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (item.copyable) ...[
            const SizedBox(width: 2),
            Icon(
              Icons.copy,
              size: 10,
              color: Colors.white.withOpacity(0.5),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMixedInfoCard(BuildContext context, String title, List<_InfoItem> items, {List<int> singleLineItems = const []}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFF1C1C1C),
        border: Border.all(
          color: Colors.grey.shade800,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 10),
          ...items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            
            // Check if this item should be on its own line
            if (singleLineItems.contains(index)) {
              return Column(
                children: [
                  _buildInfoItem(context, item),
                  if (index < items.length - 1) const SizedBox(height: 6),
                ],
              );
            }
            
            // Skip if this item will be paired with the previous one
            if (index > 0 && !singleLineItems.contains(index - 1) && !singleLineItems.contains(index) && index % 2 == 1) {
              return const SizedBox.shrink();
            }
            
            // Check if next item exists and should be paired
            final nextIndex = index + 1;
            if (nextIndex < items.length && 
                !singleLineItems.contains(index) && 
                !singleLineItems.contains(nextIndex)) {
              // Pair this item with the next one
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildCompactInfoItem(context, item),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildCompactInfoItem(context, items[nextIndex]),
                      ),
                    ],
                  ),
                  if (nextIndex < items.length - 1) const SizedBox(height: 6),
                ],
              );
            }
            
            // Single item that doesn't get paired
            return Column(
              children: [
                _buildCompactInfoItem(context, item),
                if (index < items.length - 1) const SizedBox(height: 6),
              ],
            );
          }),
        ],
      ),
    );
  }

  /// Get user-friendly connection status message
  String _getConnectionStatusMessage(bool isConnected, String connectionStatus) {
    if (isConnected) {
      return 'Wallet is synced';
    }
    
    // Provide user-friendly messages for different disconnection reasons
    switch (connectionStatus) {
      case 'No internet connection':
        return 'Check your internet connection';
      case 'Connection timeout':
        return 'Connection timed out';
      case 'Connection error':
        return 'Unable to connect to network';
      case 'Loading...':
        return 'Initializing wallet...';
      case 'Not initialized':
        return 'Connecting to network...';
      case 'No wallet':
        return 'No wallet found';
      default:
        return 'Connection failed';
    }
  }

  Widget _buildActionButton(
    BuildContext context,
    String title,
    IconData icon,
    Color backgroundColor,
    VoidCallback onPressed,
  ) {
    return Container(
      height: 48,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: Colors.white.withOpacity(0.1),
              width: 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied to clipboard: $text'),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: AppBar(
              backgroundColor: const Color(0xFF1A1A1A).withOpacity(0.95),
              elevation: 0,
              toolbarHeight: 60,
              automaticallyImplyLeading: false,
              flexibleSpace: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF2A2A2A).withOpacity(0.9),
                      const Color(0xFF1A1A1A).withOpacity(0.8),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.white.withOpacity(0.05),
                      width: 1,
                    ),
                  ),
                ),
              ),
              title: Row(
                children: [
                  // BitcoinZ Logo
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF6B00).withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset(
                        'assets/images/bitcoinz_logo.png',
                        width: 36,
                        height: 36,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          // Fallback to original logo if image fails to load
                          return Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFFFF6B00),
                                  Color(0xFFFFAA00),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.currency_bitcoin,
                                color: Colors.black87,
                                size: 20,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      children: [
                        const TextSpan(
                          text: 'Bitcoin',
                          style: TextStyle(color: Colors.white),
                        ),
                        TextSpan(
                          text: 'Z',
                          style: TextStyle(
                            color: const Color(0xFFFF6B00),
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            shadows: [
                              Shadow(
                                color: const Color(0xFFFF6B00).withOpacity(0.5),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                ],
              ),
              actions: [
          // Message notification indicator
          Consumer<WalletProvider>(
            builder: (context, walletProvider, child) {
              final unreadCount = walletProvider.unreadMemoCount;
              if (unreadCount > 0) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      IconButton(
                        icon: Container(
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                                blurRadius: 8,
                                spreadRadius: 1,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.mail,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        onPressed: _showUnreadMemos,
                      ),
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 12,
                            minHeight: 12,
                          ),
                          child: Text(
                            unreadCount > 99 ? '99+' : unreadCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          // Connection status indicator
          Consumer<WalletProvider>(
            builder: (context, walletProvider, child) {
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: GestureDetector(
                  onTap: _showServerInfo,
                  child: AnimatedBuilder(
                    animation: _connectionPulseAnimation,
                    builder: (context, child) {
                      final bool isSyncing = walletProvider.isSyncing || 
                                            _connectionPulseController.isAnimating;
                      
                      return Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: walletProvider.isConnected
                              ? (isSyncing 
                                  ? Colors.blue.withOpacity(0.1)
                                  : Colors.green.withOpacity(0.1))
                              : Colors.red.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Transform.scale(
                            scale: isSyncing ? _connectionPulseAnimation.value : 1.0,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: walletProvider.isConnected
                                    ? (isSyncing ? Colors.blue : Colors.green)
                                    : Colors.red,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: (walletProvider.isConnected
                                        ? (isSyncing ? Colors.blue : Colors.green)
                                        : Colors.red).withOpacity(0.3),
                                    blurRadius: 4,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ],
            ),
          ),
        ),
      ),
      body: Consumer<WalletProvider>(
        builder: (context, walletProvider, child) {
          return RefreshIndicator(
            onRefresh: _silentSync,
            color: Theme.of(context).colorScheme.primary,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // Top spacing for clean separation from header
                const SliverToBoxAdapter(
                  child: SizedBox(height: 24),
                ),
                // Balance Card with enhanced spacing
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                    child: const BalanceCard(),
                  ),
                ),
                
                // Sync Status Card (shows when syncing or recently synced)
                const SliverToBoxAdapter(
                  child: SyncStatusCard(),
                ),
                
                // Recent Activity Section with enhanced spacing
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Section header with improved styling
                        Container(
                          height: 32,
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                'Recent Activity',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  fontSize: 18,
                                ),
                              ),
                              TextButton(
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  backgroundColor: Colors.white.withOpacity(0.05),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: () {
                                  // Navigate to History tab (index 3) in bottom navigation
                                  final mainScreen = MainScreen.of(context);
                                  if (mainScreen != null) {
                                    mainScreen.onNavItemTapped(3);
                                  }
                                },
                                child: Text(
                                  'View All',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const RecentTransactions(limit: 5),
                      ],
                    ),
                  ),
                ),
                
                // Bottom spacing
                const SliverToBoxAdapter(
                  child: SizedBox(height: 100),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _InfoItem {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final bool copyable;
  final String? copyValue;

  const _InfoItem({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.copyable = false,
    this.copyValue,
  });
}