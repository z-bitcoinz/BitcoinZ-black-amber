import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/wallet_provider.dart';
import '../utils/constants.dart';
import 'onboarding/welcome_screen.dart';
import 'onboarding/pin_setup_screen.dart';
import 'auth/auth_screen.dart';
import 'main_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));

    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Start animations
    _fadeController.forward();
    _scaleController.forward();

    // Initialize providers
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);

    try {
      // Initialize auth provider
      await authProvider.initialize();
      
      // Start background wallet initialization while showing splash
      // This happens in background so wallet syncs during PIN entry
      if (authProvider.hasWallet) {
        if (kDebugMode) {
          print('🔄 Starting background wallet initialization during splash...');
        }
        // Start background initialization (non-blocking)
        walletProvider.startBackgroundInitialization(authProvider).then((_) {
          if (kDebugMode) {
            print('✅ Background initialization started - wallet will sync during PIN entry');
          }
        }).catchError((e) {
          if (kDebugMode) {
            print('⚠️ Background initialization failed (will retry after PIN): $e');
          }
        });
      }
      
      // Wait minimum splash time for better UX
      await Future.delayed(const Duration(milliseconds: 2000));
      
      if (mounted) {
        _navigateToNextScreen(authProvider, walletProvider);
      }
    } catch (e) {
      if (mounted) {
        _showErrorAndRetry(e.toString());
      }
    }
  }

  void _navigateToNextScreen(AuthProvider authProvider, WalletProvider walletProvider) async {
    Widget nextScreen;

    if (kDebugMode) {
      print('🚀 SplashScreen._navigateToNextScreen():');
      print('  hasWallet: ${authProvider.hasWallet}');
      print('  isAuthenticated: ${authProvider.isAuthenticated}');
      print('  needsSetup: ${authProvider.needsSetup}');
      print('  needsAuthentication: ${authProvider.needsAuthentication}');
    }

    if (authProvider.needsSetup) {
      // First time user - show welcome/onboarding
      nextScreen = const WelcomeScreen();
      if (kDebugMode) print('→ Navigating to WelcomeScreen (needsSetup)');
    } else if (authProvider.hasWallet) {
      // Check if PIN is set
      final hasPinSet = await authProvider.hasPinSet;
      if (!hasPinSet) {
        // Wallet exists but no PIN - need to set up PIN
        nextScreen = PinSetupScreen(
          walletId: authProvider.walletId ?? 'wallet_${DateTime.now().millisecondsSinceEpoch}',
          walletData: {
            'migrated': true,
            'created_at': DateTime.now().toIso8601String(),
          },
        );
        if (kDebugMode) print('→ Navigating to PinSetupScreen (wallet exists but no PIN)');
      } else if (authProvider.needsAuthentication) {
        // Returning user with wallet and PIN - show authentication
        nextScreen = const AuthScreen();
        if (kDebugMode) print('→ Navigating to AuthScreen (needsAuthentication)');
      } else if (authProvider.isAuthenticated) {
        // Authenticated user - go to main screen
        nextScreen = const MainScreen();
        if (kDebugMode) print('→ Navigating to MainScreen (isAuthenticated)');
      } else {
        // Has wallet and PIN but not authenticated
        nextScreen = const AuthScreen();
        if (kDebugMode) print('→ Navigating to AuthScreen (has wallet and PIN)');
      }
    } else {
      // Fallback to welcome screen
      nextScreen = const WelcomeScreen();
      if (kDebugMode) print('→ Navigating to WelcomeScreen (fallback)');
    }

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => nextScreen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  void _showErrorAndRetry(String error) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Initialization Error'),
        content: Text('Failed to initialize app: $error'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _initializeApp();
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  /// Debug method to perform complete reset (double-tap logo in debug mode)
  void _performDebugReset() async {
    if (!kDebugMode) return;
    
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.forceCompleteReset();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🧹 Debug Reset Complete - Fresh wallet setup enabled'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
        
        // Restart initialization after reset
        await Future.delayed(const Duration(milliseconds: 500));
        _initializeApp();
      }
    } catch (e) {
      if (mounted && kDebugMode) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Debug Reset Failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      body: Center(
        child: AnimatedBuilder(
          animation: Listenable.merge([_fadeAnimation, _scaleAnimation]),
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // App Logo with debug reset (double tap)
                    GestureDetector(
                      onDoubleTap: kDebugMode ? _performDebugReset : null,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.currency_bitcoin,
                          size: 64,
                          color: Color(0xFF1976D2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    // App Name
                    Text(
                      'BitcoinZ Wallet',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    // App Tagline
                    Text(
                      'Your Private & Secure Wallet',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                    const SizedBox(height: 48),
                    
                    // Loading Indicator
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.white.withOpacity(0.8),
                        ),
                        strokeWidth: 3,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}