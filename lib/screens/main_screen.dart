import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/wallet_provider.dart';
import '../providers/auth_provider.dart';
import 'wallet/wallet_dashboard_screen.dart';
import 'wallet/send_screen_modern.dart';
import 'wallet/receive_screen_modern.dart';
import 'wallet/paginated_transaction_history_screen.dart';
import 'settings/settings_screen.dart';
// import '../demo/cli_demo_page.dart'; // Removed - CLI demo no longer used

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  late PageController _pageController;
  late AnimationController _animationController;

  final List<Widget> _screens = [
    const WalletDashboardScreen(),
    const SendScreenModern(),
    const ReceiveScreenModern(),
    const PaginatedTransactionHistoryScreen(),
    // CliDemoPage(), // Removed - CLI demo no longer used
    const SettingsScreen(),
  ];

  final List<BottomNavigationBarItem> _navItems = [
    const BottomNavigationBarItem(
      icon: Icon(Icons.dashboard),
      activeIcon: Icon(Icons.dashboard),
      label: 'Wallet',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.send),
      activeIcon: Icon(Icons.send),
      label: 'Send',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.qr_code),
      activeIcon: Icon(Icons.qr_code),
      label: 'Receive',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.history),
      activeIcon: Icon(Icons.history),
      label: 'History',
    ),
    // Removed - CLI demo no longer used
    // const BottomNavigationBarItem(
    //   icon: Icon(Icons.terminal),
    //   activeIcon: Icon(Icons.terminal),
    //   label: 'CLI Demo',
    // ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.settings),
      activeIcon: Icon(Icons.settings),
      label: 'Settings',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    // Start initial sync
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeWallet();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _initializeWallet() async {
    try {
      if (kDebugMode) print('🚀 MainScreen._initializeWallet() starting...');
      final walletProvider = Provider.of<WalletProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      // Set the notification context for showing memo notifications
      walletProvider.setNotificationContext(context);
      
      // Check if wallet is already initialized (from PIN setup)
      if (walletProvider.hasWallet) {
        if (kDebugMode) print('   Wallet already loaded, skipping initialization');
        return;
      }
      
      // If we're on MainScreen, user must be authenticated
      // Try to restore wallet from stored data
      bool restored = false;
      if (authProvider.hasWallet) {
        if (kDebugMode) {
          print('   User has wallet, attempting restoration...');
          print('   authProvider.hasWallet: ${authProvider.hasWallet}');
          print('   authProvider.isAuthenticated: ${authProvider.isAuthenticated}');
        }
        restored = await walletProvider.restoreFromStoredData(authProvider);
        if (kDebugMode) print('   Wallet restored: $restored');
      }
      
      // If restoration failed or no stored data, just sync if we have a wallet
      if (!restored && walletProvider.hasWallet) {
        if (kDebugMode) print('   Starting wallet sync...');
        await walletProvider.syncWallet();
      }
    } catch (e) {
      // Handle initialization error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to initialize wallet: $e'),
            backgroundColor: Colors.orange,
            action: SnackBarAction(
              label: 'Retry',
              onPressed: _initializeWallet,
            ),
          ),
        );
      }
    }
  }

  void _onNavItemTapped(int index) {
    if (_currentIndex == index) return;
    
    setState(() {
      _currentIndex = index;
    });
    
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _onPageChanged(int index) {
    if (_currentIndex != index) {
      setState(() {
        _currentIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer2<WalletProvider, AuthProvider>(
        builder: (context, walletProvider, authProvider, child) {
          return PageView(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            children: _screens,
          );
        },
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.surface,
                  Theme.of(context).colorScheme.surface.withOpacity(0.95),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                  width: 0.5,
                ),
              ),
            ),
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: _onNavItemTapped,
              items: _navItems,
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.transparent,
              selectedItemColor: Theme.of(context).colorScheme.primary,
              unselectedItemColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              selectedFontSize: 12,
              unselectedFontSize: 11,
              selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
              elevation: 0,
            ),
          ),
        ),
      ),
    );
  }
}