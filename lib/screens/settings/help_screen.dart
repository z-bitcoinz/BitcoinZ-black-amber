import 'package:flutter/material.dart';
import 'dart:ui';

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  final Map<String, bool> _expandedSections = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: AppBar(
              backgroundColor: const Color(0xFF1A1A1A).withOpacity(0.8),
              elevation: 0,
              toolbarHeight: 60,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: const Text(
                'Help & Support',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              flexibleSpace: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF1F1F1F).withOpacity(0.8),
                      const Color(0xFF151515).withOpacity(0.6),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.white.withOpacity(0.05),
                      width: 1,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: 80, left: 16, right: 16, bottom: 20),
        children: [
          // Introduction
          _buildIntroCard(),
          const SizedBox(height: 24),
          
          // Balance Types Section
          _buildHelpSection(
            'balance_types',
            'Balance Types',
            Icons.account_balance_wallet,
            [
              _buildHelpItem(
                'Total Balance',
                'Your complete BitcoinZ holdings across all address types.',
                'This includes both transparent (T-addresses) and shielded (Z-addresses) funds. It represents everything you own, regardless of confirmation status.',
              ),
              _buildHelpItem(
                'Spendable Balance',
                'Funds you can immediately send to others.',
                'Only includes confirmed funds with sufficient confirmations:\n• Transparent: 1+ confirmations\n• Shielded: 2+ confirmations\n\nThis is the amount available for new transactions.',
              ),
              _buildHelpItem(
                'Verified Balance', 
                'Funds that have reached required confirmations.',
                'These funds have been confirmed by the network but may not all be spendable yet if you have pending outgoing transactions.',
              ),
              _buildHelpItem(
                'Unconfirmed Balance',
                'Recently received funds waiting for network confirmation.',
                'New transactions appear here immediately but need confirmations before becoming spendable. This helps you track incoming payments.',
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Transaction States Section
          _buildHelpSection(
            'transaction_states',
            'Transaction States',
            Icons.swap_horiz,
            [
              _buildHelpItem(
                'Confirmed',
                'Transactions with sufficient network confirmations.',
                'These transactions are permanently recorded on the blockchain and cannot be reversed. Your funds are secure and spendable.',
              ),
              _buildHelpItem(
                'Confirming',
                'Transactions waiting for network confirmations.',
                'Recently sent or received transactions that are in the mempool. They will become confirmed as new blocks are mined.',
              ),
              _buildHelpItem(
                'Change Returning',
                'Your change from outgoing transactions.',
                'When you send BitcoinZ, any unused amount returns to you as change. This shows change that\'s still confirming and will become spendable soon.',
              ),
              _buildHelpItem(
                'Incoming',
                'New funds being received from others.',
                'Payments you\'re receiving that aren\'t change from your own transactions. These funds will become spendable once confirmed.',
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Confirmations Section
          _buildHelpSection(
            'confirmations',
            'Network Confirmations',
            Icons.security,
            [
              _buildHelpItem(
                'Why Confirmations Matter',
                'Confirmations provide security against double-spending attacks.',
                'Each confirmation represents a new block mined on top of your transaction, making it exponentially harder to reverse.',
              ),
              _buildHelpItem(
                'Transparent Addresses (T-addresses)',
                'Require 1 confirmation to be spendable.',
                'T-addresses are like Bitcoin addresses. They offer fast confirmation but transactions are visible on the public blockchain.',
              ),
              _buildHelpItem(
                'Shielded Addresses (Z-addresses)',
                'Require 2 confirmations to be spendable.',
                'Z-addresses provide privacy by hiding transaction amounts and participants. The extra confirmation provides additional security for private transactions.',
              ),
              _buildHelpItem(
                'Network Security',
                'More confirmations = higher security.',
                'While 1-2 confirmations are required for spending, large amounts may warrant waiting for more confirmations for maximum security.',
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Address Types Section
          _buildHelpSection(
            'address_types',
            'Address Types',
            Icons.location_on,
            [
              _buildHelpItem(
                'Transparent Addresses (T)',
                'Public addresses similar to Bitcoin.',
                'Start with "t1". Transactions are visible on the blockchain but confirm quickly with 1 confirmation required.',
              ),
              _buildHelpItem(
                'Shielded Addresses (Z)',
                'Private addresses that hide transaction details.',
                'Start with "zs1". Provide privacy by hiding amounts and participants. Require 2 confirmations for added security.',
              ),
              _buildHelpItem(
                'When to Use Each Type',
                'Choose based on your privacy and speed needs.',
                'Use T-addresses for fast, public transactions. Use Z-addresses when privacy is important and you can wait for extra confirmations.',
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Common Questions Section
          _buildHelpSection(
            'common_questions',
            'Common Questions',
            Icons.help_outline,
            [
              _buildHelpItem(
                'Why do my balances show different amounts?',
                'Different balance types serve different purposes.',
                'Total shows everything you own, Spendable shows what you can send now, and Unconfirmed shows recent activity waiting for confirmations.',
              ),
              _buildHelpItem(
                'Why can\'t I spend my full balance?',
                'Some funds may still be confirming.',
                'Recent transactions need confirmations before becoming spendable. Check your "Change Returning" and "Incoming" amounts.',
              ),
              _buildHelpItem(
                'How long do confirmations take?',
                'Usually 1-10 minutes per confirmation.',
                'BitcoinZ blocks are mined approximately every 2.5 minutes. Network congestion can cause delays.',
              ),
              _buildHelpItem(
                'Is my transaction lost if it takes time?',
                'No, transactions in "Confirming" status are safe.',
                'They\'re in the network mempool and will be confirmed when miners include them in a block. Be patient during busy network periods.',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIntroCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary.withOpacity(0.1),
            Theme.of(context).colorScheme.primary.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info,
                color: Theme.of(context).colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Understanding Your Wallet',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'This guide explains the different balance types and transaction states you\'ll see in your BitcoinZ wallet. Understanding these concepts will help you track your funds and understand why balances may appear different.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpSection(String sectionId, String title, IconData icon, List<Widget> items) {
    final isExpanded = _expandedSections[sectionId] ?? false;
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF2A2A2A).withOpacity(0.4),
            const Color(0xFF1F1F1F).withOpacity(0.3),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.vertical(
                top: const Radius.circular(16),
                bottom: isExpanded ? Radius.zero : const Radius.circular(16),
              ),
              onTap: () {
                setState(() {
                  _expandedSections[sectionId] = !isExpanded;
                });
              },
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        icon,
                        color: Theme.of(context).colorScheme.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: Colors.white.withOpacity(0.6),
                      size: 24,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (isExpanded) ...[
            Container(
              width: double.infinity,
              height: 1,
              color: Colors.white.withOpacity(0.05),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: item,
                )).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHelpItem(String title, String summary, String details) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.05),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            summary,
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            details,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}