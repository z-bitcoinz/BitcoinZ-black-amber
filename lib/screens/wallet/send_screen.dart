import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import 'dart:async';
import '../../providers/wallet_provider.dart';
import '../../providers/currency_provider.dart';
import '../../utils/responsive.dart';
import '../../widgets/transaction_success_dialog.dart';
import '../../widgets/transaction_confirmation_dialog.dart';
import '../../widgets/sending_progress_overlay.dart';

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
  bool _isFiatInput = false; // Toggle for fiat/BTCZ input

  // Transaction progress states
  String _sendingStatus = '';
  double _sendingProgress = 0.0;
  late AnimationController _buttonAnimationController;
  late Animation<double> _buttonScaleAnimation;

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

    _buttonAnimationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _buttonScaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _buttonAnimationController,
      curve: Curves.easeInOut,
    ));

    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _buttonAnimationController.dispose();
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
    final parsed = double.tryParse(text);
    if (parsed == null) return null;

    // Convert fiat to BTCZ if in fiat mode
    if (_isFiatInput) {
      final currencyProvider = Provider.of<CurrencyProvider>(context, listen: false);
      return currencyProvider.convertFiatToBtcz(parsed);
    }
    return parsed;
  }

  bool _canSend(WalletProvider walletProvider) {
    final amount = _getAmountValue();
    if (amount == null || amount <= 0) {
      if (kDebugMode) print('🚫 CAN_SEND: Invalid amount ($amount)');
      return false;
    }

    final totalNeeded = amount + _estimatedFee;
    final canSend = walletProvider.balance.spendable >= totalNeeded;

    if (kDebugMode) {
      print('🔍 CAN_SEND CHECK:');
      print('   Amount: $amount BTCZ');
      print('   Estimated Fee: $_estimatedFee BTCZ');
      print('   Total Needed: $totalNeeded BTCZ');
      print('   Spendable Balance: ${walletProvider.balance.spendable} BTCZ');
      print('   Can Send: $canSend');
    }

    return canSend;
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

    // Animate button press
    _buttonAnimationController.forward().then((_) {
      _buttonAnimationController.reverse();
    });

    // Get transaction details
    final amount = _getAmountValue()!;
    final address = _addressController.text.trim();

    // Get fiat amount if available
    final currencyProvider = Provider.of<CurrencyProvider>(context, listen: false);
    double? fiatAmount;
    String? currencyCode;

    if (currencyProvider.currentPrice != null) {
      if (_isFiatInput) {
        // User entered fiat, so parse the text directly for fiat amount
        fiatAmount = double.tryParse(_amountController.text.trim());
      } else {
        // User entered BTCZ, convert to fiat
        fiatAmount = currencyProvider.convertBtczToFiat(amount);
      }
      currencyCode = currencyProvider.selectedCurrency.code;
    }

    // Show confirmation dialog first
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => TransactionConfirmationDialog(
        toAddress: address,
        amount: amount,
        fee: _estimatedFee,
        fiatAmount: fiatAmount,
        currencyCode: currencyCode,
        onConfirm: () => _processSendTransaction(amount, address, fiatAmount, currencyCode),
        onCancel: () {
          // User cancelled, do nothing
        },
      ),
    );
  }

  Future<void> _processSendTransaction(double amount, String address, [double? fiatAmount, String? currencyCode]) async {
    setState(() {
      _isSending = true;
      _errorMessage = null;
      _sendingStatus = 'Validating transaction...';
      _sendingProgress = 0.25;
    });

    try {
      final memo = _memoController.text.trim();

      // Let wallet provider handle real progress - no hardcoded values
      await Future.delayed(const Duration(milliseconds: 500));

      final walletProvider = Provider.of<WalletProvider>(context, listen: false);

      // Let wallet provider handle all progress updates
      await Future.delayed(const Duration(milliseconds: 300));

      final result = await walletProvider.sendTransaction(
        toAddress: address,
        amount: amount,
        memo: memo.isNotEmpty ? memo : null,
      );

      if (result != null && mounted) {
        setState(() {
          _sendingStatus = 'Transaction sent!';
          _sendingProgress = 1.0;
        });

        // Short delay to show completion
        await Future.delayed(const Duration(milliseconds: 500));

        // Show custom success dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => TransactionSuccessDialog(
            transactionId: result,
            amount: amount,
            toAddress: address,
            fiatAmount: fiatAmount,
            currencyCode: currencyCode,
            fee: _estimatedFee,
            onClose: _resetForm,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().contains('Insufficient')
              ? 'Insufficient balance to complete this transaction'
              : e.toString().contains('Invalid')
              ? 'Invalid address format. Please check and try again'
              : 'Transaction failed. Please try again later';
          _isSending = false;
          _sendingStatus = '';
          _sendingProgress = 0.0;
        });

        // Show error with animation
        _showErrorAnimation();
      }
    }
  }

  void _showErrorAnimation() {
    // Shake animation for error
    _buttonAnimationController.forward().then((_) {
      _buttonAnimationController.reverse();
    });
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

    if (kDebugMode) {
      print('💰 SET MAX AMOUNT:');
      print('   Spendable Balance: ${walletProvider.balance.spendable} BTCZ');
      print('   Estimated Fee: $_estimatedFee BTCZ');
      print('   Max Amount: $maxAmount BTCZ');
      print('   Is Fiat Input: $_isFiatInput');
    }

    if (maxAmount > 0) {
      if (_isFiatInput) {
        final currencyProvider = Provider.of<CurrencyProvider>(context, listen: false);
        final fiatAmount = currencyProvider.convertBtczToFiat(maxAmount);
        _amountController.text = fiatAmount?.toStringAsFixed(2) ?? '0.00';
        if (kDebugMode) print('   Set Fiat Amount: ${_amountController.text}');
      } else {
        _amountController.text = maxAmount.toStringAsFixed(8);
        if (kDebugMode) print('   Set BTCZ Amount: ${_amountController.text}');
      }
    } else {
      if (kDebugMode) print('   Max amount is 0 or negative, not setting');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer2<WalletProvider, CurrencyProvider>(
        builder: (context, walletProvider, currencyProvider, child) {
          return Stack(
            children: [
              FadeTransition(
                opacity: _fadeAnimation,
                child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // Top spacing
                const SliverToBoxAdapter(
                  child: SizedBox(height: 20),
                ),

                // Balance Card Section - EXACT copy from home page structure
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    child: Container(
                      width: double.infinity,
                      child: Stack(
                        children: [
                          // Glow effect behind the card
                          Positioned.fill(
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 20),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(28),
                                boxShadow: [
                                  BoxShadow(
                                    color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                                    blurRadius: 60,
                                    spreadRadius: 0,
                                    offset: const Offset(0, 20),
                                  ),
                                  BoxShadow(
                                    color: Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                                    blurRadius: 40,
                                    spreadRadius: 0,
                                    offset: const Offset(0, 10),
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
                                width: double.infinity,
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      const Color(0xFF242424).withOpacity(0.9),
                                      const Color(0xFF1A1A1A).withOpacity(0.7),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(28),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.06),
                                    width: 1.5,
                                  ),
                                  boxShadow: [
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
                                    Text(
                                      'Available Balance',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.8),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 4),

                                    _buildAmountText(
                                      walletProvider.balance.formattedSpendable,
                                      fontSize: 32,
                                      height: 1.2,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: -1,
                                      color: Colors.white,
                                    ),

                                    // Show fiat value if available
                                    if (currencyProvider.currentPrice != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        currencyProvider.formatFiatAmount(walletProvider.balance.spendable),
                                        style: TextStyle(
                                          color: Theme.of(context).colorScheme.primary.withOpacity(0.8),
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],

                                    // Removed redundant "Confirming:" display from send screen
                                    // This is already shown on the main dashboard
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Form Section with Input Fields
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                        // Recipient Address - Modern Glass Input
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(left: 4, bottom: 8),
                              child: Text(
                                'SEND TO',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.6),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFF2A2A2A).withOpacity(0.6),
                                    const Color(0xFF1F1F1F).withOpacity(0.4),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.08),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: TextFormField(
                                controller: _addressController,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontFamily: 'monospace',
                                  color: Colors.white,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Enter BitcoinZ address',
                                  hintStyle: TextStyle(
                                    color: Colors.white.withOpacity(0.3),
                                    fontSize: 14,
                                  ),
                                  prefixIcon: Icon(
                                    Icons.account_balance_wallet_outlined,
                                    color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
                                    size: 20,
                                  ),
                                  suffixIcon: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: Icon(
                                          Icons.content_paste,
                                          color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
                                          size: 20,
                                        ),
                                        onPressed: () async {
                                          final data = await Clipboard.getData(Clipboard.kTextPlain);
                                          final text = data?.text?.trim() ?? '';
                                          if (text.isNotEmpty) {
                                            setState(() {
                                              _addressController.text = text;
                                              _errorMessage = null;
                                              _isShieldedTransaction = text.startsWith('zc') || text.startsWith('zs');
                                            });
                                          }
                                        },
                                        tooltip: 'Paste',
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          Icons.qr_code_scanner,
                                          color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
                                          size: 22,
                                        ),
                                        onPressed: _scanQRCode,
                                        tooltip: 'Scan QR',
                                      ),
                                    ],
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
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
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Amount - Modern Glass Input
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(left: 4, bottom: 8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'AMOUNT',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.6),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      // Toggle for BTCZ/Fiat input
                                      if (currencyProvider.currentPrice != null) ...[
                                        Container(
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.05),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Row(
                                            children: [
                                              GestureDetector(
                                                onTap: () => setState(() => _isFiatInput = false),
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: !_isFiatInput
                                                        ? Theme.of(context).colorScheme.primary.withOpacity(0.2)
                                                        : Colors.transparent,
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    'BTCZ',
                                                    style: TextStyle(
                                                      color: !_isFiatInput
                                                          ? Theme.of(context).colorScheme.primary
                                                          : Colors.white.withOpacity(0.5),
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              GestureDetector(
                                                onTap: () => setState(() => _isFiatInput = true),
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: _isFiatInput
                                                        ? Theme.of(context).colorScheme.primary.withOpacity(0.2)
                                                        : Colors.transparent,
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    currencyProvider.selectedCurrency.code,
                                                    style: TextStyle(
                                                      color: _isFiatInput
                                                          ? Theme.of(context).colorScheme.primary
                                                          : Colors.white.withOpacity(0.5),
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                      ],
                                      GestureDetector(
                                        onTap: () => _setMaxAmount(walletProvider),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                                              width: 1,
                                            ),
                                          ),
                                          child: Text(
                                            'MAX',
                                            style: TextStyle(
                                              color: Theme.of(context).colorScheme.primary,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 1,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFF2A2A2A).withOpacity(0.6),
                                    const Color(0xFF1F1F1F).withOpacity(0.4),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.08),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: TextFormField(
                                controller: _amountController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'monospace',
                                  color: Colors.white,
                                ),
                                decoration: InputDecoration(
                                  hintText: _isFiatInput ? '0.00' : '0.00000000',
                                  hintStyle: TextStyle(
                                    color: Colors.white.withOpacity(0.2),
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  suffixText: _isFiatInput
                                      ? currencyProvider.selectedCurrency.code
                                      : 'BTCZ',
                                  suffixStyle: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context).colorScheme.primary.withOpacity(0.8),
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Please enter an amount';
                                  }
                                  final parsed = double.tryParse(value.trim());
                                  if (parsed == null || parsed <= 0) {
                                    return 'Please enter a valid amount';
                                  }

                                  // Convert to BTCZ for validation
                                  double btczAmount = parsed;
                                  if (_isFiatInput) {
                                    btczAmount = currencyProvider.convertFiatToBtcz(parsed) ?? 0;
                                  }

                                  final totalNeeded = btczAmount + _estimatedFee;
                                  if (totalNeeded > walletProvider.balance.spendable) {
                                    if (kDebugMode) {
                                      print('❌ FORM VALIDATION: Insufficient balance');
                                      print('   Input Amount: $parsed ${_isFiatInput ? "fiat" : "BTCZ"}');
                                      print('   BTCZ Amount: $btczAmount BTCZ');
                                      print('   Estimated Fee: $_estimatedFee BTCZ');
                                      print('   Total Needed: $totalNeeded BTCZ');
                                      print('   Spendable Balance: ${walletProvider.balance.spendable} BTCZ');
                                      print('   Shortfall: ${totalNeeded - walletProvider.balance.spendable} BTCZ');
                                    }
                                    return 'Insufficient balance';
                                  }
                                  return null;
                                },
                                onChanged: (value) {
                                  setState(() {
                                    _errorMessage = null;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),

                        // Show conversion amount
                        if (currencyProvider.currentPrice != null) ...[
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Builder(
                              builder: (context) {
                                final text = _amountController.text.trim();
                                if (text.isEmpty) return const SizedBox.shrink();
                                final parsed = double.tryParse(text);
                                if (parsed == null || parsed <= 0) return const SizedBox.shrink();

                                String conversionText = '';
                                if (_isFiatInput) {
                                  final btczAmount = currencyProvider.convertFiatToBtcz(parsed);
                                  if (btczAmount != null) {
                                    conversionText = '≈ ${btczAmount.toStringAsFixed(8)} BTCZ';
                                  }
                                } else {
                                  final fiatAmount = currencyProvider.convertBtczToFiat(parsed);
                                  if (fiatAmount != null) {
                                    conversionText = '≈ ${currencyProvider.formatWithSymbol(fiatAmount)}';
                                  }
                                }

                                if (conversionText.isEmpty) return const SizedBox.shrink();

                                return Text(
                                  conversionText,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
                                    fontWeight: FontWeight.w500,
                                  ),
                                );
                              },
                            ),
                          ),
                        ],

                        // Network Fee - Subtle
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 12,
                                color: Colors.white.withOpacity(0.3),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Network fee: ~${_estimatedFee.toStringAsFixed(4)} BTCZ',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white.withOpacity(0.4),
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

                        // Error Message with animation
                        if (_errorMessage != null) ...[
                          SizedBox(height: ResponsiveUtils.isSmallScreen(context) ? 16 : 24),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            padding: EdgeInsets.all(ResponsiveUtils.getHorizontalPadding(context) * 0.75),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.red.withOpacity(0.15),
                                  Colors.red.withOpacity(0.05),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(ResponsiveUtils.getCardBorderRadius(context) * 0.5),
                              border: Border.all(
                                color: Colors.red.withOpacity(0.4),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.red.withOpacity(0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.warning_amber_rounded,
                                    color: Colors.red.shade400,
                                    size: ResponsiveUtils.getIconSize(context, base: 20),
                                  ),
                                ),
                                SizedBox(width: ResponsiveUtils.isSmallMobile(context) ? 8 : 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Transaction Failed',
                                        style: TextStyle(
                                          color: Colors.red.shade400,
                                          fontSize: ResponsiveUtils.getBodyTextSize(context) * 0.9,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _errorMessage!,
                                        style: TextStyle(
                                          color: Colors.red.shade300,
                                          fontSize: ResponsiveUtils.getBodyTextSize(context) * 0.85,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Send Button - Modern Gradient Style
                        const SizedBox(height: 40),

                        AnimatedBuilder(
                          animation: _buttonScaleAnimation,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _buttonScaleAnimation.value,
                              child: Container(
                                width: double.infinity,
                                height: 60,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8), // Sharp corners
                                  gradient: _canSend(walletProvider) && !_isSending
                                      ? LinearGradient(
                                          colors: [
                                            Theme.of(context).colorScheme.primary,
                                            Theme.of(context).colorScheme.primary.withOpacity(0.8),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        )
                                      : LinearGradient(
                                          colors: [
                                            const Color(0xFF1A1A1A), // Deeper dark color for disabled
                                            const Color(0xFF0F0F0F), // Even deeper
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                  border: Border.all(
                                    color: _canSend(walletProvider) && !_isSending
                                        ? Theme.of(context).colorScheme.primary.withOpacity(0.6)
                                        : Colors.white.withOpacity(0.2),
                                    width: 1.5,
                                  ),
                                  boxShadow: _canSend(walletProvider) && !_isSending ? [
                                    BoxShadow(
                                      color: Theme.of(context).colorScheme.primary.withOpacity(0.4),
                                      blurRadius: 20,
                                      offset: const Offset(0, 8),
                                    ),
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ] : [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(8), // Sharp corners
                                    onTap: (_isSending || !_canSend(walletProvider)) ? null : _sendTransaction,
                                    child: Center(
                                      child: _isSending
                                          ? Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Stack(
                                                  alignment: Alignment.center,
                                                  children: [
                                                    SizedBox(
                                                      width: 24,
                                                      height: 24,
                                                      child: CircularProgressIndicator(
                                                        strokeWidth: 2.5,
                                                        value: _sendingProgress,
                                                        backgroundColor: Colors.white.withOpacity(0.2),
                                                        valueColor: const AlwaysStoppedAnimation<Color>(
                                                          Colors.white,
                                                        ),
                                                      ),
                                                    ),
                                                    if (_sendingProgress == 1.0)
                                                      const Icon(
                                                        Icons.check,
                                                        color: Colors.white,
                                                        size: 16,
                                                      ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  _sendingStatus,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w500,
                                                    color: Colors.white.withOpacity(0.9),
                                                  ),
                                                ),
                                              ],
                                            )
                                          : Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                const Icon(
                                                  Icons.send_rounded,
                                                  color: Colors.white,
                                                  size: 22,
                                                ),
                                                const SizedBox(width: 10),
                                                Text(
                                                  'Send Transaction',
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w700, // Sharper font weight
                                                    letterSpacing: 1.0, // More spacing
                                                    color: _canSend(walletProvider)
                                                        ? Colors.white
                                                        : Colors.white.withOpacity(0.3),
                                                  ),
                                                ),
                                              ],
                                            ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ),
                ),

                // Bottom spacing
                const SliverToBoxAdapter(
                  child: SizedBox(height: 20),
                ),
              ],
            ),
          ),
          // Progress Overlay - Use wallet provider's real progress exclusively
          SendingProgressOverlay(
            status: walletProvider.isSendingTransaction
                ? walletProvider.sendingStatus.isNotEmpty
                    ? walletProvider.sendingStatus
                    : 'Preparing transaction...'
                : _sendingStatus,
            progress: walletProvider.isSendingTransaction
                ? walletProvider.sendingProgress
                : _sendingProgress,
            eta: walletProvider.isSendingTransaction
                ? walletProvider.sendingETA
                : '',
            isVisible: _isSending || walletProvider.isSendingTransaction,
          ),
        ],
      );
    },
  ),
);
}

  /// Builds a RichText where the decimal part is smaller to save space
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

    String integerPart = amount;
    String fractionalPart = '';
    final dotIndex = amount.indexOf('.');
    if (dotIndex != -1) {
      integerPart = amount.substring(0, dotIndex);
      fractionalPart = amount.substring(dotIndex);
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
                fontSize: fontSize * 0.6,
                fontWeight: fontWeight,
                letterSpacing: letterSpacing,
              ),
            ),
        ],
      ),
    );
  }
}
}