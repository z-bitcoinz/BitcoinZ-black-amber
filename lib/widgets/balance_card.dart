import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import '../providers/wallet_provider.dart';
import '../providers/currency_provider.dart';

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
              // Main card with glassmorphism
              ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF2A2A2A).withOpacity(0.95),
                          const Color(0xFF1F1F1F).withOpacity(0.9),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.08),
                        width: 1,
                      ),
                      boxShadow: [
                        // Inner shadow for depth
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 20,
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
                    
                    AnimatedBuilder(
                      animation: _shimmerAnimation,
                      builder: (context, child) {
                        return ShaderMask(
                          shaderCallback: (bounds) {
                            return LinearGradient(
                              colors: [
                                Colors.white,
                                Colors.white.withOpacity(0.9),
                                Colors.white,
                              ],
                              stops: [
                                _shimmerAnimation.value - 0.3,
                                _shimmerAnimation.value,
                                _shimmerAnimation.value + 0.3,
                              ],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ).createShader(bounds);
                          },
                          child: Text(
                            walletProvider.balance.formattedTotal,  // Always show balance (defaults to 0)
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -1,
                              height: 1.2,
                            ),
                          ),
                        );
                      },
                    ),
                    
                    // Show fiat value if available
                    if (walletProvider.hasWallet && currencyProvider.currentPrice != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        currencyProvider.formatFiatAmount(walletProvider.balance.total),
                        style: TextStyle(
                          color: const Color(0xFFFF6B00).withOpacity(0.9),
                          fontSize: 20,
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
    final hasUnconfirmed = isTransparent 
        ? walletProvider.balance.hasUnconfirmedTransparentBalance
        : walletProvider.balance.hasUnconfirmedShieldedBalance;
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
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            amount,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.5,
            ),
          ),
          // Removed redundant "Confirming:" display from balance columns
          // This is already shown on the main dashboard
        ],
      ),
    );
  }
}