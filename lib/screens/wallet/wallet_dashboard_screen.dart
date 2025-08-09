import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:ui';
import '../../providers/wallet_provider.dart';
import '../../widgets/balance_card.dart';
import '../../widgets/recent_transactions.dart';
import 'paginated_transaction_history_screen.dart';

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
    
    // Initial sync
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _silentSync();
    });
  }

  @override
  void dispose() {
    _connectionPulseController.dispose();
    _autoSyncTimer?.cancel();
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
    
    // Start pulse animation during sync
    if (!_connectionPulseController.isAnimating) {
      _connectionPulseController.repeat(reverse: true);
    }
    
    try {
      await walletProvider.syncWallet();
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
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Connection Details',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              _buildInfoRow(
                context,
                'Status',
                walletProvider.isConnected ? 'Connected' : 'Disconnected',
                walletProvider.isConnected ? Colors.green : Colors.red,
              ),
              const SizedBox(height: 12),
              
              _buildInfoRow(
                context,
                'Server',
                'lightd.btcz.rocks:9067',
                null,
              ),
              const SizedBox(height: 12),
              
              _buildInfoRow(
                context,
                'Network',
                'Mainnet',
                null,
              ),
              const SizedBox(height: 12),
              
              if (walletProvider.lastConnectionCheck != null) ...[
                _buildInfoRow(
                  context,
                  'Last Sync',
                  _formatTime(walletProvider.lastConnectionCheck!),
                  null,
                ),
                const SizedBox(height: 12),
              ],
              
              _buildInfoRow(
                context,
                'Auto-sync',
                'Every ${_autoSyncInterval.inSeconds} seconds',
                Colors.blue,
              ),
              
              const SizedBox(height: 20),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _silentSync();
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Sync Now'),
                ),
              ),
            ],
          ),
        ),
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

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: AppBar(
              backgroundColor: const Color(0xFF1A1A1A).withOpacity(0.8),
              elevation: 0,
              toolbarHeight: 60,
              automaticallyImplyLeading: false,
              flexibleSpace: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF1F1F1F).withOpacity(0.8),
                      const Color(0xFF151515).withOpacity(0.6),
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
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.primary,
                          Theme.of(context).colorScheme.primary.withOpacity(0.7),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        'Z',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'BitcoinZ',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
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
                        width: 40,
                        height: 40,
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
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: walletProvider.isConnected
                                    ? (isSyncing ? Colors.blue : Colors.green)
                                    : Colors.red,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: (walletProvider.isConnected
                                        ? (isSyncing ? Colors.blue : Colors.green)
                                        : Colors.red).withOpacity(0.4),
                                    blurRadius: 8,
                                    spreadRadius: 2,
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
                // Spacing for extended AppBar
                const SliverToBoxAdapter(
                  child: SizedBox(height: 60),
                ),
                // Balance Card
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    child: const BalanceCard(),
                  ),
                ),
                
                // Recent Transactions Header and List combined
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          height: 30,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                'Recent Activity',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              TextButton(
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: () {
                                  // Navigate to full transaction history
                                  DefaultTabController.of(context)?.animateTo(3);
                                },
                                child: const Text('View All'),
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