import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import '../utils/formatters.dart';

class TransactionConfirmationDialog extends StatefulWidget {
  final String toAddress;
  final double amount;
  final double fee;
  final double? fiatAmount;
  final String? currencyCode;
  final String? contactName; // Optional friendly recipient name
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const TransactionConfirmationDialog({
    super.key,
    required this.toAddress,
    required this.amount,
    required this.fee,
    this.fiatAmount,
    this.currencyCode,
    this.contactName,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  State<TransactionConfirmationDialog> createState() => _TransactionConfirmationDialogState();
}

class _TransactionConfirmationDialogState extends State<TransactionConfirmationDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  String _formatAddress(String address) {
    if (address.length <= 16) return address;
    return '${address.substring(0, 8)}...${address.substring(address.length - 8)}';
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.amount + widget.fee;
    
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 400),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                      blurRadius: 40,
                      offset: const Offset(0, 20),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      padding: const EdgeInsets.all(20),
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
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Header
                          Container(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.security,
                                  color: Theme.of(context).colorScheme.primary,
                                  size: 36,
                                ),
                                const SizedBox(width: 10),
                                const Text(
                                  'CONFIRM TRANSACTION',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          // Transaction Details Card
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.05),
                              ),
                            ),
                            child: Column(
                              children: [
                                // Recipient (name if available, else address)
                                if (widget.contactName != null && widget.contactName!.isNotEmpty) ...[
                                  _buildDetailRow(
                                    context,
                                    'RECIPIENT',
                                    widget.contactName!,
                                    Icons.person_outline,
                                  ),
                                  const SizedBox(height: 12),
                                  _buildDivider(),
                                  const SizedBox(height: 12),
                                ],
                                _buildDetailRow(
                                  context,
                                  widget.contactName != null && widget.contactName!.isNotEmpty ? 'ADDRESS' : 'SEND TO',
                                  _formatAddress(widget.toAddress),
                                  Icons.account_balance_wallet_outlined,
                                  isAddress: true,
                                  fullAddress: widget.toAddress,
                                ),
                                
                                const SizedBox(height: 12),
                                _buildDivider(),
                                const SizedBox(height: 12),
                                
                                // Amount
                                _buildDetailRow(
                                  context,
                                  'AMOUNT',
                                  Formatters.formatBtczTrim(widget.amount),
                                  Icons.monetization_on_outlined,
                                  isAmount: true,
                                  subtitle: widget.fiatAmount != null && widget.currencyCode != null
                                      ? '≈ ${widget.fiatAmount!.toStringAsFixed(2)} ${widget.currencyCode}'
                                      : null,
                                ),
                                
                                const SizedBox(height: 12),
                                
                                // Network Fee
                                _buildDetailRow(
                                  context,
                                  'NETWORK FEE',
                                  Formatters.formatBtczTrim(widget.fee),
                                  Icons.speed_outlined,
                                  isSubtle: true,
                                ),
                                
                                const SizedBox(height: 12),
                                _buildDivider(),
                                const SizedBox(height: 12),
                                
                                // Total
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'TOTAL',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.7),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          Formatters.formatBtczTrim(total),
                                          style: TextStyle(
                                            color: Theme.of(context).colorScheme.primary,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            fontFamily: 'monospace',
                                          ),
                                        ),
                                        if (widget.fiatAmount != null && widget.currencyCode != null) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            '≈ ${(widget.fiatAmount! * (total / widget.amount)).toStringAsFixed(2)} ${widget.currencyCode}',
                                            style: TextStyle(
                                              color: Theme.of(context).colorScheme.primary.withOpacity(0.8),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Action Buttons
                          Row(
                            children: [
                              // Cancel Button
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8), // Sharp corners
                                    gradient: LinearGradient(
                                      colors: [
                                        const Color(0xFF1A1A1A), // Deeper dark color
                                        const Color(0xFF0F0F0F), // Even deeper
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.2),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(8), // Sharp corners
                                      onTap: () {
                                        widget.onCancel();
                                        Navigator.of(context).pop();
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        child: const Text(
                                          'Cancel',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700, // Sharper font weight
                                            letterSpacing: 1.0, // More spacing
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              
                              const SizedBox(width: 12),
                              
                              // Confirm Button
                              Expanded(
                                flex: 2,
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8), // Sharp corners
                                    gradient: LinearGradient(
                                      colors: [
                                        const Color(0xFFFF6B00), // Same orange as Send Transaction
                                        const Color(0xFFFFAA00), // Same orange gradient
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    border: Border.all(
                                      color: const Color(0xFFFF6B00).withOpacity(0.6),
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFFF6B00).withOpacity(0.3),
                                        blurRadius: 20,
                                        offset: const Offset(0, 8),
                                      ),
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(8), // Sharp corners
                                      onTap: () {
                                        Navigator.of(context).pop();
                                        widget.onConfirm();
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const Icon(
                                              Icons.check_circle_outline,
                                              color: Colors.white,
                                              size: 20,
                                            ),
                                            const SizedBox(width: 8),
                                            const Text(
                                              'Confirm & Send',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700, // Sharper font weight
                                                letterSpacing: 1.0, // More spacing
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 8),
                          
                          // Security Note
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.lock_outline,
                                size: 12,
                                color: Colors.white.withOpacity(0.4),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Transaction will be securely broadcasted',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.4),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildDetailRow(
    BuildContext context,
    String label,
    String value,
    IconData icon, {
    bool isAddress = false,
    String? fullAddress,
    bool isAmount = false,
    bool isSubtle = false,
    String? subtitle,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isAmount 
                ? Theme.of(context).colorScheme.primary.withOpacity(0.15)
                : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 18,
            color: isAmount 
                ? Theme.of(context).colorScheme.primary
                : Colors.white.withOpacity(0.6),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            value,
                            style: TextStyle(
                              color: isSubtle 
                                  ? Colors.white.withOpacity(0.6)
                                  : Colors.white,
                              fontSize: isAmount ? 16 : 14,
                              fontWeight: isAmount ? FontWeight.bold : FontWeight.w500,
                              fontFamily: isAddress || isAmount ? 'monospace' : null,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary.withOpacity(0.8),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (isAddress) ...[
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: IconButton(
                          icon: Icon(
                            Icons.copy,
                            size: 16,
                            color: Colors.white.withOpacity(0.7),
                          ),
                          padding: const EdgeInsets.all(8),
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: fullAddress ?? value));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Address copied to clipboard'),
                                duration: const Duration(seconds: 2),
                                backgroundColor: Colors.green.shade600,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildDivider() {
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0),
            Colors.white.withOpacity(0.1),
            Colors.white.withOpacity(0),
          ],
        ),
      ),
    );
  }
}