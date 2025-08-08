import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/wallet_provider.dart';
import '../../utils/responsive.dart';

class SendScreen extends StatefulWidget {
  const SendScreen({super.key});

  @override
  State<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  
  final _formKey = GlobalKey<FormState>();
  final _addressController = TextEditingController();
  final _amountController = TextEditingController();
  final _memoController = TextEditingController();
  
  bool _isSending = false;
  String? _errorMessage;
  bool _isShieldedTransaction = false;
  double _estimatedFee = 0.001; // Default fee
  
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

    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _addressController.dispose();
    _amountController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  bool _isValidBitcoinZAddress(String address) {
    // Basic validation for BitcoinZ addresses
    if (address.isEmpty) return false;
    
    // Transparent addresses start with 't1' or 'R'
    if (address.startsWith('t1') && address.length >= 34) {
      return true;
    }
    
    // Shielded addresses start with 'zc' or 'zs'
    if ((address.startsWith('zc') || address.startsWith('zs')) && address.length >= 60) {
      setState(() {
        _isShieldedTransaction = true;
      });
      return true;
    }
    
    return false;
  }

  double? _getAmountValue() {
    final text = _amountController.text.trim();
    if (text.isEmpty) return null;
    return double.tryParse(text);
  }

  bool _canSend(WalletProvider walletProvider) {
    final amount = _getAmountValue();
    if (amount == null || amount <= 0) return false;
    
    final totalNeeded = amount + _estimatedFee;
    return walletProvider.balance.spendable >= totalNeeded;
  }

