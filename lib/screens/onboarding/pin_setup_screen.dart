import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/validators.dart';
import '../main_screen.dart';

class PinSetupScreen extends StatefulWidget {
  final String walletId;
  final String? seedPhrase;
  final Map<String, dynamic>? walletData;
  
  const PinSetupScreen({
    super.key,
    required this.walletId,
    this.seedPhrase,
    this.walletData,
  });

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen>
    with TickerProviderStateMixin {
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;
  
  String _enteredPin = '';
  String _confirmedPin = '';
  bool _isConfirming = false;
  bool _isProcessing = false;
  String? _errorMessage;
  bool _biometricsAvailable = false;
  bool _enableBiometrics = false;

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
        _biometricsAvailable = isAvailable;
      });
    }
  }

  void _onPinInput(String digit) {
    if (_isProcessing) return;
    
    HapticFeedback.lightImpact();
    
    setState(() {
      if (!_isConfirming) {
        // First PIN entry
        if (_enteredPin.length < 6) {
          _enteredPin += digit;
          _errorMessage = null;
        }
        
        if (_enteredPin.length == 6) {
          // Validate PIN strength
          final validation = Validators.validatePin(_enteredPin);
          if (validation != null) {
            _errorMessage = validation;
            _showError();
            _enteredPin = '';
          } else {
            // Move to confirmation
            _isConfirming = true;
            _errorMessage = null;
          }
        }
      } else {
        // Confirming PIN
        if (_confirmedPin.length < 6) {
          _confirmedPin += digit;
        }
        
        if (_confirmedPin.length == 6) {
          if (_confirmedPin == _enteredPin) {
            // PINs match, proceed with setup
            _completeSetup();
          } else {
            // PINs don't match
            _errorMessage = 'PINs do not match. Please try again.';
            _showError();
            _confirmedPin = '';
          }
        }
      }
    });
  }

  void _onPinDelete() {
    if (_isProcessing) return;
    
    HapticFeedback.lightImpact();
    
    setState(() {
      if (!_isConfirming) {
        if (_enteredPin.isNotEmpty) {
          _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
          _errorMessage = null;
        }
      } else {
        if (_confirmedPin.isNotEmpty) {
          _confirmedPin = _confirmedPin.substring(0, _confirmedPin.length - 1);
        } else {
          // Go back to first PIN entry
          _isConfirming = false;
          _enteredPin = '';
        }
      }
    });
  }

  void _showError() {
    HapticFeedback.heavyImpact();
    _shakeController.forward().then((_) {
      _shakeController.reverse();
    });
  }

  Future<void> _completeSetup() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      // Set the PIN
      final pinSet = await authProvider.setPin(_enteredPin);
      if (!pinSet) {
        throw Exception('Failed to set PIN');
      }
      
      // Enable biometrics if requested
      if (_enableBiometrics && _biometricsAvailable) {
        await authProvider.setBiometricsEnabled(true);
      }
      
      // Register the wallet with all data
      final registered = await authProvider.registerWallet(
        widget.walletId,
        seedPhrase: widget.seedPhrase,
        walletData: widget.walletData,
      );
      
      if (!registered) {
        throw Exception('Failed to register wallet');
      }
      
      // Authenticate with the new PIN
      final authenticated = await authProvider.authenticate(pin: _enteredPin);
      if (!authenticated) {
        throw Exception('Failed to authenticate');
      }
      
      if (mounted) {
        // Navigate to main screen
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const MainScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Setup failed: ${e.toString()}';
        _isProcessing = false;
      });
      _showError();
    }
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentPin = _isConfirming ? _confirmedPin : _enteredPin;
    final title = _isConfirming ? 'Confirm Your PIN' : 'Create Your PIN';
    final subtitle = _isConfirming 
        ? 'Please re-enter your PIN to confirm'
        : 'Choose a secure 6-digit PIN for your wallet';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: !_isProcessing ? IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_isConfirming) {
              setState(() {
                _isConfirming = false;
                _confirmedPin = '';
              });
            } else {
              Navigator.of(context).pop();
            }
          },
        ) : null,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Lock Icon
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.lock_outline,
                        size: 40,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    Text(
                      title,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                    
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      AnimatedBuilder(
                        animation: _shakeAnimation,
                        builder: (context, child) {
                          return Transform.translate(
                            offset: Offset(_shakeAnimation.value, 0),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(
                                  color: Colors.red[700],
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
              
              // PIN Input Display
              Expanded(
                flex: 1,
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
                            color: index < currentPin.length
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.outline.withOpacity(0.3),
                          ),
                        );
                      }),
                    ),
                    
                    if (!_isConfirming && _biometricsAvailable) ...[
                      const SizedBox(height: 24),
                      CheckboxListTile(
                        value: _enableBiometrics,
                        onChanged: _isProcessing ? null : (value) {
                          setState(() {
                            _enableBiometrics = value ?? false;
                          });
                        },
                        title: const Text('Enable Biometric Authentication'),
                        subtitle: const Text('Use fingerprint or face unlock'),
                        secondary: const Icon(Icons.fingerprint),
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                    ],
                    
                    if (_isProcessing) ...[
                      const SizedBox(height: 24),
                      const CircularProgressIndicator(),
                    ],
                  ],
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
                        _buildEmptyButton(),
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
            onPressed: _isProcessing ? null : () => _onPinInput(number),
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

  Widget _buildDeleteButton() {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: SizedBox(
          height: 64,
          child: ElevatedButton(
            onPressed: _isProcessing ? null : _onPinDelete,
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