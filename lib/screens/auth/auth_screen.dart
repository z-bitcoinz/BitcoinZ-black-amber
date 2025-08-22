import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import '../../providers/auth_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../utils/responsive.dart';
import '../main_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with TickerProviderStateMixin {
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;
  
  final TextEditingController _pinController = TextEditingController();
  bool _showBiometricOption = false;
  bool _isAuthenticating = false;
  String _enteredPin = '';

  @override
  void initState() {
    super.initState();
    
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _shakeAnimation = Tween<double>(
      begin: 0,
      end: 10,
    ).animate(CurvedAnimation(
      parent: _shakeController,
      curve: Curves.elasticIn,
    ));

    _checkBiometricsAvailability();
  }

  Future<void> _checkBiometricsAvailability() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isAvailable = await authProvider.isBiometricsAvailable();
    
    if (mounted) {
      setState(() {
        _showBiometricOption = isAvailable && authProvider.biometricsEnabled;
      });
      
      // Note: Removed auto-trigger to prevent conflicts with manual button press
      // User must explicitly tap the biometric button to authenticate
    }
  }

  Future<void> _authenticateWithBiometrics() async {
    if (_isAuthenticating) return;
    
    setState(() {
      _isAuthenticating = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      // Check biometric availability first
      final isAvailable = await authProvider.isBiometricsAvailable();
      if (!isAvailable) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Biometric authentication not available on this device'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }
      
      final success = await authProvider.authenticate();
      
      if (success && mounted) {
        // Success - navigate to dashboard
        _navigateToDashboard();
      } else {
        // Authentication failed or was cancelled
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Authentication cancelled. Please try again or use PIN.'),
              backgroundColor: Colors.orange.shade700,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      // Biometric auth error
      if (mounted) {
        String errorMessage = 'Biometric authentication failed. Please use PIN.';
        
        // Provide more specific error messages
        if (e.toString().contains('UserCancel')) {
          errorMessage = 'Authentication cancelled by user';
        } else if (e.toString().contains('NotAvailable')) {
          errorMessage = 'Biometric authentication not available';
        } else if (e.toString().contains('NotEnrolled')) {
          errorMessage = 'No biometrics enrolled on device';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
        });
      }
    }
  }

  Future<void> _authenticateWithPin() async {
    if (_enteredPin.length < 6 || _isAuthenticating) return;

    setState(() {
      _isAuthenticating = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final success = await authProvider.authenticate(pin: _enteredPin);
      
      if (success && mounted) {
        _navigateToDashboard();
      } else {
        _showPinError();
      }
    } catch (e) {
      _showPinError();
    } finally {
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
          _enteredPin = '';
        });
      }
    }
  }

  void _showPinError() {
    HapticFeedback.heavyImpact();
    _shakeController.forward().then((_) {
      _shakeController.reverse();
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Incorrect PIN. Please try again.'),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _navigateToDashboard() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const MainScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    );
  }

  void _onPinInput(String digit) {
    if (_enteredPin.length < 6) {
      HapticFeedback.lightImpact();
      setState(() {
        _enteredPin += digit;
      });
      
      if (_enteredPin.length == 6) {
        _authenticateWithPin();
      }
    }
  }

  void _onPinDelete() {
    if (_enteredPin.isNotEmpty) {
      HapticFeedback.lightImpact();
      setState(() {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      });
    }
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Only show connection warning if actually offline
                      Consumer<WalletProvider>(
                        builder: (context, walletProvider, child) {
                          // Only show if there's a real connection problem
                          if (walletProvider.connectionStatus.toLowerCase().contains('offline') ||
                              walletProvider.connectionStatus.toLowerCase().contains('error') ||
                              walletProvider.connectionStatus.toLowerCase().contains('failed')) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF6B00).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFFF6B00).withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.wifi_off,
                                    size: 16,
                                    color: Color(0xFFFF6B00),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Server Offline',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFFFF6B00),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // App Logo
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF6B00), Color(0xFFFFAA00)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.lock,
                          size: 36,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      const Text(
                        'Welcome Back',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      
                      Text(
                        'Enter your PIN to access your wallet',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.6),
                        ),
                      ),
                      
                      const SizedBox(height: 30),
                      
                      // PIN Input Display
                      AnimatedBuilder(
                        animation: _shakeAnimation,
                        builder: (context, child) {
                          return Transform.translate(
                            offset: Offset(_shakeAnimation.value, 0),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(6, (index) {
                                    return Container(
                                      margin: const EdgeInsets.symmetric(horizontal: 8),
                                      width: 16,
                                      height: 16,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: index < _enteredPin.length
                                            ? Theme.of(context).colorScheme.primary
                                            : Theme.of(context).colorScheme.outline.withOpacity(0.3),
                                      ),
                                    );
                                  }),
                                ),
                                if (_isAuthenticating) ...[
                                  const SizedBox(height: 24),
                                  CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                      
                      const SizedBox(height: 30),
                      
                      // PIN Keypad with constrained size
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: ResponsiveUtils.getPinKeypadWidth(context),
                        ),
                        child: Column(
                        children: [
                          // Numbers 1-3
                          Row(
                            children: [
                              _buildPinButton('1'),
                              _buildPinButton('2'),
                              _buildPinButton('3'),
                            ],
                          ),
                          // Numbers 4-6
                          Row(
                            children: [
                              _buildPinButton('4'),
                              _buildPinButton('5'),
                              _buildPinButton('6'),
                            ],
                          ),
                          // Numbers 7-9
                          Row(
                            children: [
                              _buildPinButton('7'),
                              _buildPinButton('8'),
                              _buildPinButton('9'),
                            ],
                          ),
                          // Bottom row
                          Row(
                            children: [
                              // Biometric button or empty space
                              _showBiometricOption
                                  ? _buildBiometricButton()
                                  : _buildEmptyButton(),
                              _buildPinButton('0'),
                              _buildDeleteButton(),
                            ],
                          ),
                        ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPinButton(String number) {
    return Expanded(
      child: Padding(
        padding: EdgeInsets.all(ResponsiveUtils.getPinButtonPadding(context)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: ResponsiveUtils.getPinButtonMinSize(context),
            minHeight: ResponsiveUtils.getPinButtonMinSize(context),
          ),
          child: AspectRatio(
            aspectRatio: 1.0,
            child: ElevatedButton(
              onPressed: _isAuthenticating ? null : () => _onPinInput(number),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.surface,
                foregroundColor: Theme.of(context).colorScheme.onSurface,
                elevation: 2,
                shape: const CircleBorder(),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Text(
                number,
                style: TextStyle(
                  fontSize: ResponsiveUtils.getPinButtonFontSize(context),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBiometricButton() {
    return Expanded(
      child: Padding(
        padding: EdgeInsets.all(ResponsiveUtils.getPinButtonPadding(context)),
        child: AspectRatio(
          aspectRatio: 1.0,
          child: ElevatedButton(
            onPressed: _isAuthenticating ? null : _authenticateWithBiometrics,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.surface,
              foregroundColor: Theme.of(context).colorScheme.primary,
              elevation: 2,
              shape: const CircleBorder(),
              side: BorderSide(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: _isAuthenticating 
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.primary.withOpacity(0.7),
                    ),
                  ),
                )
              : const Icon(
                  Icons.fingerprint,
                  size: 26,
                ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteButton() {
    return Expanded(
      child: Padding(
        padding: EdgeInsets.all(ResponsiveUtils.getPinButtonPadding(context)),
        child: AspectRatio(
          aspectRatio: 1.0,
          child: ElevatedButton(
            onPressed: _isAuthenticating ? null : _onPinDelete,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              elevation: 0,
              shape: const CircleBorder(),
            ),
            child: const Icon(
              Icons.backspace_outlined,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyButton() {
    return Expanded(
      child: Padding(
        padding: EdgeInsets.all(ResponsiveUtils.getPinButtonPadding(context)),
        child: const AspectRatio(
          aspectRatio: 1.0,
          child: SizedBox(),
        ),
      ),
    );
  }
}