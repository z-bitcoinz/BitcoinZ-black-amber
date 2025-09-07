import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import 'dart:io';
import '../providers/wallet_provider.dart';
import '../providers/currency_provider.dart';
import '../providers/interface_provider.dart';

import '../utils/responsive.dart';
import 'animated_progress_dots.dart';
import '../screens/settings/settings_screen.dart';

class BalanceCard extends StatefulWidget {
  const BalanceCard({super.key});

  @override
  State<BalanceCard> createState() => _BalanceCardState();
}

class _BalanceCardState extends State<BalanceCard> with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _shimmerAnimation = Tween<double>(
      begin: -1.0,
      end: 2.0,
    ).animate(CurvedAnimation(
      parent: _shimmerController,
      curve: Curves.easeInOut,
    ));
    _shimmerController.repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<WalletProvider, CurrencyProvider>(
      builder: (context, walletProvider, currencyProvider, child) {
        return Container(
          width: double.infinity,
          child: Stack(
            children: [
              // Glow effect behind the card
              Positioned.fill(
                child: Container(
                  margin: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF6B00).withOpacity(0.1),
                        blurRadius: 60,
                        spreadRadius: 0,
                        offset: const Offset(0, 20),
                      ),
                    ],
                  ),
                ),
              ),
              // Main card with clean glassmorphism - NO BackdropFilter!
              Container(
                  padding: EdgeInsets.fromLTRB(
                    24,
                    ResponsiveUtils.getBalanceTopPadding(context),
                    24,
                    24
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF2A2A2A).withOpacity(0.95),
                        const Color(0xFF1F1F1F).withOpacity(0.9),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(28), // Visual rounding only, no clipping
                    border: Border.all(
                      color: Colors.white.withOpacity(0.08),
                      width: 1,
                    ),
                    boxShadow: [
                      // Multiple shadow layers for depth without blur bleeding
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 15,
                        spreadRadius: -5,
                        offset: const Offset(0, 8),
                      ),
                      BoxShadow(
                        color: Colors.white.withOpacity(0.1),
                        blurRadius: 10,
                        spreadRadius: -8,
                        offset: const Offset(0, -2),
                      ),
                      BoxShadow(
                        color: const Color(0xFFFF6B00).withOpacity(0.1),
                        blurRadius: 20,
                        spreadRadius: -10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Total Balance Section
                      Text(
                        'Total Balance',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),

                      // Simplified balance text with explicit height - NO COMPLEX EFFECTS!
                      Container(
                        height: ResponsiveUtils.getBalanceContainerHeight(context),
                        child: Center(
                          child: _buildAmountText(
                            walletProvider.balance.formattedTotal,
                            fontSize: ResponsiveUtils.getBalanceTextSize(context),
                            height: ResponsiveUtils.getBalanceTextHeight(context),
                            fontWeight: FontWeight.bold,
                            letterSpacing: Platform.isIOS || Platform.isAndroid ? -0.5 : -1,
                          ),
                        ),
                      ),

                    // Show fiat value if available
                    if (walletProvider.hasWallet && currencyProvider.currentPrice != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        currencyProvider.formatFiatAmount(walletProvider.balance.total),
                        style: TextStyle(
                          color: const Color(0xFFFF6B00).withOpacity(0.9),
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        currencyProvider.selectedCurrency.name,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),

                    // Divider
                    Container(
                      height: 1,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withOpacity(0),
                            Colors.white.withOpacity(0.2),
                            Colors.white.withOpacity(0),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Transparent vs Shielded breakdown
                    Row(
                      children: [
                        Expanded(
                          child: _buildBalanceColumn(
                            context,
                            'Transparent',
                            walletProvider.balance.formattedTransparent,
                            Icons.visibility_outlined,
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 40,
                          color: Colors.white.withOpacity(0.2),
                        ),
                        Expanded(
                          child: _buildBalanceColumn(
                            context,
                            'Shielded',
                            walletProvider.balance.formattedShielded,
                            Icons.shield_outlined,
                          ),
                        ),
                      ],
                    ),

                    // Removed redundant "Confirming:" display from balance card
                    // This is already shown on the main dashboard
                  ],
                ),
              ),
              // Settings icon positioned in top-right corner
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.settings,
                      color: Colors.white.withOpacity(0.8),
                      size: 20,
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SettingsScreen(),
                        ),
                      );
                    },
                    tooltip: 'Settings',
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBalanceColumn(BuildContext context, String label, String amount, IconData icon) {
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    final isTransparent = label == 'Transparent';
    // Only show dots for incoming unconfirmed transactions (not outgoing)
    final hasUnconfirmed = isTransparent
        ? walletProvider.balance.hasIncomingUnconfirmedTransparentBalance
        : walletProvider.balance.hasIncomingUnconfirmedShieldedBalance;
    final unconfirmedAmount = isTransparent
        ? walletProvider.balance.formattedUnconfirmedTransparent
        : walletProvider.balance.formattedUnconfirmedShielded;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: Colors.white.withOpacity(0.6),
                size: 14,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _buildAmountText(
            amount,
            fontSize: 24,
            height: 1.2,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.5,
          ),
          // Show progress dots when this balance type has unconfirmed transactions
          if (hasUnconfirmed || walletProvider.isLoading || walletProvider.isSyncing) ...[
            const SizedBox(height: 4),
            const AnimatedProgressDots(),
          ],
          // Removed redundant "Confirming:" display from balance columns
          // This is already shown on the main dashboard
        ],
      ),
    );
  }

  /// Builds a RichText where the decimal part is rendered smaller
  Widget _buildAmountText(
    String amount, {
    required double fontSize,
    required double height,
    FontWeight fontWeight = FontWeight.w600,
    double letterSpacing = -0.5,
    Color color = Colors.white,
  }) {
    final interfaceProvider = Provider.of<InterfaceProvider>(context, listen: false);
    final showDecimals = interfaceProvider.showDecimals;

    // Split integer and fractional parts
    String integerPart = amount;
    String fractionalPart = '';
    final dotIndex = amount.indexOf('.');
    if (dotIndex != -1) {
      integerPart = amount.substring(0, dotIndex);
      fractionalPart = amount.substring(dotIndex); // keep the dot with decimals
    }

    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
          letterSpacing: letterSpacing,
          height: height,
        ),
        children: [
          TextSpan(text: integerPart),
          if (showDecimals && fractionalPart.isNotEmpty)
            TextSpan(
              text: fractionalPart,
              style: TextStyle(
                fontSize: fontSize * 0.6, // smaller decimals
                fontWeight: fontWeight,
                letterSpacing: letterSpacing,
              ),
            ),
        ],
      ),
    );
  }
}