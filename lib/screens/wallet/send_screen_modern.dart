import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../providers/wallet_provider.dart';
import '../../providers/currency_provider.dart';
import '../../providers/contact_provider.dart';
import '../../models/contact_model.dart';
import '../../widgets/transaction_confirmation_dialog.dart';
import '../../widgets/sending_progress_overlay.dart';
import '../../widgets/animated_progress_dots.dart';
import 'qr_scanner_screen.dart';
import '../../services/send_prefill_bus.dart';
import '../../services/image_helper_service.dart';

import '../../utils/formatters.dart';
import '../../providers/interface_provider.dart';
import '../../screens/main_screen.dart';

class SendScreenModern extends StatefulWidget {
  final String? prefilledAddress;
  final String? contactName;
  final String? contactPhoto;

  const SendScreenModern({
    super.key,
    this.prefilledAddress,
    this.contactName,
    this.contactPhoto,
  });

  @override
  State<SendScreenModern> createState() => _SendScreenModernState();
}

class _SendScreenModernState extends State<SendScreenModern> {
  final _formKey = GlobalKey<FormState>();
  final _addressController = TextEditingController();
  final _amountController = TextEditingController();
  final _memoController = TextEditingController();

  // Selected contact info (if coming from contacts or prefill bus)
  String? _selectedContactName;
  String? _selectedContactPhoto;

  String? _errorMessage;
  bool _isShieldedTransaction = false;
  final double _estimatedFee = 0.00001; // Standard BitcoinZ fee (much lower)
  bool _isFiatInput = false;

  // Track if user manually cleared the form
  bool _wasManuallyCleared = false;

  @override
  void initState() {
    super.initState();
    print('🎯 SendScreenModern.initState() called');
    print('🎯 SendScreenModern.initState: prefilledAddress = ${widget.prefilledAddress}');
    print('🎯 SendScreenModern.initState: contactName = ${widget.contactName}');

    // Listen for prefill events so we can update even when the widget is reused by PageView
    SendPrefillBus.current.addListener(_onPrefillChanged);

    // Save incoming contact info (if any) for use across the flow
    _selectedContactName = widget.contactName;
    _selectedContactPhoto = widget.contactPhoto;

    _handlePrefilledData();
  }

  @override
  void didUpdateWidget(SendScreenModern oldWidget) {
    super.didUpdateWidget(oldWidget);

    print('🎯 SendScreenModern.didUpdateWidget() called');
    print('🎯 SendScreenModern.didUpdateWidget: old prefilledAddress = ${oldWidget.prefilledAddress}');
    print('🎯 SendScreenModern.didUpdateWidget: new prefilledAddress = ${widget.prefilledAddress}');
    print('🎯 SendScreenModern.didUpdateWidget: old contactName = ${oldWidget.contactName}');
    print('🎯 SendScreenModern.didUpdateWidget: new contactName = ${widget.contactName}');

    // Handle updates to prefilled data
    if (oldWidget.prefilledAddress != widget.prefilledAddress ||
        oldWidget.contactName != widget.contactName) {
      print('🎯 SendScreenModern.didUpdateWidget: Prefilled data changed, calling _handlePrefilledData()');
      _handlePrefilledData();
    } else {
      print('🎯 SendScreenModern.didUpdateWidget: No change in prefilled data');
    }
  }

