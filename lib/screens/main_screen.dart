import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/wallet_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/interface_provider.dart';
import 'wallet/wallet_dashboard_screen.dart';
import 'wallet/send_screen_modern.dart';
import 'wallet/receive_screen_modern.dart';
import 'wallet/paginated_transaction_history_screen.dart';
import 'analytics/financial_analytics_screen.dart';
import 'settings/settings_screen.dart';
import 'contacts/contacts_screen.dart';
import '../providers/contact_provider.dart';

import '../services/send_prefill_bus.dart';
import '../services/battery_optimization_prompt.dart';
// import '../demo/cli_demo_page.dart'; // Removed - CLI demo no longer used

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();

  // Static method to access the current instance
  static _MainScreenState? of(BuildContext context) {
    return context.findAncestorStateOfType<_MainScreenState>();
  }

  // Static navigation key for global access
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  // Static reference to the current MainScreen state
  static _MainScreenState? _currentInstance;

  // Global method to navigate to send with contact
  static void navigateToSendWithContact(String address, String contactName, [String? photo]) {
    print('🎯 MainScreen.navigateToSendWithContact called with: $address, $contactName, photo: ${photo != null ? 'provided' : 'null'}');
    if (_currentInstance != null) {
      print('🎯 MainScreen: Found current instance, calling method');
      _currentInstance!.navigateToSendWithContact(address, contactName, photo);
    } else {
      print('🎯 MainScreen: No current instance found!');
    }
  }

  // Global method to navigate to specific tab (for notifications)
  static void navigateToTab(int tabIndex) {

    if (kDebugMode) print('🔔 MainScreen.navigateToTab called with index: $tabIndex');
    if (_currentInstance != null) {
      _currentInstance!._navigateToTabFromNotification(tabIndex);
    } else {
      if (kDebugMode) print('🔔 MainScreen: No current instance found for tab navigation');
    }
  }
}

