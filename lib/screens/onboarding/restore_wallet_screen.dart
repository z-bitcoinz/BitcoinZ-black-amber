import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:bip39/bip39.dart' as bip39;
import '../../providers/wallet_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/responsive.dart';
import '../main_screen.dart';
import '../../widgets/wallet_restore_success_dialog.dart';

class RestoreWalletScreen extends StatefulWidget {
  const RestoreWalletScreen({super.key});

  @override
  State<RestoreWalletScreen> createState() => _RestoreWalletScreenState();
}

class _RestoreWalletScreenState extends State<RestoreWalletScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  
  final List<TextEditingController> _controllers = [];
  final List<FocusNode> _focusNodes = [];
  final TextEditingController _birthdayController = TextEditingController();
  
  bool _isRestoring = false;
  String? _errorMessage;
  bool _showAdvancedOptions = false;
  
  static const int _wordCount = 24;

  @override
  void initState() {
    super.initState();
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    // Initialize controllers and focus nodes
    for (int i = 0; i < _wordCount; i++) {
      _controllers.add(TextEditingController());
      _focusNodes.add(FocusNode());
    }
    
    _birthdayController.text = '0';
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    _birthdayController.dispose();
    super.dispose();
  }

  String get _seedPhrase {
    return _controllers.map((c) => c.text.trim().toLowerCase()).join(' ');
  }

  bool _validateSeedPhrase() {
    final seedPhrase = _seedPhrase;
    
    // Check if all fields are filled
    if (_controllers.any((c) => c.text.trim().isEmpty)) {
      setState(() {
        _errorMessage = 'Please fill in all 24 words';
      });
      return false;
    }
    
    // Validate BIP39 seed phrase
    if (!bip39.validateMnemonic(seedPhrase)) {
      setState(() {
        _errorMessage = 'Invalid recovery phrase. Please check your words.';
      });
      return false;
    }
    
    return true;
  }

  Future<void> _restoreWallet() async {
    if (_isRestoring) return;
    
    setState(() {
      _isRestoring = true;
      _errorMessage = null;
    });

    try {
      print('🚀 RESTORE DEBUG: Starting wallet restore process');
      
      if (!_validateSeedPhrase()) {
        print('❌ RESTORE DEBUG: Seed phrase validation failed');
        setState(() {
          _isRestoring = false;
        });
        return;
      }

      final birthdayHeight = int.tryParse(_birthdayController.text) ?? 0;
      print('🚀 RESTORE DEBUG: Birthday height: $birthdayHeight');
      print('🚀 RESTORE DEBUG: Seed phrase length: ${_seedPhrase.split(' ').length} words');
      
      // Restore wallet with the seed phrase
      print('🚀 RESTORE DEBUG: Getting providers...');
      final walletProvider = Provider.of<WalletProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      print('🚀 RESTORE DEBUG: Calling walletProvider.restoreWallet...');
      await walletProvider.restoreWallet(_seedPhrase, birthdayHeight: birthdayHeight, authProvider: authProvider);
      print('🚀 RESTORE DEBUG: walletProvider.restoreWallet completed successfully');

      if (mounted) {
        // Show success dialog for a cohesive experience
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => WalletRestoreSuccessDialog(
            onClose: () {
              Navigator.of(ctx).pop();
            },
          ),
        );

        // Navigate to main screen
        Navigator.of(context).pushAndRemoveUntil(
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
          (route) => false,
        );
      }
    } catch (e) {
      print('❌ RESTORE DEBUG: Exception caught: $e');
      print('❌ RESTORE DEBUG: Exception type: ${e.runtimeType}');
      print('❌ RESTORE DEBUG: Stack trace: ${StackTrace.current}');
      
      if (mounted) {
        setState(() {
          // Provide more user-friendly error messages
          String userMessage;
          if (e.toString().contains('timeout') || e.toString().contains('timed out')) {
            userMessage = 'Wallet restore timed out. Please check your internet connection and try again.';
          } else if (e.toString().contains('Failed to restore wallet via Rust Bridge')) {
            userMessage = 'Unable to restore wallet. Please check your seed phrase and try again.';
          } else {
            userMessage = 'Failed to restore wallet: ${e.toString().replaceAll('Exception: ', '')}';
          }
          _errorMessage = userMessage;
          _isRestoring = false;
          
          print('❌ RESTORE DEBUG: Set error message: $userMessage');
          print('❌ RESTORE DEBUG: _isRestoring set to false');
        });
      }
    }
  }

  void _clearAllFields() {
    for (var controller in _controllers) {
      controller.clear();
    }
    setState(() {
      _errorMessage = null;
    });
  }

  void _pasteFromClipboard() async {
    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      if (clipboardData?.text != null) {
        final words = clipboardData!.text!.trim().split(RegExp(r'\s+'));
        
        if (words.length == _wordCount) {
          for (int i = 0; i < _wordCount && i < words.length; i++) {
            _controllers[i].text = words[i].toLowerCase();
          }
          setState(() {
            _errorMessage = null;
          });
          
          HapticFeedback.lightImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Recovery phrase pasted from clipboard'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          setState(() {
            _errorMessage = 'Clipboard should contain exactly 24 words';
          });
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to paste from clipboard';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isAndroid = Platform.isAndroid;
    final double _spacingFactor = isAndroid ? 1.2 : 1.0;
    final double _aspectScale = isAndroid ? 0.7 : 0.8; // Taller inputs on Android
    final double _sectionSpacing = (ResponsiveUtils.isSmallScreen(context) ? 20 : 32) * (isAndroid ? 1.1 : 1.0);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Restore Wallet'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.content_paste),
            onPressed: _pasteFromClipboard,
            tooltip: 'Paste from clipboard',
          ),
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: _clearAllFields,
            tooltip: 'Clear all fields',
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: ResponsiveUtils.getScreenPadding(context),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Instructions
                  Container(
                    padding: EdgeInsets.all(ResponsiveUtils.getHorizontalPadding(context)),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(ResponsiveUtils.getCardBorderRadius(context) * 0.75),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.restore,
                              color: Theme.of(context).colorScheme.primary,
                              size: ResponsiveUtils.getIconSize(context, base: 24),
                            ),
                            SizedBox(width: ResponsiveUtils.isSmallMobile(context) ? 8 : 12),
                            Expanded(
                              child: Text(
                                'Restore Your Wallet',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: ResponsiveUtils.isSmallScreen(context) ? 8 : 12),
                        Text(
                          'Enter your 24-word recovery phrase to restore your wallet. Make sure each word is spelled correctly.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.8),
                            fontSize: ResponsiveUtils.getBodyTextSize(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: _sectionSpacing),

                  // Seed Phrase Input
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(ResponsiveUtils.getHorizontalPadding(context) * (isAndroid ? 1.1 : 1.0)),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(ResponsiveUtils.getCardBorderRadius(context)),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Recovery Phrase',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: ResponsiveUtils.getTitleTextSize(context) * (isAndroid ? 1.02 : 1.0),
                          ),
                        ),
                        SizedBox(height: (ResponsiveUtils.isSmallScreen(context) ? 16 : 24) * (isAndroid ? 1.1 : 1.0)),

                        // Word input grid
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: ResponsiveUtils.getSeedPhraseGridColumns(context),
                            childAspectRatio: ResponsiveUtils.getSeedPhraseAspectRatio(context) * _aspectScale, // Taller inputs on Android
                            crossAxisSpacing: ResponsiveUtils.getSeedPhraseSpacing(context) * _spacingFactor,
                            mainAxisSpacing: ResponsiveUtils.getSeedPhraseSpacing(context) * _spacingFactor,
                          ),
                          itemCount: _wordCount,
                          itemBuilder: (context, index) {
                            return Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.background,
                                borderRadius: BorderRadius.circular(ResponsiveUtils.isSmallMobile(context) ? 6 : 8),
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: ResponsiveUtils.isSmallMobile(context) ? 20 : 24,
                                    height: double.infinity,
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                                      borderRadius: BorderRadius.only(
                                        topLeft: Radius.circular(ResponsiveUtils.isSmallMobile(context) ? 6 : 8),
                                        bottomLeft: Radius.circular(ResponsiveUtils.isSmallMobile(context) ? 6 : 8),
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${index + 1}',
                                        style: TextStyle(
                                          fontSize: ResponsiveUtils.getSeedNumberTextSize(context) * 0.9,
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: TextField(
                                      controller: _controllers[index],
                                      focusNode: _focusNodes[index],
                                      textInputAction: index < _wordCount - 1 
                                          ? TextInputAction.next 
                                          : TextInputAction.done,
                                      autocorrect: false,
                                      enableSuggestions: false,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: ResponsiveUtils.getSeedWordTextSize(context) * 0.9,
                                        fontWeight: FontWeight.w500,
                                        fontFamily: 'monospace',
                                      ),
                                      decoration: InputDecoration(
                                        border: InputBorder.none,
                                        hintText: '•••',
                                        hintStyle: TextStyle(
                                          color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
                                          fontSize: ResponsiveUtils.getSeedWordTextSize(context) * 0.8,
                                        ),
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: ResponsiveUtils.isSmallMobile(context) ? 4 : 6,
                                          vertical: ResponsiveUtils.isSmallMobile(context) ? 8 : 10,
                                        ),
                                      ),
                                      onSubmitted: (value) {
                                        if (index < _wordCount - 1) {
                                          _focusNodes[index + 1].requestFocus();
                                        }
                                      },
                                      onChanged: (value) {
                                        setState(() {
                                          _errorMessage = null;
                                        });
                                        
                                        // Auto-advance when user types a space after a word (paste/type friendly)
                                        if (value.isNotEmpty &&
                                            value.endsWith(' ') &&
                                            index < _wordCount - 1) {
                                          _focusNodes[index + 1].requestFocus();
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  
                  // Advanced Options
                  SizedBox(height: ResponsiveUtils.isSmallScreen(context) ? 16 : 24),
                  
                  ExpansionTile(
                    title: Text(
                      'Advanced Options',
                      style: TextStyle(
                        fontSize: ResponsiveUtils.getBodyTextSize(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    leading: Icon(
                      Icons.settings,
                      size: ResponsiveUtils.getIconSize(context, base: 20),
                    ),
                    children: [
                      Padding(
                        padding: EdgeInsets.all(ResponsiveUtils.getHorizontalPadding(context)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Birthday Height (Optional)',
                              style: TextStyle(
                                fontSize: ResponsiveUtils.getBodyTextSize(context) * 0.9,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            SizedBox(height: ResponsiveUtils.isSmallScreen(context) ? 6 : 8),
                            TextField(
                              controller: _birthdayController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              decoration: InputDecoration(
                                hintText: 'Block height when wallet was created (0 for full scan)',
                                filled: true,
                                fillColor: Theme.of(context).colorScheme.background,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(ResponsiveUtils.getCardBorderRadius(context) * 0.75),
                                ),
                                contentPadding: ResponsiveUtils.getInputFieldPadding(context),
                                hintStyle: TextStyle(
                                  fontSize: ResponsiveUtils.getBodyTextSize(context) * 0.85,
                                  color: Theme.of(context).colorScheme.outline.withOpacity(0.6),
                                ),
                              ),
                            ),
                            SizedBox(height: ResponsiveUtils.isSmallScreen(context) ? 8 : 12),
                            Text(
                              'Specifying a birthday height can speed up wallet restoration by skipping blockchain scanning before this block.',
                              style: TextStyle(
                                fontSize: ResponsiveUtils.getBodyTextSize(context) * 0.8,
                                color: Theme.of(context).colorScheme.outline,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  // Error Message
                  if (_errorMessage != null) ...[
                    SizedBox(height: ResponsiveUtils.isSmallScreen(context) ? 16 : 24),
                    Container(
                      padding: EdgeInsets.all(ResponsiveUtils.getHorizontalPadding(context) * 0.75),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(ResponsiveUtils.getCardBorderRadius(context) * 0.5),
                        border: Border.all(
                          color: Colors.red.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: ResponsiveUtils.getIconSize(context, base: 18),
                          ),
                          SizedBox(width: ResponsiveUtils.isSmallMobile(context) ? 6 : 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: ResponsiveUtils.getBodyTextSize(context) * 0.9,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  
                  // Restore Button
                  SizedBox(height: ResponsiveUtils.isSmallScreen(context) ? 24 : 32),
                  
                  SizedBox(
                    width: double.infinity,
                    height: ResponsiveUtils.getButtonHeight(context),
                    child: ElevatedButton(
                      onPressed: _isRestoring ? null : _restoreWallet,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            ResponsiveUtils.getButtonBorderRadius(context),
                          ),
                        ),
                        elevation: _isRestoring ? 0 : 4,
                      ),
                      child: _isRestoring
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: ResponsiveUtils.getIconSize(context, base: 20),
                                  height: ResponsiveUtils.getIconSize(context, base: 20),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                ),
                                SizedBox(width: ResponsiveUtils.isSmallMobile(context) ? 8 : 12),
                                Text(
                                  'Restoring Wallet...',
                                  style: TextStyle(
                                    fontSize: ResponsiveUtils.getBodyTextSize(context),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            )
                          : Text(
                              'Restore Wallet',
                              style: TextStyle(
                                fontSize: ResponsiveUtils.getBodyTextSize(context),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                  
                  SizedBox(height: ResponsiveUtils.getVerticalPadding(context)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}