  void _onPrefillChanged() {
    final prefill = SendPrefillBus.current.value;
    print('🎯 SendScreenModern._onPrefillChanged: $prefill');
    if (prefill != null) {
      // Reset manual clear flag when new prefill arrives
      _wasManuallyCleared = false;

      if (prefill.address.isNotEmpty) {
        print('🎯 SendScreenModern: Applying bus prefill address: ${prefill.address}');
        _addressController.text = prefill.address;
        _isValidBitcoinZAddress(prefill.address);
      }
      if (prefill.name != null && prefill.name!.isNotEmpty) {
        _selectedContactName = prefill.name;
        _selectedContactPhoto = prefill.photo;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Sending to ${prefill.name!}'),
                backgroundColor: Colors.blue,
                duration: const Duration(seconds: 2),
              ),
            );
            setState(() {}); // refresh UI banner/title
          }
        });
      }
    }
  }
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Don't apply prefill if user manually cleared the form
    if (_wasManuallyCleared) {
      print('🎯 SendScreenModern.didChangeDependencies: Skipping prefill - user manually cleared');
      return;
    }

    // If there is a prefill waiting on the bus when we become active, apply it.
    final prefill = SendPrefillBus.current.value;
    if (prefill != null) {
      if (prefill.address.isNotEmpty && _addressController.text.isEmpty) {
        print('🎯 SendScreenModern.didChangeDependencies: applying pending prefill address');
        _addressController.text = prefill.address;
        _isValidBitcoinZAddress(prefill.address);
      }
      if (prefill.name != null && prefill.name!.isNotEmpty && _selectedContactName == null) {
        print('🎯 SendScreenModern.didChangeDependencies: applying pending prefill name: ${prefill.name}');
        _selectedContactName = prefill.name;
        _selectedContactPhoto = prefill.photo;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() {}); // refresh UI banner/title
        });
      }
    }
  }


  void _handlePrefilledData() {
    print('🎯 SendScreenModern._handlePrefilledData() called');
    print('🎯 SendScreenModern: prefilledAddress = ${widget.prefilledAddress}');
    print('🎯 SendScreenModern: contactName = ${widget.contactName}');

    // Initialize with prefilled address if provided
    if (widget.prefilledAddress != null) {
      print('🎯 SendScreenModern: Setting address controller text to: ${widget.prefilledAddress!}');
      _addressController.text = widget.prefilledAddress!;
      print('🎯 SendScreenModern: Address controller text is now: ${_addressController.text}');

      // Validate the address to set transaction type
      _isValidBitcoinZAddress(widget.prefilledAddress!);
    } else {
      print('🎯 SendScreenModern: No prefilled address provided');
    }

    // Apply contact name and photo (independent of whether address came via widget or bus)
    if (widget.contactName != null && widget.contactName!.isNotEmpty) {
      _selectedContactName = widget.contactName;
      _selectedContactPhoto = widget.contactPhoto;
      print('🎯 SendScreenModern: Applying contact name for UI: ${widget.contactName!}');
      print('🎯 SendScreenModern: Contact photo: ${widget.contactPhoto != null ? 'provided' : 'null'}');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Sending to ${widget.contactName!}'),
              backgroundColor: Colors.blue,
              duration: const Duration(seconds: 2),
            ),
          );
          setState(() {}); // refresh UI banner/title
        }
      });
    }
  }

  @override
  void dispose() {
    SendPrefillBus.current.removeListener(_onPrefillChanged);
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

  void _clearRecipient() {
    setState(() {
      _addressController.clear();
      _selectedContactName = null;
      _selectedContactPhoto = null;
      _isShieldedTransaction = false;
      _wasManuallyCleared = true; // Mark as manually cleared
    });

    // Clear any error message
    _errorMessage = null;

    // Clear the prefill bus to prevent auto-refill
    SendPrefillBus.clear();

    HapticFeedback.lightImpact();
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
    try {
      final result = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (context) => const QRScannerScreen(),
          fullscreenDialog: true,
        ),
      );

      if (result != null && result.isNotEmpty && result != 'manual_entry') {
        _processQRCodeData(result);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Scanner error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _processQRCodeData(String qrData) {
    try {
      final parsedData = _parseQRCode(qrData);

      if (parsedData['address'] != null) {
        _addressController.text = parsedData['address']!;

        // Validate the address to set transaction type
        _isValidBitcoinZAddress(parsedData['address']!);
      }

      if (parsedData['amount'] != null && parsedData['amount']!.isNotEmpty) {
        _amountController.text = parsedData['amount']!;
      }

      if (parsedData['memo'] != null && parsedData['memo']!.isNotEmpty && _isShieldedTransaction) {
        _memoController.text = parsedData['memo']!;
      }

      // Show success feedback
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('QR code scanned successfully'),
          backgroundColor: const Color(0xFF4CAF50),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );

      // Rebuild to update UI
      setState(() {});

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invalid QR code format'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  Map<String, String?> _parseQRCode(String qrData) {
    final result = <String, String?>{
      'address': null,
      'amount': null,
      'memo': null,
    };

    // Clean the QR data
    final cleanData = qrData.trim();

    // Check if it's a BitcoinZ URI (bitcoinz:address?params)
    if (cleanData.toLowerCase().startsWith('bitcoinz:')) {
      final uri = Uri.tryParse(cleanData);
      if (uri != null) {
        // Extract address (everything after bitcoinz: and before ?)
        String address = uri.path;
        if (address.isEmpty && uri.host.isNotEmpty) {
          address = uri.host; // Handle bitcoinz://address format
        }

        result['address'] = address;
        result['amount'] = uri.queryParameters['amount'];
        result['memo'] = uri.queryParameters['memo'] ?? uri.queryParameters['message'];

        return result;
      }
    }

    // Check if it's a generic crypto URI (bitcoin:, zcash:, etc.)
    if (cleanData.contains(':')) {
      final uri = Uri.tryParse(cleanData);
      if (uri != null && uri.scheme.isNotEmpty) {
        String address = uri.path;
        if (address.isEmpty && uri.host.isNotEmpty) {
          address = uri.host;
        }

        result['address'] = address;
        result['amount'] = uri.queryParameters['amount'];
        result['memo'] = uri.queryParameters['memo'] ?? uri.queryParameters['message'];

        return result;
      }
    }

    // Assume it's a plain address
    if (_isValidAddressFormat(cleanData)) {
      result['address'] = cleanData;
      return result;
    }

    throw Exception('Unsupported QR code format');
  }

  bool _isValidAddressFormat(String address) {
    // BitcoinZ transparent addresses start with 't1' and are ~34 chars
    if (address.startsWith('t1') && address.length >= 32 && address.length <= 40) {
      return true;
    }

    // BitcoinZ shielded addresses start with 'zs' and are longer
    if (address.startsWith('zs') && address.length >= 60 && address.length <= 80) {
      return true;
    }

    // Legacy shielded addresses start with 'zc'
    if (address.startsWith('zc') && address.length >= 60 && address.length <= 80) {
      return true;
    }

    return false;
  }

  Future<void> _showContactPicker() async {
    final contactProvider = Provider.of<ContactProvider>(context, listen: false);

    // Ensure contacts are loaded
    if (contactProvider.contacts.isEmpty) {
      await contactProvider.loadContacts();
    }

    if (!mounted) return;

    if (contactProvider.contacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No contacts found. Add contacts first.'),
          backgroundColor: Colors.orange,
          action: SnackBarAction(
            label: 'Add Contact',
            onPressed: () {
              // Navigate to contacts tab - would require parent MainScreen access
            },
          ),
        ),
      );
      return;
    }

    final selectedContact = await showDialog<ContactModel>(
      context: context,
      builder: (context) => _ContactPickerDialog(contacts: contactProvider.contacts),
    );

    if (selectedContact != null && mounted) {
      _addressController.text = selectedContact.address;
      _isValidBitcoinZAddress(selectedContact.address);
      _selectedContactName = selectedContact.name; // wire name for banner, dialogs, title
      _selectedContactPhoto = selectedContact.pictureBase64; // wire photo for display
      _wasManuallyCleared = false; // Reset manual clear flag when selecting new contact

      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Selected ${selectedContact.name}'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );

      setState(() {});
    }
  }

  Future<void> _sendTransaction() async {
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    if (!_formKey.currentState!.validate() || walletProvider.isSendingTransaction) return;

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
        contactName: _selectedContactName,
        onConfirm: () => _processSendTransaction(amount, address, fiatAmount, currencyCode),
        onCancel: () {},
      ),
    );
  }

  Future<void> _processSendTransaction(double amount, String address, [double? fiatAmount, String? currencyCode]) async {
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);

    // Determine if auto-shielding might occur
    final hasTransparentFunds = walletProvider.balance.transparent > 0.001;
    final needsAutoShielding = hasTransparentFunds && _isShieldedTransaction;

    setState(() {
      _errorMessage = null;
    });

    try {
      final memo = _isShieldedTransaction ? _memoController.text : null;

      // The wallet provider will handle progress updates automatically

      final txid = await walletProvider.sendTransaction(
        toAddress: address,
        amount: amount,
        memo: memo,
      );

      if (txid != null && mounted) {
        // Success! The SendingProgressOverlay will show the success state automatically
        // Form fields will be cleared when the overlay closes
      } else {
        setState(() {
          _errorMessage = 'Transaction failed. Please try again.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
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
        title: Text(
          _selectedContactName != null && _selectedContactName!.isNotEmpty
              ? 'Send to ${_selectedContactName!}'
              : 'Send',
          style: const TextStyle(
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
                // Contact Info Card (if sending to contact)
                if (_selectedContactName != null && _selectedContactName!.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.primary.withOpacity(0.2),
                          Theme.of(context).colorScheme.primary.withOpacity(0.1),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                          backgroundImage: _selectedContactPhoto != null
                              ? ImageHelperService.getMemoryImage(_selectedContactPhoto)
                              : null,
                          child: _selectedContactPhoto == null
                              ? Icon(
                                  Icons.person,
                                  color: Theme.of(context).colorScheme.primary,
                                  size: 24,
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Sending to Contact',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _selectedContactName!,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.close,
                            color: Colors.white.withOpacity(0.7),
                            size: 20,
                          ),
                          onPressed: _clearRecipient,
                          tooltip: 'Clear selection',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Complete Balance Card with Clear Breakdown
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
                      // Main Balance Section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Available to Send',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.6),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                buildAmountTextSmall(
                                  walletProvider.balance.formattedSpendable,
                                  fontSize: 36,
                                  height: 1.2,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                if (currencyProvider.currentPrice != null)
                                  Text(
                                    currencyProvider.formatFiatAmount(walletProvider.balance.spendable),
                                    style: TextStyle(
                                      color: const Color(0xFFFF6B00).withOpacity(0.8),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          // Total Balance Summary
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.1),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'Total Balance',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.5),
                                    fontSize: 10,
                                  ),
                                ),
                                buildAmountTextSmall(
                                  walletProvider.balance.formattedTotal,
                                  fontSize: 18,
                                  height: 1.1,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      // Balance Breakdown - Show when there are any confirming funds (incoming OR change)
                      if (walletProvider.balance.unconfirmed > 0 || walletProvider.balance.unverified > 0) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1A1A),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.1),
                            ),
                          ),
                          child: Column(
                            children: [
                              // Header with loading animation
                              Row(
                                children: [
                                  Icon(
                                    Icons.account_balance_wallet,
                                    size: 16,
                                    color: Colors.white.withOpacity(0.6),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Balance Breakdown',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.6),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  // Show animated dots when balance has unconfirmed activity
                                  if (walletProvider.balance.unconfirmed > 0 || walletProvider.balance.unverified > 0 || walletProvider.isLoading || walletProvider.isSyncing) ...[
                                    const SizedBox(width: 8),
                                    const AnimatedProgressDots(),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 8),

                              // Spendable
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF4CAF50),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Spendable',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.8),
                                          fontSize: 15,
                                        ),
                                      ),
                                    ],
                                  ),
                                  buildAmountTextSmall(
                                    walletProvider.balance.formattedSpendable,
                                    fontSize: 15,
                                    height: 1.1,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF4CAF50),
                                  ),
                                ],
                              ),

                              // Pure Incoming funds (not change) - show only if > 0.001
                              if (walletProvider.balance.pureIncoming >= 0.001) ...[
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: Colors.blue,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Incoming (Confirming)',
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.8),
                                            fontSize: 15,
                                          ),
                                        ),
                                      ],
                                    ),
                                    buildAmountTextSmall(
                                      walletProvider.balance.formattedPureIncoming,
                                      fontSize: 15,
                                      height: 1.1,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.blue,
                                    ),
                                  ],
                                ),
                              ],

                              // Change Returning (unverified balance) - show only if meaningful amount
                              if (walletProvider.balance.unverified >= 0.001) ...[
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: Colors.green.withOpacity(0.7),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Change Returning',
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.8),
                                            fontSize: 15,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      walletProvider.balance.formattedUnverified,
                                      style: TextStyle(
                                        color: Colors.green.withOpacity(0.7),
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],

                              // Divider and Total
                              const SizedBox(height: 8),
                              Container(
                                height: 1,
                                color: Colors.white.withOpacity(0.1),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Total',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.9),
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    walletProvider.balance.formattedTotal,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.9),
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],

                    ],
                  ),
                ),

                const SizedBox(height: 16),

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
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_addressController.text.isNotEmpty)
                                IconButton(
                                  icon: Icon(
                                    Icons.clear,
                                    color: Colors.white.withOpacity(0.5),
                                    size: 18,
                                  ),
                                  onPressed: _clearRecipient,
                                  tooltip: 'Clear',
                                ),
                              IconButton(
                                icon: Icon(
                                  Icons.content_paste,
                                  color: const Color(0xFFFF6B00),
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
                                  Icons.contacts,
                                  color: const Color(0xFFFF6B00),
                                  size: 20,
                                ),
                                onPressed: _showContactPicker,
                                tooltip: 'Select from contacts',
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.qr_code_scanner,
                                  color: const Color(0xFFFF6B00),
                                  size: 20,
                                ),
                                onPressed: _scanQRCode,
                                tooltip: 'Scan QR code',
                              ),
                            ],
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
                          setState(() {
                            _isValidBitcoinZAddress(value);
                          });
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
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: _isFiatInput
                                ? Icon(
                                    Icons.attach_money,
                                    color: Colors.white.withOpacity(0.5),
                                    size: 24,
                                  )
                                : Container(
                                    width: 28,
                                    height: 28,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: Image.asset(
                                        'assets/images/bitcoinz_logo.png',
                                        width: 28,
                                        height: 28,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          // Fallback to bitcoin icon if image fails to load
                                          return Container(
                                            width: 28,
                                            height: 28,
                                            decoration: BoxDecoration(
                                              gradient: const LinearGradient(
                                                colors: [
                                                  Color(0xFFFF6B00),
                                                  Color(0xFFFFAA00),
                                                ],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              ),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Center(
                                              child: Icon(
                                                Icons.currency_bitcoin,
                                                color: Colors.white.withOpacity(0.9),
                                                size: 18,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
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
                            if (walletProvider.balance.total >= totalNeeded && walletProvider.balance.spendable < totalNeeded) {
                              return 'Funds need confirmations before spending';
                            }
                            return 'Need ${Formatters.formatBtczTrim(totalNeeded, showSymbol: false)} BTCZ (includes fee)';
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
                                  conversionText = '≈ ${Formatters.formatBtczTrim(btczAmount, showSymbol: false)} BTCZ';
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
                          'Fee: ~${Formatters.formatBtczTrim(_estimatedFee, showSymbol: false)} BTCZ',
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
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Need ${Formatters.formatBtczTrim(totalNeeded, showSymbol: false)} BTCZ total (${Formatters.formatBtczTrim(amount, showSymbol: false)} + ${Formatters.formatBtczTrim(_estimatedFee, showSymbol: false)} fee)',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.orange,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            if (walletProvider.balance.total > walletProvider.balance.spendable)
                                              Padding(
                                                padding: const EdgeInsets.only(top: 2),
                                                child: Text(
                                                  '${Formatters.formatBtczTrim((walletProvider.balance.total - walletProvider.balance.spendable), showSymbol: false)} BTCZ awaiting confirmations (typically 2-6 minutes)',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: Colors.orange.withOpacity(0.8),
                                                  ),
                                                ),
                                              ),
                                          ],
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
                      colors: _canSend(walletProvider) && !walletProvider.isSendingTransaction
                          ? [const Color(0xFFFF6B00), const Color(0xFFFFAA00)]
                          : [const Color(0xFF1A1A1A), const Color(0xFF0F0F0F)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(8), // Sharp corners
                    border: Border.all(
                      color: _canSend(walletProvider) && !walletProvider.isSendingTransaction
                          ? const Color(0xFFFF6B00).withOpacity(0.6)
                          : Colors.white.withOpacity(0.2),
                      width: 1.5,
                    ),
                    boxShadow: _canSend(walletProvider) && !walletProvider.isSendingTransaction
                        ? [
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
                          ]
                        : [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                  ),
                  child: ElevatedButton(
                    onPressed: _canSend(walletProvider) && !walletProvider.isSendingTransaction
                        ? _sendTransaction
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8), // Sharp corners
                      ),
                    ),
                    child: walletProvider.isSendingTransaction
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
                              fontWeight: FontWeight.w700, // Sharper font weight
                              letterSpacing: 1.0, // More spacing
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
      status: walletProvider.sendingStatus,
      progress: walletProvider.isSendingTransaction ? walletProvider.sendingProgress : 0,
      eta: walletProvider.isSendingTransaction ? walletProvider.sendingETA : '',
      isVisible: walletProvider.isSendingTransaction || walletProvider.sendingStatus == 'success',
      completedTxid: walletProvider.completedTransactionId,
      sentAmount: (_amountController.text.isNotEmpty || walletProvider.completedTransactionId != null)
          ? _getAmountValue()
          : null,
      onClose: () {
        walletProvider.closeSendingSuccess();
        // Clear form fields after overlay closes
        if (mounted) {
          _addressController.clear();
          _amountController.clear();
          _memoController.clear();
        }
      },
    ),
  ],
);
  }
}

