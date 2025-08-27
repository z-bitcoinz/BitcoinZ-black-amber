import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/currency_provider.dart';
import '../../widgets/enhanced_amount_input.dart';
import '../../services/qr_service.dart';
import '../../services/sharing_service.dart';
import '../../utils/responsive.dart';
import 'address_list_screen.dart';

class ReceiveScreen extends StatefulWidget {
  const ReceiveScreen({super.key});

  @override
  State<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends State<ReceiveScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  
  final _amountController = TextEditingController();
  final _memoController = TextEditingController();
  
  bool _isShieldedAddress = false;
  bool _showAdvanced = false;
  String? _selectedAddress;
  
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
    _amountController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  String _generateQRData() {
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    final address = _selectedAddress ?? walletProvider.currentAddress;

    if (address == null) return '';

    final amountText = _amountController.text.trim();
    final memo = _memoController.text.trim();

    double? amount;
    if (amountText.isNotEmpty) {
      amount = double.tryParse(amountText);
    }

    return QRService.generatePaymentURI(
      address: address,
      amount: amount,
      memo: memo.isNotEmpty && _isShieldedAddress ? memo : null,
    );
  }

  void _copyToClipboard(String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.lightImpact();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _sharePaymentRequest() async {
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    final currencyProvider = Provider.of<CurrencyProvider>(context, listen: false);
    final address = _selectedAddress ?? walletProvider.currentAddress;

    if (address == null) return;

    final amountText = _amountController.text.trim();
    final memo = _memoController.text.trim();

    double? amount;
    String? fiatAmount;

    if (amountText.isNotEmpty) {
      amount = double.tryParse(amountText);
      if (amount != null && amount > 0) {
        final fiatValue = currencyProvider.convertBtczToFiat(amount);
        if (fiatValue != null) {
          fiatAmount = currencyProvider.formatFiatAmount(amount);
        }
      }
    }

    await SharingService.sharePaymentRequest(
      context: context,
      address: address,
      amount: amount,
      memo: memo.isNotEmpty && _isShieldedAddress ? memo : null,
      fiatAmount: fiatAmount,
      currency: currencyProvider.selectedCurrency.code,
      includeQRImage: true,
    );
  }

  void _switchAddressType() {
    setState(() {
      _isShieldedAddress = !_isShieldedAddress;
      _selectedAddress = null; // Reset to default for selected type
    });
  }
  
  Future<void> _createNewAddress() async {
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    
    try {
      final addressType = _isShieldedAddress ? 'shielded' : 'transparent';
      final newAddress = await walletProvider.generateNewAddress(addressType);
      
      if (newAddress != null) {
        setState(() {
          _selectedAddress = newAddress;
        });
        
        if (mounted) {
          HapticFeedback.lightImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('New ${_isShieldedAddress ? 'shielded' : 'transparent'} address created'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create new address: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Receive BitcoinZ'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.list),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const AddressListScreen(),
                ),
              );
            },
            tooltip: 'View All Addresses',
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _sharePaymentRequest,
            tooltip: 'Share Payment Request',
          ),
        ],
      ),
      body: SafeArea(
        child: Consumer<WalletProvider>(
          builder: (context, walletProvider, child) {
            // Get the appropriate address based on type selection
            final currentAddress = _selectedAddress ?? 
                walletProvider.getAddressByType(_isShieldedAddress) ?? 
                'No ${_isShieldedAddress ? 'shielded' : 'transparent'} address available';
            final qrData = _generateQRData();
            final hasAddresses = walletProvider.getAddressesOfType(_isShieldedAddress).isNotEmpty;
            
            return Padding(
              padding: ResponsiveUtils.getScreenPadding(context),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Address Type Selector
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(ResponsiveUtils.getHorizontalPadding(context) * 0.75),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(ResponsiveUtils.getCardBorderRadius(context) * 0.75),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _isShieldedAddress ? 'Shielded Address' : 'Transparent Address',
                                    style: TextStyle(
                                      fontSize: ResponsiveUtils.getBodyTextSize(context),
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                  SizedBox(height: ResponsiveUtils.isSmallScreen(context) ? 4 : 6),
                                  Text(
                                    _isShieldedAddress 
                                        ? 'Private transactions with memo support'
                                        : 'Public transactions, faster and lower fees',
                                    style: TextStyle(
                                      fontSize: ResponsiveUtils.getBodyTextSize(context) * 0.85,
                                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _isShieldedAddress,
                              onChanged: (value) => _switchAddressType(),
                              activeColor: Theme.of(context).colorScheme.primary,
                            ),
                          ],
                        ),
                      ),
                      
                      // Create New Address Button
                      if (hasAddresses)
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: ResponsiveUtils.isSmallScreen(context) ? 12 : 16),
                          child: SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: walletProvider.isLoading ? null : _createNewAddress,
                              icon: walletProvider.isLoading 
                                  ? SizedBox(
                                      width: ResponsiveUtils.getIconSize(context, base: 16),
                                      height: ResponsiveUtils.getIconSize(context, base: 16),
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          Theme.of(context).colorScheme.primary,
                                        ),
                                      ),
                                    )
                                  : Icon(
                                      Icons.add,
                                      size: ResponsiveUtils.getIconSize(context, base: 18),
                                    ),
                              label: Text(
                                walletProvider.isLoading 
                                    ? 'Creating...' 
                                    : 'Create New ${_isShieldedAddress ? 'Shielded' : 'Transparent'} Address',
                                style: TextStyle(
                                  fontSize: ResponsiveUtils.getBodyTextSize(context) * 0.9,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                padding: EdgeInsets.symmetric(
                                  horizontal: ResponsiveUtils.getHorizontalPadding(context),
                                  vertical: ResponsiveUtils.isSmallScreen(context) ? 12 : 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(ResponsiveUtils.getCardBorderRadius(context) * 0.75),
                                ),
                                side: BorderSide(
                                  color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                                ),
                              ),
                            ),
                          ),
                        ),
                      
                      SizedBox(height: ResponsiveUtils.isSmallScreen(context) ? 24 : 32),
                      
                      // QR Code
                      Container(
                        padding: EdgeInsets.all(ResponsiveUtils.getHorizontalPadding(context)),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(ResponsiveUtils.getCardBorderRadius(context)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            QRService.generateQRWidget(
                              data: qrData,
                              size: ResponsiveUtils.isSmallMobile(context) ? 200 : 250,
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                              includeMargin: false,
                            )
                            else
                              Container(
                                width: ResponsiveUtils.isSmallMobile(context) ? 200 : 250,
                                height: ResponsiveUtils.isSmallMobile(context) ? 200 : 250,
                                decoration: BoxDecoration(
                                  color: Colors.grey.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(ResponsiveUtils.getCardBorderRadius(context) * 0.5),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.qr_code,
                                      size: ResponsiveUtils.getIconSize(context, base: 64),
                                      color: Colors.grey,
                                    ),
                                    SizedBox(height: ResponsiveUtils.isSmallScreen(context) ? 12 : 16),
                                    Text(
                                      hasAddresses 
                                          ? 'QR Code will appear here'
                                          : 'No ${_isShieldedAddress ? 'shielded' : 'transparent'} addresses available',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: ResponsiveUtils.getBodyTextSize(context),
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    if (!hasAddresses) ...[
                                      SizedBox(height: ResponsiveUtils.isSmallScreen(context) ? 12 : 16),
                                      ElevatedButton.icon(
                                        onPressed: walletProvider.isLoading ? null : _createNewAddress,
                                        icon: walletProvider.isLoading 
                                            ? SizedBox(
                                                width: ResponsiveUtils.getIconSize(context, base: 16),
                                                height: ResponsiveUtils.getIconSize(context, base: 16),
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                                ),
                                              )
                                            : Icon(
                                                Icons.add,
                                                size: ResponsiveUtils.getIconSize(context, base: 16),
                                              ),
                                        label: Text(
                                          walletProvider.isLoading 
                                              ? 'Creating...' 
                                              : 'Create First Address',
                                          style: TextStyle(
                                            fontSize: ResponsiveUtils.getBodyTextSize(context) * 0.85,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: ResponsiveUtils.getHorizontalPadding(context),
                                            vertical: ResponsiveUtils.isSmallScreen(context) ? 8 : 12,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(ResponsiveUtils.getCardBorderRadius(context) * 0.5),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            
                            SizedBox(height: ResponsiveUtils.isSmallScreen(context) ? 16 : 20),
                            
                            // Address Display
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(ResponsiveUtils.getHorizontalPadding(context) * 0.75),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(ResponsiveUtils.getCardBorderRadius(context) * 0.5),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    'Your Address',
                                    style: TextStyle(
                                      fontSize: ResponsiveUtils.getBodyTextSize(context) * 0.9,
                                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                    ),
                                  ),
                                  SizedBox(height: ResponsiveUtils.isSmallScreen(context) ? 6 : 8),
                                  GestureDetector(
                                    onTap: () => _copyToClipboard(currentAddress, 'Address copied to clipboard'),
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: ResponsiveUtils.getHorizontalPadding(context) * 0.5,
                                        vertical: ResponsiveUtils.isSmallScreen(context) ? 8 : 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.background,
                                        borderRadius: BorderRadius.circular(ResponsiveUtils.getCardBorderRadius(context) * 0.5),
                                        border: Border.all(
                                          color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              currentAddress,
                                              style: TextStyle(
                                                fontSize: ResponsiveUtils.getBodyTextSize(context) * 0.85,
                                                fontFamily: 'monospace',
                                                fontWeight: FontWeight.w500,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                          SizedBox(width: ResponsiveUtils.isSmallMobile(context) ? 6 : 8),
                                          Icon(
                                            Icons.copy,
                                            size: ResponsiveUtils.getIconSize(context, base: 16),
                                            color: Theme.of(context).colorScheme.primary,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      SizedBox(height: ResponsiveUtils.isSmallScreen(context) ? 24 : 32),
                      
                      // Advanced Options
                      ExpansionTile(
                        title: Text(
                          'Payment Request Options',
                          style: TextStyle(
                            fontSize: ResponsiveUtils.getBodyTextSize(context),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        leading: Icon(
                          Icons.tune,
                          size: ResponsiveUtils.getIconSize(context, base: 20),
                        ),
                        children: [
                          Padding(
                            padding: EdgeInsets.all(ResponsiveUtils.getHorizontalPadding(context)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Amount Field
                                Text(
                                  'Request Amount (Optional)',
                                  style: TextStyle(
                                    fontSize: ResponsiveUtils.getBodyTextSize(context) * 0.9,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                                SizedBox(height: ResponsiveUtils.isSmallScreen(context) ? 6 : 8),
                                EnhancedAmountInput(
                                  controller: _amountController,
                                  label: 'Request Amount (Optional)',
                                  hintText: '0.00000000',
                                  onChanged: (value) {
                                    setState(() {}); // Rebuild to update QR code
                                  },
                                ),
                                
                                // Memo Field (only for shielded addresses)
                                if (_isShieldedAddress) ...[
                                  SizedBox(height: ResponsiveUtils.isSmallScreen(context) ? 16 : 20),
                                  Text(
                                    'Memo (Optional)',
                                    style: TextStyle(
                                      fontSize: ResponsiveUtils.getBodyTextSize(context) * 0.9,
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                  SizedBox(height: ResponsiveUtils.isSmallScreen(context) ? 6 : 8),
                                  TextField(
                                    controller: _memoController,
                                    maxLines: 2,
                                    maxLength: 512,
                                    decoration: InputDecoration(
                                      hintText: 'Add a note for this payment request',
                                      filled: true,
                                      fillColor: Theme.of(context).colorScheme.background,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(ResponsiveUtils.getCardBorderRadius(context) * 0.75),
                                      ),
                                      contentPadding: ResponsiveUtils.getInputFieldPadding(context),
                                    ),
                                    style: TextStyle(
                                      fontSize: ResponsiveUtils.getBodyTextSize(context),
                                    ),
                                    onChanged: (value) {
                                      setState(() {}); // Rebuild to update QR code
                                    },
                                  ),
                                ],
                                
                                SizedBox(height: ResponsiveUtils.isSmallScreen(context) ? 12 : 16),
                                
                                // Info Text
                                Container(
                                  padding: EdgeInsets.all(ResponsiveUtils.getHorizontalPadding(context) * 0.75),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(ResponsiveUtils.getCardBorderRadius(context) * 0.5),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.info_outline,
                                        size: ResponsiveUtils.getIconSize(context, base: 16),
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                      SizedBox(width: ResponsiveUtils.isSmallMobile(context) ? 6 : 8),
                                      Expanded(
                                        child: Text(
                                          'Adding amount and memo will include them in the QR code for easier payments.',
                                          style: TextStyle(
                                            fontSize: ResponsiveUtils.getBodyTextSize(context) * 0.8,
                                            color: Theme.of(context).colorScheme.primary.withOpacity(0.8),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      
                      SizedBox(height: ResponsiveUtils.getVerticalPadding(context)),
                    ],
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