import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/responsive.dart';

class BackupSeedDisplayScreen extends StatefulWidget {
  final String seedPhrase;
  final int? birthdayBlock;

  const BackupSeedDisplayScreen({
    super.key,
    required this.seedPhrase,
    this.birthdayBlock,
  });

  @override
  State<BackupSeedDisplayScreen> createState() => _BackupSeedDisplayScreenState();
}

class _BackupSeedDisplayScreenState extends State<BackupSeedDisplayScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _revealController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _revealAnimation;
  
  bool _isRevealed = false;

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

  List<String> get _seedWords => widget.seedPhrase.split(' ');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup Recovery Phrase'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 48.0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
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
                // Security Warning Section
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.red.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.security,
                        color: Colors.red,
                        size: 32,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Keep This Information Secret',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Anyone with access to this recovery phrase can access your wallet and funds. Write it down and store it securely offline.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.red.shade300,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                // Birthday Block Display (if available)
                if (widget.birthdayBlock != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.cake_outlined,
                          color: Theme.of(context).colorScheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Wallet Birthday Block',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Block #${widget.birthdayBlock}',
                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'monospace',
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Save this number along with your seed phrase for faster wallet restoration.',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.primary.withOpacity(0.8),
                                  fontSize: 11,
                                ),
                              ),
                            ],
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
                                        padding: const EdgeInsets.only(top: 8, bottom: 12),
                                        child: Text(
                                          'Your Recovery Phrase',
                                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: GridView.builder(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: ResponsiveUtils.getHorizontalPadding(context) * 0.5,
                                          ),
                                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                            crossAxisCount: ResponsiveUtils.getSeedPhraseGridColumns(context),
                                            childAspectRatio: ResponsiveUtils.getSeedPhraseAspectRatio(context),
                                            crossAxisSpacing: ResponsiveUtils.getSeedPhraseSpacing(context),
                                            mainAxisSpacing: ResponsiveUtils.getSeedPhraseSpacing(context),
                                          ),
                                          itemCount: _seedWords.length,
                                          itemBuilder: (context, index) {
                                            return Container(
                                              decoration: BoxDecoration(
                                                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Row(
                                                children: [
                                                  Container(
                                                    width: 22,
                                                    height: double.infinity,
                                                    decoration: BoxDecoration(
                                                      color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                                                      borderRadius: const BorderRadius.only(
                                                        topLeft: Radius.circular(6),
                                                        bottomLeft: Radius.circular(6),
                                                      ),
                                                    ),
                                                    child: Center(
                                                      child: Text(
                                                        '${index + 1}',
                                                        style: TextStyle(
                                                          fontSize: ResponsiveUtils.getSeedNumberTextSize(context),
                                                          fontWeight: FontWeight.bold,
                                                          color: Theme.of(context).colorScheme.primary,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    child: Padding(
                                                      padding: const EdgeInsets.symmetric(horizontal: 4),
                                                      child: Center(
                                                        child: Text(
                                                          _seedWords[index],
                                                          style: TextStyle(
                                                            fontSize: ResponsiveUtils.getSeedWordTextSize(context),
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

                // Bottom spacing
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}