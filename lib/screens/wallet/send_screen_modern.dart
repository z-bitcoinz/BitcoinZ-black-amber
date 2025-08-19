import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../providers/wallet_provider.dart';
import '../../providers/currency_provider.dart';
import '../../widgets/transaction_success_dialog.dart';
import '../../widgets/transaction_confirmation_dialog.dart';
import '../../widgets/sending_progress_overlay.dart';

class SendScreenModern extends StatefulWidget {
  const SendScreenModern({super.key});

  @override
  State<SendScreenModern> createState() => _SendScreenModernState();
}

class _SendScreenModernState extends State<SendScreenModern> {
  final _formKey = GlobalKey<FormState>();
  final _addressController = TextEditingController();
  final _amountController = TextEditingController();
  final _memoController = TextEditingController();
  
  bool _isSending = false;
  String? _errorMessage;
  bool _isShieldedTransaction = false;
  final double _estimatedFee = 0.00001; // Standard BitcoinZ fee (much lower)
  bool _isFiatInput = false;
  
  @override
  void dispose() {
    _addressController.dispose();
    _amountController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  bool _isValidBitcoinZAddress(String address) {
    if (address.isEmpty) return false;
    
    // Transparent addresses
    if (address.startsWith('t1') && address.length >= 34) {
      setState(() => _isShieldedTransaction = false);
      return true;
    }
    
    // Shielded addresses
    if ((address.startsWith('zc') || address.startsWith('zs')) && address.length >= 60) {
      setState(() => _isShieldedTransaction = true);
      return true;
    }
    
    return false;
  }

  double? _getAmountValue() {
    final text = _amountController.text.trim();
    if (text.isEmpty) return null;
    final parsed = double.tryParse(text);
    if (parsed == null) return null;
    
    if (_isFiatInput) {
      final currencyProvider = Provider.of<CurrencyProvider>(context, listen: false);
      return currencyProvider.convertFiatToBtcz(parsed);
    }
    return parsed;
  }

  bool _canSend(WalletProvider walletProvider) {
    final amount = _getAmountValue();
    if (amount == null || amount <= 0) return false;
    
    final totalNeeded = amount + _estimatedFee;
    return walletProvider.balance.spendable >= totalNeeded;
  }

  Future<void> _scanQRCode() async {
    // Placeholder for QR scanner
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('QR scanner would open here'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _sendTransaction() async {
    if (!_formKey.currentState!.validate() || _isSending) return;
    
    final amount = _getAmountValue()!;
    final address = _addressController.text.trim();
    
    final currencyProvider = Provider.of<CurrencyProvider>(context, listen: false);
    double? fiatAmount;
    String? currencyCode;
    
    if (currencyProvider.currentPrice != null) {
      if (_isFiatInput) {
        fiatAmount = double.tryParse(_amountController.text.trim());
      } else {
        fiatAmount = currencyProvider.convertBtczToFiat(amount);
      }
      currencyCode = currencyProvider.selectedCurrency.code;
    }
    
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
        onCancel: () {},
      ),
    );
  }
  
  Future<void> _processSendTransaction(double amount, String address, [double? fiatAmount, String? currencyCode]) async {
    setState(() {
      _isSending = true;
      _errorMessage = null;
    });

    try {
      final walletProvider = Provider.of<WalletProvider>(context, listen: false);
      final memo = _isShieldedTransaction ? _memoController.text : null;
      
      final txid = await walletProvider.sendTransaction(
        toAddress: address,
        amount: amount,
        memo: memo,
      );
      
      if (txid != null && mounted) {
        // Show success dialog
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext dialogContext) => TransactionSuccessDialog(
            transactionId: txid,
            amount: amount,
            toAddress: address,
            fiatAmount: fiatAmount,
            currencyCode: currencyCode,
            onClose: () {
              // Pop the dialog safely
              if (mounted && Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
            },
          ),
        );
        
        // Clear fields after successful send
        if (mounted) {
          _addressController.clear();
          _amountController.clear();
          _memoController.clear();
        }
      } else {
        setState(() {
          _errorMessage = 'Transaction failed. Please try again.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final walletProvider = Provider.of<WalletProvider>(context);
    final currencyProvider = Provider.of<CurrencyProvider>(context);
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 700;
    
    return Stack(
      children: [
        Scaffold(
          backgroundColor: const Color(0xFF1A1A1A),
          appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Send',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Compact Balance Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF2A2A2A),
                        const Color(0xFF1F1F1F),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.05),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Available Balance',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        walletProvider.balance.formattedSpendable,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (currencyProvider.currentPrice != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          currencyProvider.formatFiatAmount(walletProvider.balance.spendable),
                          style: TextStyle(
                            color: const Color(0xFFFF6B00).withOpacity(0.8),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Recipient Address Field
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'RECIPIENT',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A2A2A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                        ),
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
                            Icons.account_balance_wallet,
                            color: Colors.white.withOpacity(0.5),
                            size: 18,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              Icons.qr_code_scanner,
                              color: const Color(0xFFFF6B00),
                              size: 20,
                            ),
                            onPressed: _scanQRCode,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a recipient address';
                          }
                          if (!_isValidBitcoinZAddress(value)) {
                            return 'Invalid BitcoinZ address';
                          }
                          return null;
                        },
                        onChanged: (value) {
                          _isValidBitcoinZAddress(value);
                        },
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 20),
                
                // Amount Field
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'AMOUNT',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _isFiatInput = !_isFiatInput;
                              _amountController.clear();
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF6B00).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFFFF6B00).withOpacity(0.4),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.swap_horiz,
                                  size: 14,
                                  color: const Color(0xFFFF6B00),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _isFiatInput 
                                      ? '${currencyProvider.selectedCurrency.code} → BTCZ' 
                                      : 'BTCZ → ${currencyProvider.selectedCurrency.code}',
                                  style: const TextStyle(
                                    color: Color(0xFFFF6B00),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A2A2A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                      child: TextFormField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                        onChanged: (value) {
                          setState(() {}); // Rebuild to update conversion display
                        },
                        decoration: InputDecoration(
                          hintText: '0.00',
                          hintStyle: TextStyle(
                            color: Colors.white.withOpacity(0.3),
                            fontSize: 18,
                          ),
                          prefixIcon: Padding(
                            padding: const EdgeInsets.only(left: 16, right: 8),
                            child: _isFiatInput 
                                ? Icon(
                                    Icons.attach_money,
                                    color: Colors.white.withOpacity(0.5),
                                    size: 20,
                                  )
                                : SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Icon(
                                          Icons.currency_bitcoin,
                                          color: Colors.white.withOpacity(0.5),
                                          size: 20,
                                        ),
                                        Positioned(
                                          bottom: 3,
                                          child: Text(
                                            'Z',
                                            style: TextStyle(
                                              color: Colors.white.withOpacity(0.7),
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                          ),
                          suffixText: _isFiatInput 
                              ? currencyProvider.selectedCurrency.code
                              : 'BTCZ',
                          suffixStyle: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter an amount';
                          }
                          final amount = _getAmountValue();
                          if (amount == null || amount <= 0) {
                            return 'Invalid amount';
                          }
                          if (!_canSend(walletProvider)) {
                            final totalNeeded = amount + _estimatedFee;
                            return 'Need ${totalNeeded.toStringAsFixed(8)} BTCZ (includes fee)';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Fiat conversion display
                        if (_amountController.text.isNotEmpty) ...[
                          Builder(
                            builder: (context) {
                              final inputAmount = double.tryParse(_amountController.text) ?? 0;
                              if (inputAmount <= 0) {
                                return const SizedBox();
                              }
                              
                              String conversionText = '';
                              
                              // Use hardcoded price as fallback if API fails
                              const double fallbackPrice = 0.00005; // Example: 1 BTCZ = $0.00005
                              
                              if (_isFiatInput) {
                                // Converting from fiat to BTCZ
                                double? btczAmount = currencyProvider.convertFiatToBtcz(inputAmount);
                                if (btczAmount == null && fallbackPrice > 0) {
                                  // Use fallback price if API data unavailable
                                  btczAmount = inputAmount / fallbackPrice;
                                }
                                if (btczAmount != null) {
                                  conversionText = '≈ ${btczAmount.toStringAsFixed(8)} BTCZ';
                                }
                              } else {
                                // Converting from BTCZ to fiat
                                double? fiatAmount = currencyProvider.convertBtczToFiat(inputAmount);
                                if (fiatAmount == null) {
                                  // Use fallback price if API data unavailable
                                  fiatAmount = inputAmount * fallbackPrice;
                                }
                                if (fiatAmount != null) {
                                  conversionText = '≈ \$${fiatAmount.toStringAsFixed(2)}';
                                }
                              }
                              
                              if (conversionText.isEmpty) {
                                // Fallback if prices aren't loaded
                                conversionText = 'Conversion unavailable';
                              }
                              
                              return Text(
                                conversionText,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: conversionText.contains('unavailable') 
                                      ? Colors.white.withOpacity(0.4)
                                      : const Color(0xFFFF6B00),
                                  fontWeight: FontWeight.w600,
                                ),
                              );
                            },
                          ),
                        ] else const SizedBox(),
                        Text(
                          'Fee: ~${_estimatedFee.toStringAsFixed(8)} BTCZ',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withOpacity(0.4),
                          ),
                        ),
                      ],
                    ),
                    // Show warning if balance insufficient for amount + fee
                    if (_amountController.text.isNotEmpty) ...[
                      Builder(
                        builder: (context) {
                          final amount = _getAmountValue();
                          if (amount != null && amount > 0) {
                            final totalNeeded = amount + _estimatedFee;
                            final balance = walletProvider.balance.spendable;
                            if (balance < totalNeeded) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: Colors.orange.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.warning_amber_rounded,
                                        size: 14,
                                        color: Colors.orange,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          'Need ${totalNeeded.toStringAsFixed(8)} BTCZ total (${amount.toStringAsFixed(8)} + ${_estimatedFee.toStringAsFixed(8)} fee)',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.orange,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }
                          }
                          return const SizedBox();
                        },
                      ),
                    ],
                  ],
                ),
                
                // Memo Field (for shielded transactions)
                if (_isShieldedTransaction) ...[
                  const SizedBox(height: 20),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MEMO (OPTIONAL)',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A2A2A),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.1),
                          ),
                        ),
                        child: TextFormField(
                          controller: _memoController,
                          maxLines: 2,
                          maxLength: 512,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Add a private message',
                            hintStyle: TextStyle(
                              color: Colors.white.withOpacity(0.3),
                              fontSize: 14,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.all(12),
                            counterStyle: TextStyle(
                              color: Colors.white.withOpacity(0.4),
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                
                // Error Message
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.red.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                
                const SizedBox(height: 32),
                
                // Send Button
                Container(
                  height: 54,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _canSend(walletProvider) && !_isSending
                          ? [const Color(0xFFFF6B00), const Color(0xFFFFAA00)]
                          : [Colors.grey.shade700, Colors.grey.shade600],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(27),
                    boxShadow: _canSend(walletProvider) && !_isSending
                        ? [
                            BoxShadow(
                              color: const Color(0xFFFF6B00).withOpacity(0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ]
                        : [],
                  ),
                  child: ElevatedButton(
                    onPressed: _canSend(walletProvider) && !_isSending
                        ? _sendTransaction
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(27),
                      ),
                    ),
                    child: _isSending
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Send Transaction',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    ),
    // Sending Progress Overlay
    SendingProgressOverlay(
      status: _isSending ? 'Broadcasting transaction...' : '',
      progress: _isSending ? 0.5 : 0,
      isVisible: _isSending,
    ),
  ],
);
  }
}