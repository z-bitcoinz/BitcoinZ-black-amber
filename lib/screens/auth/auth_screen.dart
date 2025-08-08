import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import '../../providers/auth_provider.dart';
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
      
      // Auto-trigger biometric auth if enabled and available
      if (_showBiometricOption) {
        _authenticateWithBiometrics();
      }
    }
  }

  Future<void> _authenticateWithBiometrics() async {
    if (_isAuthenticating) return;
    
    setState(() {
      _isAuthenticating = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final success = await authProvider.authenticate();
      
      if (success && mounted) {
        _navigateToDashboard();
      }
    } catch (e) {
      // Biometric auth failed, fall back to PIN
    } finally {
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
        });
      }
    }
  }

  Future<void> _authenticateWithPin() async {
    if (_enteredPin.length < 4 || _isAuthenticating) return;

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
      
      if (_enteredPin.length >= 4) {
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
      body: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(24.0),
          height: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom,
          child: Column(
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // App Logo
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    Text(
                      'Welcome Back',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    Text(
                      'Enter your PIN to access your wallet',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              
              // PIN Input Display
              Expanded(
                flex: 1,
                child: AnimatedBuilder(
                  animation: _shakeAnimation,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(_shakeAnimation.value, 0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
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
                            const CircularProgressIndicator(),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
              
              // PIN Keypad
              Expanded(
                flex: 3,
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
  }

  Widget _buildPinButton(String number) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: SizedBox(
          height: 64,
          child: ElevatedButton(
            onPressed: _isAuthenticating ? null : () => _onPinInput(number),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.surface,
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              elevation: 2,
              shape: const CircleBorder(),
            ),
            child: Text(
              number,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w500,
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
        padding: const EdgeInsets.all(8.0),
        child: SizedBox(
          height: 64,
          child: ElevatedButton(
            onPressed: _isAuthenticating ? null : _authenticateWithBiometrics,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              foregroundColor: Theme.of(context).colorScheme.primary,
              elevation: 0,
              shape: const CircleBorder(),
            ),
            child: const Icon(
              Icons.fingerprint,
              size: 28,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteButton() {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: SizedBox(
          height: 64,
          child: ElevatedButton(
            onPressed: _isAuthenticating ? null : _onPinDelete,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              elevation: 0,
              shape: const CircleBorder(),
            ),
            child: const Icon(
              Icons.backspace_outlined,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyButton() {
    return const Expanded(
      child: SizedBox(height: 64),
    );
  }
}