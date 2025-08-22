import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../utils/responsive.dart';
import 'backup_seed_display_screen.dart';

class BackupWalletScreen extends StatefulWidget {
  const BackupWalletScreen({super.key});

  @override
  State<BackupWalletScreen> createState() => _BackupWalletScreenState();
}

class _BackupWalletScreenState extends State<BackupWalletScreen>
    with TickerProviderStateMixin {
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;
  
  String _enteredPin = '';
  bool _isAuthenticating = false;
  String? _errorMessage;

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
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _authenticateWithPin() async {
    if (_enteredPin.length < 6 || _isAuthenticating) return;

    setState(() {
      _isAuthenticating = true;
      _errorMessage = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final success = await authProvider.authenticate(pin: _enteredPin);
      
      if (success && mounted) {
        // Authentication successful, get seed phrase and navigate
        final walletProvider = Provider.of<WalletProvider>(context, listen: false);
        final seedPhrase = await walletProvider.getSeedPhrase();
        
        if (mounted) {
          if (seedPhrase != null && seedPhrase.isNotEmpty) {
            // Get birthday block for backup
            final birthdayBlock = walletProvider.getBirthdayBlock();
            
            // Navigate to backup seed phrase display screen
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => BackupSeedDisplayScreen(
                  seedPhrase: seedPhrase,
                  birthdayBlock: birthdayBlock,
                ),
              ),
            );
          } else {
            setState(() {
              _errorMessage = 'Seed phrase not available. Please try again later.';
              _enteredPin = '';
              _isAuthenticating = false;
            });
          }
        }
      } else {
        _showPinError('Incorrect PIN. Please try again.');
      }
    } catch (e) {
      _showPinError('Authentication failed. Please try again.');
    }
  }

  void _showPinError(String message) {
    HapticFeedback.heavyImpact();
    _shakeController.forward().then((_) {
      _shakeController.reverse();
    });
    
    setState(() {
      _errorMessage = message;
      _enteredPin = '';
      _isAuthenticating = false;
    });
  }

  void _onPinInput(String digit) {
    if (_enteredPin.length < 6 && !_isAuthenticating) {
      HapticFeedback.lightImpact();
      setState(() {
        _enteredPin += digit;
        _errorMessage = null;
      });
      
      if (_enteredPin.length == 6) {
        _authenticateWithPin();
      }
    }
  }

  void _onPinDelete() {
    if (_enteredPin.isNotEmpty && !_isAuthenticating) {
      HapticFeedback.lightImpact();
      setState(() {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
        _errorMessage = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup Wallet'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 48.0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(ResponsiveUtils.getHorizontalPadding(context)),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      SizedBox(height: ResponsiveUtils.getPinVerticalSpacing(context)),
                      
                      // Security Warning
                        Container(
                          padding: EdgeInsets.all(ResponsiveUtils.getSecurityWarningPadding(context)),
                          margin: EdgeInsets.only(
                            bottom: ResponsiveUtils.getPinVerticalSpacing(context),
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(
                              ResponsiveUtils.getCardBorderRadius(context),
                            ),
                            border: Border.all(
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.security,
                                color: Theme.of(context).colorScheme.primary,
                                size: ResponsiveUtils.getIconSize(context, base: 28),
                              ),
                              SizedBox(height: ResponsiveUtils.isDesktop(context) ? 8 : 12),
                              Text(
                                'Security Verification Required',
                                style: TextStyle(
                                  fontSize: ResponsiveUtils.getTitleTextSize(context) * 0.8,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              SizedBox(height: ResponsiveUtils.isDesktop(context) ? 6 : 8),
                              Text(
                                'Enter your PIN to view your recovery phrase. Make sure you are in a private location.',
                                style: TextStyle(
                                  fontSize: ResponsiveUtils.getBodyTextSize(context),
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),

                        // PIN Input Display
                        AnimatedBuilder(
                          animation: _shakeAnimation,
                          builder: (context, child) {
                            return Transform.translate(
                              offset: Offset(_shakeAnimation.value, 0),
                              child: Column(
                                children: [
                                  Text(
                                    'Enter your PIN',
                                    style: TextStyle(
                                      fontSize: ResponsiveUtils.getTitleTextSize(context) * 0.85,
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(context).colorScheme.onSurface,
                                    ),
                                  ),
                                  SizedBox(height: ResponsiveUtils.isLimitedHeight(context) ? 12 : 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: List.generate(6, (index) {
                                      final dotSize = ResponsiveUtils.isSmallDesktop(context) ? 10.0 : (ResponsiveUtils.isDesktop(context) ? 12.0 : 16.0);
                                      final spacing = ResponsiveUtils.isSmallDesktop(context) ? 5.0 : (ResponsiveUtils.isDesktop(context) ? 6.0 : 8.0);
                                      return Container(
                                        margin: EdgeInsets.symmetric(horizontal: spacing),
                                        width: dotSize,
                                        height: dotSize,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: index < _enteredPin.length
                                              ? Theme.of(context).colorScheme.primary
                                              : Theme.of(context).colorScheme.outline.withOpacity(0.3),
                                        ),
                                      );
                                    }),
                                  ),
                                  if (_errorMessage != null) ...[
                                    SizedBox(height: ResponsiveUtils.isLimitedHeight(context) ? 8 : 12),
                                    Text(
                                      _errorMessage!,
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.error,
                                        fontSize: ResponsiveUtils.getBodyTextSize(context),
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                  if (_isAuthenticating) ...[
                                    SizedBox(height: ResponsiveUtils.isLimitedHeight(context) ? 12 : 16),
                                    SizedBox(
                                      width: ResponsiveUtils.isSmallDesktop(context) ? 18 : (ResponsiveUtils.isDesktop(context) ? 20 : 24),
                                      height: ResponsiveUtils.isSmallDesktop(context) ? 18 : (ResponsiveUtils.isDesktop(context) ? 20 : 24),
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                        
                        SizedBox(height: ResponsiveUtils.getPinVerticalSpacing(context)),
              
                        // PIN Keypad - Center it within the full width
                        Center(
                          child: ConstrainedBox(
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
                        ),
                        
                        SizedBox(height: ResponsiveUtils.getPinVerticalSpacing(context) * 0.5),
                      ],
                    ),
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