class _ContactPickerDialog extends StatefulWidget {
  final List<ContactModel> contacts;

  const _ContactPickerDialog({
    required this.contacts,
  });

  @override
  State<_ContactPickerDialog> createState() => _ContactPickerDialogState();
}

class _ContactPickerDialogState extends State<_ContactPickerDialog> {
  final _searchController = TextEditingController();
  List<ContactModel> _filteredContacts = [];

  @override
  void initState() {
    super.initState();
    _filteredContacts = widget.contacts;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterContacts(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredContacts = widget.contacts;
      } else {
        final lowerQuery = query.toLowerCase();
        _filteredContacts = widget.contacts.where((contact) {
          return contact.name.toLowerCase().contains(lowerQuery) ||
                 contact.address.toLowerCase().contains(lowerQuery) ||
                 (contact.description?.toLowerCase().contains(lowerQuery) ?? false);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 600, maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.contacts,
                    color: Color(0xFFFF6B00),
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Select Contact',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),

            // Search field
            Container(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                onChanged: _filterContacts,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search contacts...',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                  prefixIcon: Icon(
                    Icons.search,
                    color: Colors.white.withOpacity(0.5),
                  ),
                  filled: true,
                  fillColor: const Color(0xFF2A2A2A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),

            // Contact list
            Expanded(
              child: _filteredContacts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 48,
                            color: Colors.white.withOpacity(0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No contacts found',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filteredContacts.length,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemBuilder: (context, index) {
                        final contact = _filteredContacts[index];
                        return ListTile(
                          onTap: () => Navigator.pop(context, contact),
                          leading: CircleAvatar(
                            radius: 20,
                            backgroundColor: const Color(0xFFFF6B00).withOpacity(0.2),
                            child: Text(
                              contact.name.isNotEmpty
                                  ? contact.name[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                color: Color(0xFFFF6B00),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  contact.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              if (contact.isFavorite)
                                const Icon(
                                  Icons.star,
                                  color: Colors.amber,
                                  size: 16,
                                ),
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: contact.isTransparent
                                      ? Colors.blue.withOpacity(0.2)
                                      : Colors.purple.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  contact.isTransparent ? 'T' : 'S',
                                  style: TextStyle(
                                    color: contact.isTransparent
                                        ? Colors.blue
                                        : Colors.purple,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                contact.address.length > 24
                                    ? '${contact.address.substring(0, 12)}...${contact.address.substring(contact.address.length - 12)}'
                                    : contact.address,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.6),
                                  fontSize: 12,
                                  fontFamily: 'monospace',
                                ),
                              ),
                              if (contact.description?.isNotEmpty == true)
                                Text(
                                  contact.description!,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.4),
                                    fontSize: 11,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                        );
                      },
                    ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
              ),
              child: Text(
                '${_filteredContacts.length} contact${_filteredContacts.length == 1 ? '' : 's'}',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
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
    String integerPart = amount;
    String fractionalPart = '';
    final dotIndex = amount.indexOf('.');
    if (dotIndex != -1) {
      integerPart = amount.substring(0, dotIndex);
      fractionalPart = amount.substring(dotIndex);
    }

    return RichText(
      textAlign: TextAlign.start,
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
          if (fractionalPart.isNotEmpty)
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


// Top-level helper: render amount with smaller decimals
Widget buildAmountTextSmall(
  String amount, {
  required double fontSize,
  required double height,
  FontWeight fontWeight = FontWeight.w600,
  double letterSpacing = -0.5,
  Color color = Colors.white,
  TextAlign textAlign = TextAlign.start,
}) {
  // Read the interface provider to decide if decimals should show
  try {
    final interfaceProvider = Provider.of<InterfaceProvider>(MainScreen.navigatorKey.currentContext!, listen: false);
    final showDecimals = interfaceProvider.showDecimals;

    String integerPart = amount;
    String fractionalPart = '';
    final dotIndex = amount.indexOf('.');
    if (dotIndex != -1) {
      integerPart = amount.substring(0, dotIndex);
      fractionalPart = amount.substring(dotIndex);
    }

    return RichText(
      textAlign: textAlign,
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
  } catch (_) {
    // Fallback if provider/context is unavailable very early
    return RichText(
      textAlign: textAlign,
      text: TextSpan(
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
          letterSpacing: letterSpacing,
          height: height,
        ),
        text: amount,
      ),
    );
  }
}

