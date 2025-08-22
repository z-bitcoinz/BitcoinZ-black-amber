import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/validators.dart';
import '../../utils/responsive.dart';

class ChangePinScreen extends StatefulWidget {
  const ChangePinScreen({super.key});

  @override
  State<ChangePinScreen> createState() => _ChangePinScreenState();
}

class _ChangePinScreenState extends State<ChangePinScreen>
    with TickerProviderStateMixin {
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;
  
  String _currentPin = '';
  String _newPin = '';
  String _confirmedPin = '';
  int _stage = 0; // 0: current PIN, 1: new PIN, 2: confirm new PIN
  bool _isProcessing = false;
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

  void _onPinInput(String digit) {
    if (_isProcessing) return;
    
    HapticFeedback.lightImpact();
    
    setState(() {
      switch (_stage) {
        case 0:
          if (_currentPin.length < 6) {
            _currentPin += digit;
            _errorMessage = null;
          }
          if (_currentPin.length == 6) {
            _processStage();
          }
          break;
        case 1:
          if (_newPin.length < 6) {
            _newPin += digit;
            _errorMessage = null;
          }
          if (_newPin.length == 6) {
            _processStage();
          }
          break;
        case 2:
          if (_confirmedPin.length < 6) {
            _confirmedPin += digit;
            _errorMessage = null;
          }
          if (_confirmedPin.length == 6) {
            _processStage();
          }
          break;
      }
    });
  }

  void _onPinDelete() {
    if (_isProcessing) return;
    
    HapticFeedback.lightImpact();
    
    setState(() {
      switch (_stage) {
        case 0:
          if (_currentPin.isNotEmpty) {
            _currentPin = _currentPin.substring(0, _currentPin.length - 1);
          }
          break;
        case 1:
          if (_newPin.isNotEmpty) {
            _newPin = _newPin.substring(0, _newPin.length - 1);
          } else {
            // Go back to previous stage
            _stage = 0;
            _currentPin = '';
          }
          break;
        case 2:
          if (_confirmedPin.isNotEmpty) {
            _confirmedPin = _confirmedPin.substring(0, _confirmedPin.length - 1);
          } else {
            // Go back to previous stage
            _stage = 1;
            _newPin = '';
          }
          break;
      }
    });
  }

  Future<void> _processStage() async {
    switch (_stage) {
      case 0:
        // Verify current PIN
        await _verifyCurrentPin();
        break;
      case 1:
        // Validate new PIN
        _validateNewPin();
        break;
      case 2:
        // Confirm and save new PIN
        await _confirmAndSaveNewPin();
        break;
    }
  }

  Future<void> _verifyCurrentPin() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final isValid = await authProvider.authenticate(pin: _currentPin);
      
      if (isValid) {
        setState(() {
          _stage = 1;
          _isProcessing = false;
          _errorMessage = null;
        });
      } else {
        setState(() {
          _errorMessage = 'Incorrect current PIN';
          _currentPin = '';
          _isProcessing = false;
        });
        _showError();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to verify PIN';
        _currentPin = '';
        _isProcessing = false;
      });
      _showError();
    }
  }

  void _validateNewPin() {
    // Check if new PIN is same as current
    if (_newPin == _currentPin) {
      setState(() {
        _errorMessage = 'New PIN must be different from current PIN';
        _newPin = '';
      });
      _showError();
      return;
    }
    
    // Validate PIN strength
    final validation = Validators.validatePin(_newPin);
    if (validation != null) {
      setState(() {
        _errorMessage = validation;
        _newPin = '';
      });
      _showError();
    } else {
      setState(() {
        _stage = 2;
        _errorMessage = null;
      });
    }
  }

  Future<void> _confirmAndSaveNewPin() async {
    if (_confirmedPin != _newPin) {
      setState(() {
        _errorMessage = 'PINs do not match';
        _confirmedPin = '';
      });
      _showError();
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final success = await authProvider.setPin(_newPin);
      
      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PIN changed successfully'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop();
        }
      } else {
        throw Exception('Failed to update PIN');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to change PIN: ${e.toString()}';
        _isProcessing = false;
      });
      _showError();
    }
  }

  void _showError() {
    HapticFeedback.heavyImpact();
    _shakeController.forward().then((_) {
      _shakeController.reverse();
    });
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String currentPin;
    String title;
    String subtitle;
    
    switch (_stage) {
      case 0:
        currentPin = _currentPin;
        title = 'Enter Current PIN';
        subtitle = 'Please enter your current PIN to continue';
        break;
      case 1:
        currentPin = _newPin;
        title = 'Create New PIN';
        subtitle = 'Choose a new secure 6-digit PIN';
        break;
      case 2:
        currentPin = _confirmedPin;
        title = 'Confirm New PIN';
        subtitle = 'Please re-enter your new PIN to confirm';
        break;
      default:
        currentPin = '';
        title = '';
        subtitle = '';
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Change PIN'),
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
                        // Progress Indicator
                        SizedBox(height: ResponsiveUtils.isDesktop(context) ? 16 : 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildStageIndicator(0, 'Current'),
                            _buildStageConnector(0),
                            _buildStageIndicator(1, 'New'),
                            _buildStageConnector(1),
                            _buildStageIndicator(2, 'Confirm'),
                          ],
                        ),
                        SizedBox(height: ResponsiveUtils.isDesktop(context) ? 12 : 16),
                        
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: ResponsiveUtils.getTitleTextSize(context),
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        SizedBox(height: ResponsiveUtils.isDesktop(context) ? 6 : 8),
                        
                        Text(
                          subtitle,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: ResponsiveUtils.getBodyTextSize(context),
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                        
                        SizedBox(height: ResponsiveUtils.isDesktop(context) ? 8 : 12),
                        
                        // Error Message Container - Fixed height to prevent overflow
                        SizedBox(
                          height: ResponsiveUtils.isDesktop(context) ? 50 : 60,
                          child: _errorMessage != null 
                            ? AnimatedBuilder(
                                animation: _shakeAnimation,
                                builder: (context, child) {
                                  return Transform.translate(
                                    offset: Offset(_shakeAnimation.value, 0),
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: ResponsiveUtils.getHorizontalPadding(context),
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Center(
                                        child: Text(
                                          _errorMessage!,
                                          style: TextStyle(
                                            color: Colors.red[700],
                                            fontSize: ResponsiveUtils.getBodyTextSize(context),
                                          ),
                                          textAlign: TextAlign.center,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              )
                            : const SizedBox.shrink(),
                        ),
              
                        SizedBox(height: ResponsiveUtils.isDesktop(context) ? 8 : 12),
                        
                        // PIN Input Display
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(6, (index) {
                            final dotSize = ResponsiveUtils.isDesktop(context) ? 12.0 : 16.0;
                            final spacing = ResponsiveUtils.isDesktop(context) ? 6.0 : 8.0;
                            return Container(
                              margin: EdgeInsets.symmetric(horizontal: spacing),
                              width: dotSize,
                              height: dotSize,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: index < currentPin.length
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.outline.withOpacity(0.3),
                              ),
                            );
                          }),
                        ),
                        
                        if (_isProcessing) ...[
                          SizedBox(height: ResponsiveUtils.isDesktop(context) ? 16 : 24),
                          SizedBox(
                            width: ResponsiveUtils.isDesktop(context) ? 20 : 24,
                            height: ResponsiveUtils.isDesktop(context) ? 20 : 24,
                            child: const CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ],
                        
                        SizedBox(height: ResponsiveUtils.isDesktop(context) ? 12 : 16),
                        
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
                        
                        SizedBox(height: ResponsiveUtils.isDesktop(context) ? 20 : 16),
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

  Widget _buildStageIndicator(int stage, String label) {
    final isActive = _stage >= stage;
    final isCompleted = _stage > stage;
    final size = ResponsiveUtils.isDesktop(context) ? 28.0 : 32.0;
    
    return Column(
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive 
                ? Theme.of(context).colorScheme.primary 
                : Theme.of(context).colorScheme.outline.withOpacity(0.3),
          ),
          child: Center(
            child: isCompleted
                ? Icon(
                    Icons.check, 
                    color: Colors.white, 
                    size: ResponsiveUtils.isDesktop(context) ? 14 : 16,
                  )
                : Text(
                    '${stage + 1}',
                    style: TextStyle(
                      color: isActive ? Colors.white : Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                      fontWeight: FontWeight.bold,
                      fontSize: ResponsiveUtils.isDesktop(context) ? 12 : 14,
                    ),
                  ),
          ),
        ),
        SizedBox(height: ResponsiveUtils.isDesktop(context) ? 3 : 4),
        Text(
          label,
          style: TextStyle(
            fontSize: ResponsiveUtils.isDesktop(context) ? 10 : 12,
            color: isActive 
                ? Theme.of(context).colorScheme.primary 
                : Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
          ),
        ),
      ],
    );
  }

  Widget _buildStageConnector(int afterStage) {
    final isActive = _stage > afterStage;
    final width = ResponsiveUtils.isDesktop(context) ? 30.0 : 40.0;
    final bottomMargin = ResponsiveUtils.isDesktop(context) ? 17.0 : 20.0;
    
    return Container(
      width: width,
      height: 2,
      margin: EdgeInsets.only(bottom: bottomMargin),
      color: isActive 
          ? Theme.of(context).colorScheme.primary 
          : Theme.of(context).colorScheme.outline.withOpacity(0.3),
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