  Future<void> _scanQRCode() async {
    try {
      // For now, show a placeholder dialog
      // In a real implementation, you would use qr_code_scanner package
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('QR Scanner'),
          content: const Text(
            'QR Code scanning would be implemented here using the device camera. '
            'For now, please enter the address manually.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to open QR scanner: $e';
      });
    }
  }

  Future<void> _sendTransaction() async {
    if (!_formKey.currentState!.validate() || _isSending) return;
    
    setState(() {
      _isSending = true;
      _errorMessage = null;
    });

    try {
      final amount = _getAmountValue()!;
      final address = _addressController.text.trim();
      final memo = _memoController.text.trim();
      
      final walletProvider = Provider.of<WalletProvider>(context, listen: false);
      
      final result = await walletProvider.sendTransaction(
        toAddress: address,
        amount: amount,
        memo: memo.isNotEmpty ? memo : null,
      );

      if (result != null && mounted) {
        // Show success dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Transaction Sent'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text('Transaction ID: ${result.substring(0, 8)}...'),
                const SizedBox(height: 8),
                const Text('Your transaction has been broadcast to the network.'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _resetForm();
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to send transaction: $e';
          _isSending = false;
        });
      }
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _addressController.clear();
    _amountController.clear();
    _memoController.clear();
    setState(() {
      _errorMessage = null;
      _isShieldedTransaction = false;
      _isSending = false;
    });
  }

  void _setMaxAmount(WalletProvider walletProvider) {
    final maxAmount = walletProvider.balance.spendable - _estimatedFee;
    if (maxAmount > 0) {
      _amountController.text = maxAmount.toStringAsFixed(8);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Send BitcoinZ'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: _scanQRCode,
            tooltip: 'Scan QR Code',
          ),
        ],
      ),
      body: SafeArea(
        child: Consumer<WalletProvider>(
          builder: (context, walletProvider, child) {
            return Padding(
              padding: ResponsiveUtils.getScreenPadding(context),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Balance Display
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(ResponsiveUtils.getCardBorderRadius(context)),
                            child: Container(
                              padding: EdgeInsets.all(ResponsiveUtils.getHorizontalPadding(context)),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                    Theme.of(context).colorScheme.secondary.withOpacity(0.05),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(ResponsiveUtils.getCardBorderRadius(context)),
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                    blurRadius: 15,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    'Balance',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      color: Theme.of(context).colorScheme.primary.withOpacity(0.8),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  SizedBox(height: ResponsiveUtils.isSmallScreen(context) ? 4 : 8),
                                  
                                  // Spendable Balance (main)
                                  Text(
                                    '${walletProvider.balance.formattedSpendable} BTCZ',
                                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                      color: Theme.of(context).colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  
                                  // Total Balance (secondary)
                                  if (walletProvider.balance.spendable != walletProvider.balance.total) ...[
                                    SizedBox(height: ResponsiveUtils.isSmallScreen(context) ? 2 : 4),
                                    Text(
                                      'Total: ${walletProvider.balance.formattedTotal} BTCZ',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                  
                                  // Spendable label
                                  SizedBox(height: ResponsiveUtils.isSmallScreen(context) ? 2 : 4),
                                  Text(
                                    'Available to Send',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        
                        SizedBox(height: ResponsiveUtils.isSmallScreen(context) ? 24 : 32),
                        
                        // Recipient Address
                        Text(
                          'Recipient Address',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: ResponsiveUtils.isSmallScreen(context) ? 8 : 12),
                        
                        TextFormField(
                          controller: _addressController,
                          decoration: InputDecoration(
                            hintText: 'Enter BitcoinZ address',
                            prefixIcon: const Icon(Icons.account_balance_wallet),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.qr_code_scanner),
                              onPressed: _scanQRCode,
                            ),
                            filled: true,
                            fillColor: Theme.of(context).colorScheme.surface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(ResponsiveUtils.getCardBorderRadius(context) * 0.75),
                            ),
                            contentPadding: ResponsiveUtils.getInputFieldPadding(context),
                          ),
                          style: TextStyle(
                            fontSize: ResponsiveUtils.getBodyTextSize(context) * 0.9,
                            fontFamily: 'monospace',
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter a recipient address';
                            }
                            if (!_isValidBitcoinZAddress(value.trim())) {
                              return 'Please enter a valid BitcoinZ address';
                            }
                            return null;
                          },
                          onChanged: (value) {
                            setState(() {
                              _errorMessage = null;
                              _isShieldedTransaction = value.startsWith('zc') || value.startsWith('zs');
                            });
                          },
                        ),
                        
                        SizedBox(height: ResponsiveUtils.isSmallScreen(context) ? 20 : 24),
                        
                        // Amount
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Amount',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            TextButton(
                              onPressed: () => _setMaxAmount(walletProvider),
                              child: Text(
                                'MAX',
                                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: ResponsiveUtils.isSmallScreen(context) ? 8 : 12),
                        
                        TextFormField(
                          controller: _amountController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            hintText: '0.00000000',
                            suffixText: 'BTCZ',
                            suffixStyle: TextStyle(
                              fontSize: ResponsiveUtils.getBodyTextSize(context),
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            filled: true,
                            fillColor: Theme.of(context).colorScheme.surface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(ResponsiveUtils.getCardBorderRadius(context) * 0.75),
                            ),
                            contentPadding: ResponsiveUtils.getInputFieldPadding(context),
                          ),
                          style: TextStyle(
                            fontSize: ResponsiveUtils.getTitleTextSize(context),
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter an amount';
                            }
                            final amount = double.tryParse(value.trim());
                            if (amount == null || amount <= 0) {
                              return 'Please enter a valid amount';
                            }
                            final totalNeeded = amount + _estimatedFee;
                            if (totalNeeded > walletProvider.balance.spendable) {
                              return 'Insufficient balance (including fee)';
                            }
                            return null;
                          },
                          onChanged: (value) {
                            setState(() {
                              _errorMessage = null;
                            });
                          },
                        ),
                        
                        // Fee Display
                        SizedBox(height: ResponsiveUtils.isSmallScreen(context) ? 12 : 16),
                        Container(
                          padding: EdgeInsets.all(ResponsiveUtils.getHorizontalPadding(context) * 0.75),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(ResponsiveUtils.getCardBorderRadius(context) * 0.5),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Network Fee',
                                style: TextStyle(
                                  fontSize: ResponsiveUtils.getBodyTextSize(context) * 0.9,
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                ),
                              ),
                              Text(
                                '${_estimatedFee.toStringAsFixed(8)} BTCZ',
                                style: TextStyle(
                                  fontSize: ResponsiveUtils.getBodyTextSize(context) * 0.9,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Memo (for shielded transactions)
                        if (_isShieldedTransaction) ...[
                          SizedBox(height: ResponsiveUtils.isSmallScreen(context) ? 20 : 24),
                          
                          Text(
                            'Memo (Optional)',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: ResponsiveUtils.isSmallScreen(context) ? 8 : 12),
                          
                          TextFormField(
                            controller: _memoController,
                            maxLines: 3,
                            maxLength: 512,
                            decoration: InputDecoration(
                              hintText: 'Enter optional memo for shielded transaction',
                              filled: true,
                              fillColor: Theme.of(context).colorScheme.surface,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(ResponsiveUtils.getCardBorderRadius(context) * 0.75),
                              ),
                              contentPadding: ResponsiveUtils.getInputFieldPadding(context),
                            ),
                            style: TextStyle(
                              fontSize: ResponsiveUtils.getBodyTextSize(context),
                            ),
                          ),
                        ],
                        
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
                        
                        // Send Button
                        SizedBox(height: ResponsiveUtils.isSmallScreen(context) ? 32 : 40),
                        
                        SizedBox(
                          width: double.infinity,
                          height: ResponsiveUtils.getButtonHeight(context),
                          child: ElevatedButton(
                            onPressed: (_isSending || !_canSend(walletProvider)) ? null : _sendTransaction,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  ResponsiveUtils.getButtonBorderRadius(context),
                                ),
                              ),
                              elevation: _isSending ? 0 : 4,
                            ),
                            child: _isSending
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
                                        'Sending...',
                                        style: TextStyle(
                                          fontSize: ResponsiveUtils.getBodyTextSize(context),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  )
                                : Text(
                                    'Send BitcoinZ',
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
            );
          },
        ),
      ),
    );
  }
}