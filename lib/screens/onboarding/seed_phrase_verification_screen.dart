import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/responsive.dart';
import '../main_screen.dart';
import 'pin_setup_screen.dart';

class SeedPhraseVerificationScreen extends StatefulWidget {
  final String seedPhrase;
  final int? birthdayBlock;

  const SeedPhraseVerificationScreen({
    super.key,
    required this.seedPhrase,
    this.birthdayBlock,
  });

  @override
  State<SeedPhraseVerificationScreen> createState() => _SeedPhraseVerificationScreenState();
}

class _SeedPhraseVerificationScreenState extends State<SeedPhraseVerificationScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  
  final List<int> _verificationIndices = [];
  final Map<int, TextEditingController> _controllers = {};
  
  bool _isVerifying = false;
  String? _errorMessage;

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

    _generateRandomIndices();
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _generateRandomIndices() {
    final seedWords = widget.seedPhrase.split(' ');
    final totalWords = seedWords.length;
    
    // Select 4 random indices for verification
    final indices = <int>[];
    while (indices.length < 4) {
      final randomIndex = (DateTime.now().millisecondsSinceEpoch + indices.length) % totalWords;
      if (!indices.contains(randomIndex)) {
        indices.add(randomIndex);
      }
    }
    
    _verificationIndices.addAll(indices..sort());
    
    // Initialize controllers
    for (int index in _verificationIndices) {
      _controllers[index] = TextEditingController();
    }
  }

  bool _validateInputs() {
    final seedWords = widget.seedPhrase.split(' ');
    
    for (int index in _verificationIndices) {
      final userInput = _controllers[index]?.text.trim().toLowerCase() ?? '';
      final correctWord = seedWords[index].toLowerCase();
      
      if (userInput != correctWord) {
        return false;
      }
    }
    return true;
  }

  Future<void> _verifyAndCreateWallet() async {
    if (_isVerifying) return;
    
    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      if (!_validateInputs()) {
        setState(() {
          _errorMessage = 'Some words are incorrect. Please check your inputs.';
          _isVerifying = false;
        });
        return;
      }

      // Create wallet with the verified seed phrase
      final walletProvider = Provider.of<WalletProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final walletData = await walletProvider.createWallet(widget.seedPhrase, authProvider: authProvider);

      if (mounted) {
        // Generate a wallet ID from the seed phrase
        final walletId = 'wallet_${DateTime.now().millisecondsSinceEpoch}';
        
        // Navigate to PIN setup screen
        Navigator.of(context).pushAndRemoveUntil(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                PinSetupScreen(
                  walletId: walletId,
                  seedPhrase: widget.seedPhrase,
                  walletData: {
                    'birthdayHeight': widget.birthdayBlock ?? 0,
                    'created_at': DateTime.now().toIso8601String(),
                  },
                ),
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
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to create wallet: $e';
          _isVerifying = false;
        });
      }
    }
  }

  void _clearInputs() {
    for (var controller in _controllers.values) {
      controller.clear();
    }
    setState(() {
      _errorMessage = null;
    });
  }

  Future<void> _skipVerification() async {
    if (_isVerifying) return;
    
    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      // Create wallet without verification (for development only)
      final walletProvider = Provider.of<WalletProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final walletData = await walletProvider.createWallet(widget.seedPhrase, authProvider: authProvider);

      if (mounted) {
        // Generate a wallet ID from the seed phrase
        final walletId = 'wallet_${DateTime.now().millisecondsSinceEpoch}';
        
        // Navigate to PIN setup screen
        Navigator.of(context).pushAndRemoveUntil(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                PinSetupScreen(
                  walletId: walletId,
                  seedPhrase: widget.seedPhrase,
                  walletData: {
                    'birthdayHeight': widget.birthdayBlock ?? 0,
                    'created_at': DateTime.now().toIso8601String(),
                  },
                ),
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
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to create wallet: $e';
          _isVerifying = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Recovery Phrase'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _clearInputs,
            tooltip: 'Clear inputs',
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: ResponsiveUtils.getScreenPadding(context),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height - 
                    MediaQuery.of(context).padding.top - 
                    MediaQuery.of(context).padding.bottom - 
                    ResponsiveUtils.getVerticalPadding(context) * 2 - 
                    56, // AppBar height
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Instructions Section
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
                                Icons.quiz,
                                color: Theme.of(context).colorScheme.primary,
                                size: ResponsiveUtils.getIconSize(context, base: 24),
                              ),
                              SizedBox(width: ResponsiveUtils.isSmallMobile(context) ? 8 : 12),
                              Expanded(
                                child: Text(
                                  'Verification Required',
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
                            'Enter the missing words from your recovery phrase to verify you have written it down correctly.',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.8),
                              fontSize: ResponsiveUtils.getBodyTextSize(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    SizedBox(height: ResponsiveUtils.isSmallScreen(context) ? 20 : 32),
                    
                    // Verification Inputs
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(ResponsiveUtils.getHorizontalPadding(context)),
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
                            'Enter Missing Words',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: ResponsiveUtils.getTitleTextSize(context),
                            ),
                          ),
                          SizedBox(height: ResponsiveUtils.isSmallScreen(context) ? 16 : 24),
                          
                          // Input fields
                          for (int i = 0; i < _verificationIndices.length; i++)
                            Padding(
                              padding: EdgeInsets.only(bottom: ResponsiveUtils.isSmallScreen(context) ? 12 : 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Word #${_verificationIndices[i] + 1}',
                                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(context).colorScheme.primary,
                                      fontSize: ResponsiveUtils.getBodyTextSize(context) * 0.9,
                                    ),
                                  ),
                                  SizedBox(height: ResponsiveUtils.isSmallScreen(context) ? 6 : 8),
                                  SizedBox(
                                    height: ResponsiveUtils.getInputFieldHeight(context),
                                    child: TextField(
                                      controller: _controllers[_verificationIndices[i]],
                                      textInputAction: TextInputAction.next,
                                      autocorrect: false,
                                      enableSuggestions: false,
                                      style: TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: ResponsiveUtils.getSeedWordTextSize(context),
                                      ),
                                      decoration: InputDecoration(
                                        hintText: 'Enter word ${_verificationIndices[i] + 1}',
                                        filled: true,
                                        fillColor: Theme.of(context).colorScheme.background,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(ResponsiveUtils.getCardBorderRadius(context) * 0.75),
                                          borderSide: BorderSide(
                                            color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(ResponsiveUtils.getCardBorderRadius(context) * 0.75),
                                          borderSide: BorderSide(
                                            color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(ResponsiveUtils.getCardBorderRadius(context) * 0.75),
                                          borderSide: BorderSide(
                                            color: Theme.of(context).colorScheme.primary,
                                            width: 2,
                                          ),
                                        ),
                                        contentPadding: ResponsiveUtils.getInputFieldPadding(context),
                                        hintStyle: TextStyle(
                                          fontSize: ResponsiveUtils.getSeedWordTextSize(context) * 0.9,
                                          color: Theme.of(context).colorScheme.outline.withOpacity(0.6),
                                        ),
                                      ),
                                      onChanged: (value) {
                                        setState(() {
                                          _errorMessage = null;
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          
                          if (_errorMessage != null) ...[
                            SizedBox(height: ResponsiveUtils.isSmallScreen(context) ? 12 : 16),
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
                        ],
                      ),
                    ),
                    
                    SizedBox(height: ResponsiveUtils.isSmallScreen(context) ? 20 : 32),
                    
                    // Action Button
                    SizedBox(
                      width: double.infinity,
                      height: ResponsiveUtils.getButtonHeight(context),
                      child: ElevatedButton(
                        onPressed: _isVerifying ? null : _verifyAndCreateWallet,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              ResponsiveUtils.getButtonBorderRadius(context),
                            ),
                          ),
                          elevation: _isVerifying ? 0 : 4,
                        ),
                        child: _isVerifying
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
                                    'Creating Wallet...',
                                    style: TextStyle(
                                      fontSize: ResponsiveUtils.getBodyTextSize(context),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              )
                            : Text(
                                'Verify & Create Wallet',
                                style: TextStyle(
                                  fontSize: ResponsiveUtils.getBodyTextSize(context),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                    
                    // Skip button for development
                    SizedBox(height: ResponsiveUtils.isSmallScreen(context) ? 12 : 16),
                    SizedBox(
                      width: double.infinity,
                      height: ResponsiveUtils.getButtonHeight(context),
                      child: TextButton(
                        onPressed: _isVerifying ? null : _skipVerification,
                        style: TextButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              ResponsiveUtils.getButtonBorderRadius(context),
                            ),
                            side: BorderSide(
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.skip_next,
                              size: ResponsiveUtils.getIconSize(context, base: 20),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Skip Verification (Dev Only)',
                              style: TextStyle(
                                fontSize: ResponsiveUtils.getBodyTextSize(context),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}