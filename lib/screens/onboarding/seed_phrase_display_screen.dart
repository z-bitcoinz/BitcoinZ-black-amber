import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/responsive.dart';
import 'seed_phrase_verification_screen.dart';

class SeedPhraseDisplayScreen extends StatefulWidget {
  final String seedPhrase;
  final int? birthdayBlock;

  const SeedPhraseDisplayScreen({
    super.key,
    required this.seedPhrase,
    this.birthdayBlock,
  });

  @override
  State<SeedPhraseDisplayScreen> createState() => _SeedPhraseDisplayScreenState();
}

class _SeedPhraseDisplayScreenState extends State<SeedPhraseDisplayScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _revealController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _revealAnimation;
  
  bool _isRevealed = false;
  bool _hasAcknowledged = false;

  @override
  void initState() {
    super.initState();
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _revealController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _revealAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _revealController,
      curve: Curves.easeInOut,
    ));

    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _revealController.dispose();
    super.dispose();
  }

  void _revealSeedPhrase() {
    HapticFeedback.mediumImpact();
    setState(() {
      _isRevealed = true;
    });
    _revealController.forward();
  }

  void _copySeedPhrase() {
    HapticFeedback.lightImpact();
    Clipboard.setData(ClipboardData(text: widget.seedPhrase));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Recovery phrase copied to clipboard'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _acknowledgeBackup() {
    HapticFeedback.lightImpact();
    setState(() {
      _hasAcknowledged = !_hasAcknowledged;
    });
  }

  void _proceedToVerification() {
    if (!_hasAcknowledged) return;
    
    HapticFeedback.mediumImpact();
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            SeedPhraseVerificationScreen(
              seedPhrase: widget.seedPhrase,
              birthdayBlock: widget.birthdayBlock,
            ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          );
        },
      ),
    );
  }

  List<String> get _seedWords => widget.seedPhrase.split(' ');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recovery Phrase'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_isRevealed)
            IconButton(
              icon: const Icon(Icons.copy),
              onPressed: _copySeedPhrase,
              tooltip: 'Copy to clipboard',
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: ResponsiveUtils.getScreenPadding(context),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              children: [
                // Compact Warning Section
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: Colors.orange.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.orange,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Write down these 24 words in order and store them securely.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.orange.shade800,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Compact Birthday Block Display (if available)
                if (widget.birthdayBlock != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.cake_outlined,
                          color: Theme.of(context).colorScheme.primary,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Wallet Birthday Block',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Block #${widget.birthdayBlock}',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Seed Phrase Display  
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(
                        ResponsiveUtils.getCardBorderRadius(context),
                      ),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                      ),
                    ),
                    child: _isRevealed
                        ? AnimatedBuilder(
                            animation: _revealAnimation,
                            builder: (context, child) {
                              return Opacity(
                                opacity: _revealAnimation.value,
                                child: Padding(
                                  padding: EdgeInsets.all(
                                    ResponsiveUtils.getHorizontalPadding(context),
                                  ),
                                  child: Column(
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4, bottom: 6),
                                        child: Text(
                                          'Your Recovery Phrase',
                                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: GridView.builder(
                                          padding: const EdgeInsets.symmetric(horizontal: 4),
                                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                            crossAxisCount: 3, // Always 3 columns for 24 words
                                            childAspectRatio: 2.8, // More compact aspect ratio for mobile
                                            crossAxisSpacing: 4,
                                            mainAxisSpacing: 4,
                                          ),
                                          itemCount: _seedWords.length,
                                          itemBuilder: (context, index) {
                                            return Container(
                                              decoration: BoxDecoration(
                                                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Row(
                                                children: [
                                                  Container(
                                                    width: 18,
                                                    height: double.infinity,
                                                    decoration: BoxDecoration(
                                                      color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                                                      borderRadius: const BorderRadius.only(
                                                        topLeft: Radius.circular(4),
                                                        bottomLeft: Radius.circular(4),
                                                      ),
                                                    ),
                                                    child: Center(
                                                      child: Text(
                                                        '${index + 1}',
                                                        style: TextStyle(
                                                          fontSize: 9,
                                                          fontWeight: FontWeight.bold,
                                                          color: Theme.of(context).colorScheme.primary,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    child: Padding(
                                                      padding: const EdgeInsets.symmetric(horizontal: 3),
                                                      child: Center(
                                                        child: Text(
                                                          _seedWords[index],
                                                          style: const TextStyle(
                                                            fontSize: 10,
                                                            fontWeight: FontWeight.w500,
                                                            fontFamily: 'monospace',
                                                          ),
                                                          textAlign: TextAlign.center,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ),
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
                                ),
                              );
                            },
                          )
                        : Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.visibility_off,
                                  size: ResponsiveUtils.getIconSize(context, base: 64),
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                                SizedBox(height: ResponsiveUtils.isSmallScreen(context) ? 12 : 16),
                                Text(
                                  'Recovery Phrase Hidden',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.outline,
                                    fontSize: ResponsiveUtils.getTitleTextSize(context) * 0.8,
                                  ),
                                ),
                                SizedBox(height: ResponsiveUtils.isSmallScreen(context) ? 6 : 8),
                                Text(
                                  'Make sure no one is looking at your screen',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.outline,
                                    fontSize: ResponsiveUtils.getBodyTextSize(context),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: ResponsiveUtils.isSmallScreen(context) ? 16 : 24),
                                ElevatedButton.icon(
                                  onPressed: _revealSeedPhrase,
                                  icon: const Icon(Icons.visibility),
                                  label: const Text('Reveal Recovery Phrase'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Theme.of(context).colorScheme.primary,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ),

                // Compact Acknowledgment and Continue
                if (_isRevealed) ...[
                  const SizedBox(height: 8),
                  // Compact Acknowledgment Checkbox
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Transform.scale(
                          scale: 0.7,
                          child: Checkbox(
                            value: _hasAcknowledged,
                            onChanged: (_) => _acknowledgeBackup(),
                            activeColor: Theme.of(context).colorScheme.primary,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: GestureDetector(
                            onTap: _acknowledgeBackup,
                            child: Text(
                              'I have written down my recovery phrase and stored it in a safe place',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                        
                  // Compact Continue Button
                  SizedBox(
                    width: double.infinity,
                    height: 40,
                    child: ElevatedButton(
                      onPressed: _hasAcknowledged ? _proceedToVerification : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        elevation: _hasAcknowledged ? 4 : 0,
                      ),
                      child: const Text(
                        'Continue',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}