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
import 'dart:math' as math;

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late AnimationController _zoomController;
  late AnimationController _glowController;
  late AnimationController _rotationController;
  late AnimationController _particleController;
  late AnimationController _progressController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _zoomAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _particleAnimation;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _zoomController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _glowController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );

    _particleController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );

    _progressController = AnimationController(
      duration: const Duration(milliseconds: 1500),
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
      begin: 0.6,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));

    _zoomAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _zoomController,
      curve: Curves.elasticOut,
    ));

    _glowAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _glowController,
      curve: Curves.easeInOut,
    ));

    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _rotationController,
      curve: Curves.linear,
    ));

    _particleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _particleController,
      curve: Curves.easeInOut,
    ));

    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOut,
    ));

    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Start animations in sequence for dramatic effect
    _fadeController.forward();
    _scaleController.forward();
    
    // Start zoom animation with slight delay for dramatic bank-style entrance
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _zoomController.forward();
    });
    
    _glowController.repeat(reverse: true);
    _rotationController.repeat();
    _particleController.repeat();
    _progressController.forward();

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
      
      // Wait minimum splash time for better UX (optimized for faster loading)
      await Future.delayed(const Duration(milliseconds: 1200));
      
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
    _zoomController.dispose();
    _glowController.dispose();
    _rotationController.dispose();
    _particleController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000), // Pure black background
      body: Stack(
        children: [
          // Background gradient effect
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.0,
                colors: [
                  const Color(0xFF1A1A1A),
                  const Color(0xFF000000),
                ],
                stops: const [0.0, 1.0],
              ),
            ),
          ),
          
          // Main content
          Center(
            child: AnimatedBuilder(
              animation: Listenable.merge([
                _fadeAnimation, 
                _scaleAnimation, 
                _zoomAnimation,
                _glowAnimation, 
                _rotationAnimation, 
                _particleAnimation,
                _progressAnimation,
              ]),
              builder: (context, child) {
                return FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Enhanced BitcoinZ Logo with bank-style zoom entrance
                      ScaleTransition(
                        scale: _scaleAnimation,
                        child: ScaleTransition(
                          scale: _zoomAnimation,
                          child: SizedBox(
                            width: 180,
                            height: 180,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Floating particles background - scale with zoom
                                Transform.scale(
                                  scale: 0.5 + (_zoomAnimation.value * 0.5),
                                  child: CustomPaint(
                                    size: const Size(180, 180),
                                    painter: ParticlePainter(_particleAnimation.value * _zoomAnimation.value),
                                  ),
                                ),
                                
                                // Glowing effects - intensify with zoom
                                Transform.scale(
                                  scale: 0.3 + (_zoomAnimation.value * 0.7),
                                  child: CustomPaint(
                                    size: const Size(140, 140),
                                    painter: GlowingLogoPainter(
                                      _glowAnimation.value * _zoomAnimation.value, 
                                      _rotationAnimation.value,
                                    ),
                                  ),
                                ),
                                
                                // Main logo - clean design without amber frame
                                GestureDetector(
                                  onDoubleTap: kDebugMode ? _performDebugReset : null,
                                  child: Container(
                                    width: 140,
                                    height: 140,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(28),
                                      // Removed old amber gradient and border
                                      color: Colors.transparent,
                                      boxShadow: [
                                        // Enhanced shadow that grows with zoom
                                        BoxShadow(
                                          color: Color(0xFFFF6B00).withOpacity(0.3 * _zoomAnimation.value),
                                          blurRadius: 40 + _zoomAnimation.value * 20,
                                          offset: const Offset(0, 12),
                                          spreadRadius: 4 + _zoomAnimation.value * 4,
                                        ),
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.4 * _zoomAnimation.value),
                                          blurRadius: 60,
                                          offset: const Offset(0, 25),
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(28),
                                      child: Container(
                                        padding: const EdgeInsets.all(20),
                                        child: Image.asset(
                                          'assets/images/bitcoinz_logo.png',
                                          width: 100,
                                          height: 100,
                                          fit: BoxFit.contain,
                                          errorBuilder: (context, error, stackTrace) {
                                            return Container(
                                              width: 100,
                                              height: 100,
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: [
                                                    Color(0xFFFF6B00),
                                                    Color(0xFFFFAA00),
                                                  ],
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                ),
                                                borderRadius: BorderRadius.circular(20),
                                              ),
                                              child: const Center(
                                                child: Icon(
                                                  Icons.currency_bitcoin,
                                                  color: Colors.black87,
                                                  size: 56,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 48),
                      
                      // Enhanced App Name with gradient text effect
                      ShaderMask(
                        shaderCallback: (bounds) => LinearGradient(
                          colors: [
                            Colors.white,
                            Color(0xFFFF6B00),
                            Color(0xFFFFAA00),
                            Colors.white,
                          ],
                          stops: const [0.0, 0.3, 0.7, 1.0],
                        ).createShader(bounds),
                        child: RichText(
                          text: TextSpan(
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              foreground: Paint()..color = Colors.white,
                            ),
                            children: [
                              const TextSpan(
                                text: 'Bitcoin',
                              ),
                              TextSpan(
                                text: 'Z',
                                style: TextStyle(
                                  fontSize: 40,
                                  fontWeight: FontWeight.w900,
                                  shadows: [
                                    Shadow(
                                      color: Color(0xFFFF6B00).withOpacity(0.8),
                                      blurRadius: 12 + _glowAnimation.value * 8,
                                      offset: const Offset(0, 3),
                                    ),
                                    Shadow(
                                      color: Color(0xFFFFAA00).withOpacity(0.6),
                                      blurRadius: 6,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Enhanced Professional Tagline
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildTaglineText('Decentralized'),
                          _buildTaglineDot(),
                          _buildTaglineText('Private'),
                          _buildTaglineDot(),
                          _buildTaglineText('Secure'),
                        ],
                      ),
                      const SizedBox(height: 64),
                      
                      // Professional Loading Indicator
                      SizedBox(
                        width: 40,
                        height: 40,
                        child: CustomPaint(
                          painter: ProfessionalProgressPainter(_progressAnimation.value),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaglineText(String text) {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Text(
          text,
          style: TextStyle(
            color: Colors.white.withOpacity(0.85 + _glowAnimation.value * 0.15),
            fontSize: 16,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
            shadows: [
              Shadow(
                color: Color(0xFFFF6B00).withOpacity(0.2 + _glowAnimation.value * 0.2),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTaglineDot() {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          width: 4,
          height: 4,
          decoration: BoxDecoration(
            color: Color(0xFFFF6B00).withOpacity(0.8 + _glowAnimation.value * 0.2),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Color(0xFFFF6B00).withOpacity(0.4 + _glowAnimation.value * 0.3),
                blurRadius: 4,
                offset: const Offset(0, 0),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Custom painter for glowing logo effects
class GlowingLogoPainter extends CustomPainter {
  final double animation;
  final double rotation;

  GlowingLogoPainter(this.animation, this.rotation);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Create multiple glow layers
    for (int i = 0; i < 3; i++) {
      final glowPaint = Paint()
        ..color = Color(0xFFFF6B00).withOpacity(0.1 * animation * (3 - i) / 3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0 + i * 1.0
        ..maskFilter = MaskFilter.blur(BlurStyle.outer, 4.0 + i * 2.0);

      canvas.drawCircle(center, radius + i * 8, glowPaint);
    }

    // Draw rotating light rays
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation * math.pi * 2);

    for (int i = 0; i < 8; i++) {
      final angle = (math.pi * 2 / 8) * i;
      final rayPaint = Paint()
        ..color = Color(0xFFFF6B00).withOpacity(0.15 * animation)
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);

      final startRadius = radius * 0.6;
      final endRadius = radius * 1.3;
      
      canvas.drawLine(
        Offset(math.cos(angle) * startRadius, math.sin(angle) * startRadius),
        Offset(math.cos(angle) * endRadius, math.sin(angle) * endRadius),
        rayPaint,
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is GlowingLogoPainter && 
           (oldDelegate.animation != animation || oldDelegate.rotation != rotation);
  }
}

/// Custom painter for floating particles
class ParticlePainter extends CustomPainter {
  final double animation;

  ParticlePainter(this.animation);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = Color(0xFFFF6B00).withOpacity(0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.0);

    // Draw floating particles
    for (int i = 0; i < 12; i++) {
      final angle = (i * math.pi * 2 / 12) + (animation * math.pi * 2);
      final distance = 80 + (math.sin(animation * math.pi * 3 + i) * 20);
      final particleX = center.dx + math.cos(angle) * distance;
      final particleY = center.dy + math.sin(angle) * distance;
      final particleSize = 2 + math.sin(animation * math.pi * 4 + i) * 1;
      
      canvas.drawCircle(
        Offset(particleX, particleY),
        particleSize,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is ParticlePainter && oldDelegate.animation != animation;
  }
}

/// Custom painter for professional progress ring
class ProfessionalProgressPainter extends CustomPainter {
  final double progress;

  ProfessionalProgressPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;
    
    // Background ring
    final backgroundPaint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    
    canvas.drawCircle(center, radius, backgroundPaint);
    
    // Progress ring with gradient
    final progressPaint = Paint()
      ..shader = SweepGradient(
        colors: [
          Color(0xFFFF6B00),
          Color(0xFFFFAA00),
          Color(0xFFFF6B00).withOpacity(0.8),
        ],
        stops: [0.0, 0.5, 1.0],
        startAngle: -math.pi / 2,
        endAngle: -math.pi / 2 + (progress * 2 * math.pi),
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    
    final sweepAngle = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );

    // Glowing end cap
    if (progress > 0) {
      final endAngle = -math.pi / 2 + sweepAngle;
      final endX = center.dx + math.cos(endAngle) * radius;
      final endY = center.dy + math.sin(endAngle) * radius;
      
      final glowPaint = Paint()
        ..color = Color(0xFFFF6B00)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
      
      canvas.drawCircle(Offset(endX, endY), 3, glowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is ProfessionalProgressPainter && 
           oldDelegate.progress != progress;
  }
}