class _MainScreenState extends State<MainScreen>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  late PageController _pageController;
  late AnimationController _animationController;

  // Contact data for sending
  String? _prefilledAddress;
  String? _contactName;
  String? _contactPhoto;

  // Pending prefill to publish after switching to the Send tab
  String? _pendingPrefillAddress;
  String? _pendingPrefillName;
  String? _pendingPrefillPhoto;

  List<Widget> _getScreens(bool showAnalytics) {
    final baseScreens = [
      const WalletDashboardScreen(),
      SendScreenModern(
        key: ValueKey('send_${_prefilledAddress ?? 'empty'}_${_contactName ?? 'none'}'),
        prefilledAddress: _prefilledAddress,
        contactName: _contactName,
        contactPhoto: _contactPhoto,
      ),
      const ReceiveScreenModern(),
      const PaginatedTransactionHistoryScreen(),
    ];

    if (showAnalytics) {
      baseScreens.add(const FinancialAnalyticsScreen());
    }

    baseScreens.add(ContactsScreen(
      onSendToContact: (address, name, photo) => navigateToSendWithContact(address, name, photo),
    ));

    return baseScreens;
  }

  List<BottomNavigationBarItem> _getNavItems(bool showAnalytics) {
    final baseItems = [
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
    ];

    if (showAnalytics) {
      baseItems.add(const BottomNavigationBarItem(
        icon: Icon(Icons.analytics),
        activeIcon: Icon(Icons.analytics),
        label: 'Analytics',
      ));
    }

    baseItems.add(const BottomNavigationBarItem(
      icon: Icon(Icons.contacts),
      activeIcon: Icon(Icons.contacts),
      label: 'Contacts',
    ));

    return baseItems;
  }

  @override
  void initState() {
    super.initState();
    MainScreen._currentInstance = this; // Set static reference
    _pageController = PageController(initialPage: _currentIndex);
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    // Start initial sync and initialize contacts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeWallet();
      _initializeContacts();
      // Prompt Android users to disable battery optimization
      BatteryOptimizationPrompt.maybePrompt(context);
    });
  }

  @override
  void dispose() {
    MainScreen._currentInstance = null; // Clear static reference
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

      // Check if wallet is already initialized (from PIN setup or background initialization)
      if (walletProvider.hasWallet) {
        if (kDebugMode) print('   Wallet already loaded, skipping initialization');
        return;
      }

      // Check if background initialization is in progress
      if (walletProvider.isLoading) {
        if (kDebugMode) print('   Background initialization in progress, waiting...');
        // Wait a moment for background initialization to complete
        await Future.delayed(const Duration(milliseconds: 500));
        // Check again after waiting
        if (walletProvider.hasWallet) {
          if (kDebugMode) print('   ✅ Background initialization completed successfully');
          return;
        }
        if (kDebugMode) print('   Background initialization still in progress, continuing with restoration...');
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

  Future<void> _initializeContacts() async {
    try {
      final contactProvider = Provider.of<ContactProvider>(context, listen: false);
      await contactProvider.loadContacts();
      if (kDebugMode) print('✅ MainScreen: Contacts initialized');
    } catch (e) {
      if (kDebugMode) print('⚠️ MainScreen: Contact initialization failed: $e');
    }
  }

  void _navigateToSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SettingsScreen(),
      ),
    );
  }

  // Public method for external navigation calls
  void onNavItemTapped(int index) {
    final interfaceProvider = Provider.of<InterfaceProvider>(context, listen: false);
    final showAnalytics = interfaceProvider.analyticsTabVisible;
    _onNavItemTapped(index, showAnalytics);
  }

  void _onNavItemTapped(int index, bool showAnalytics) {
    if (_currentIndex == index) return;

    // Clear contact data when navigating away from send tab
    if (_currentIndex == 1 && index != 1) {
      clearContactData();
    }

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
      // Clear contact data when navigating away from send tab
      if (_currentIndex == 1 && index != 1) {
        clearContactData();
      }

      setState(() {
        _currentIndex = index;
      });
    }
  }

  // Method to navigate to send tab with contact data
  void navigateToSendWithContact(String address, String contactName, [String? photo]) {
    print('🎯 MainScreen.navigateToSendWithContact (instance method) called');
    print('🎯 MainScreen: Setting _prefilledAddress = $address');
    print('🎯 MainScreen: Setting _contactName = $contactName');
    print('🎯 MainScreen: Setting _contactPhoto = ${photo != null ? 'provided' : 'null'}');
    print('🎯 MainScreen: Current _currentIndex = $_currentIndex');

    // Defer publishing to the bus until after we've switched to the Send tab
    _pendingPrefillAddress = address;
    _pendingPrefillName = contactName;
    _pendingPrefillPhoto = photo;

    setState(() {
      _prefilledAddress = address;
      _contactName = contactName;
      _contactPhoto = photo;
      // Set the current index in the same setState to avoid double rebuilds
      if (_currentIndex != 1) {
        print('🎯 MainScreen: Changing _currentIndex from $_currentIndex to 1');
        _currentIndex = 1;
      } else {
        print('🎯 MainScreen: Already on send tab (index 1)');
      }
    });

    print('🎯 MainScreen: setState completed, _prefilledAddress = $_prefilledAddress, _contactName = $_contactName, _contactPhoto = ${_contactPhoto != null ? 'provided' : 'null'}');

    // Use post-frame callback to ensure PageView is rebuilt with new key
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Navigate to send tab (index 1) after the PageView is rebuilt
      if (_pageController.hasClients && _currentIndex == 1) {
        _pageController.animateToPage(
          1,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );

        // Now that we've navigated to the Send tab, publish the prefill
        if (_pendingPrefillAddress != null) {
          SendPrefillBus.set(_pendingPrefillAddress!, _pendingPrefillName, _pendingPrefillPhoto);
          _pendingPrefillAddress = null;
          _pendingPrefillName = null;
          _pendingPrefillPhoto = null;
        }
      }
    });
  }

  // Method to clear contact data
  void clearContactData() {
    // Do not clear the bus here; allow the Send screen to consume existing prefill.
    setState(() {
      _prefilledAddress = null;
      _contactName = null;
    });
  }

  // Method to navigate to tab from notification
  void _navigateToTabFromNotification(int tabIndex) {
    if (kDebugMode) print('🔔 Navigating to tab from notification: $tabIndex');

    // Get the interface provider to check if analytics tab is visible
    final interfaceProvider = Provider.of<InterfaceProvider>(context, listen: false);
    final showAnalytics = interfaceProvider.analyticsTabVisible;
    final maxTabIndex = showAnalytics ? 5 : 4; // 0-4 without analytics, 0-5 with analytics

    // Validate tab index
    if (tabIndex < 0 || tabIndex > maxTabIndex) {
      if (kDebugMode) print('⚠️ Invalid tab index: $tabIndex (max: $maxTabIndex)');
      tabIndex = 0; // Default to dashboard
    }

    // Adjust tab index if analytics is hidden and we're trying to navigate to contacts
    if (!showAnalytics && tabIndex == 5) {
      tabIndex = 4; // Contacts becomes index 4 when analytics is hidden
    }

    // Clear contact data when navigating away from send tab
    if (_currentIndex == 1 && tabIndex != 1) {
      clearContactData();
    }

    setState(() {
      _currentIndex = tabIndex;
    });

    // Animate to the new page
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        tabIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<InterfaceProvider>(
      builder: (context, interfaceProvider, child) {
        final showAnalytics = interfaceProvider.analyticsTabVisible;
        final screens = _getScreens(showAnalytics);
        final navItems = _getNavItems(showAnalytics);

        // Adjust current index if analytics tab is hidden and we're on it or beyond
        int adjustedIndex = _currentIndex;
        if (!showAnalytics && _currentIndex >= 4) {
          // If analytics tab is hidden and we're on analytics (4) or contacts (5),
          // move to contacts (which becomes index 4)
          adjustedIndex = _currentIndex == 4 ? 4 : _currentIndex - 1;
          if (adjustedIndex != _currentIndex) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              setState(() {
                _currentIndex = adjustedIndex;
              });
              _pageController.animateToPage(
                adjustedIndex,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            });
          }
        }

        return Scaffold(
          body: Consumer2<WalletProvider, AuthProvider>(
            builder: (context, walletProvider, authProvider, child) {
              return PageView(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                children: screens,
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
              borderRadius: BorderRadius.zero,
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
                  currentIndex: adjustedIndex,
                  onTap: (index) => _onNavItemTapped(index, showAnalytics),
                  items: navItems,
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
      },
    );
  }
}