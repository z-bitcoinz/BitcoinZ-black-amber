import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../utils/validators.dart';
import '../../utils/responsive.dart';
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
      
      // Pre-initialize the wallet BEFORE navigating to MainScreen
      // This prevents the "no wallet" delay
      if (mounted) {
        final walletProvider = Provider.of<WalletProvider>(context, listen: false);
        
        // Restore wallet from the data we just registered
        final restored = await walletProvider.restoreFromStoredData(authProvider);
        
        if (restored) {
          // Start initial sync in background
          walletProvider.syncWallet().catchError((e) {
            // Don't block navigation on sync errors
            if (kDebugMode) print('⚠️ Initial sync warning: $e');
          });
        }
        
        // Now navigate to main screen with wallet ready
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: Container(
                height: constraints.maxHeight,
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  children: [
                    Flexible(
                      flex: 1,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Lock Icon (smaller)
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.lock_outline,
                        size: 30,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    Text(
                      title,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    
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
              Flexible(
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
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: Checkbox(
                                value: _enableBiometrics,
                                onChanged: _isProcessing ? null : (value) {
                                  setState(() {
                                    _enableBiometrics = value ?? false;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Enable Biometric Authentication',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                  Text(
                                    'Use fingerprint or face unlock',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      fontSize: 10,
                                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.fingerprint, size: 20),
                          ],
                        ),
                      ),
                    ],
                    
                    if (_isProcessing) ...[
                      const SizedBox(height: 24),
                      const CircularProgressIndicator(),
                    ],
                  ],
                ),
              ),
              
              // PIN Keypad with constrained size
              Flexible(
                flex: 3,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
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
                ],
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
              onPressed: _isProcessing ? null : () => _onPinInput(number),
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

  Widget _buildDeleteButton() {
    return Expanded(
      child: Padding(
        padding: EdgeInsets.all(ResponsiveUtils.getPinButtonPadding(context)),
        child: AspectRatio(
          aspectRatio: 1.0,
          child: ElevatedButton(
            onPressed: _isProcessing ? null : _onPinDelete,
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