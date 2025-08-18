import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../providers/wallet_provider.dart';
import 'address_list_screen.dart';

class ReceiveScreenModern extends StatefulWidget {
  const ReceiveScreenModern({super.key});

  @override
  State<ReceiveScreenModern> createState() => _ReceiveScreenModernState();
}

class _ReceiveScreenModernState extends State<ReceiveScreenModern>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  
  final _amountController = TextEditingController();
  final _memoController = TextEditingController();
  
  bool _isShieldedAddress = false;
  String? _selectedAddress;
  bool _showAmountField = false;
  
  @override
  void initState() {
    super.initState();
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
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
    
    // Basic URI format for BitcoinZ
    String qrData = 'bitcoinz:$address';
    
    final amount = _amountController.text.trim();
    final memo = _memoController.text.trim();
    
    List<String> params = [];
    
    if (amount.isNotEmpty) {
      params.add('amount=$amount');
    }
    
    if (memo.isNotEmpty && _isShieldedAddress) {
      params.add('memo=$memo');
    }
    
    if (params.isNotEmpty) {
      qrData += '?${params.join('&')}';
    }
    
    return qrData;
  }

  void _copyToClipboard(String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.lightImpact();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF4CAF50),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _shareAddress() {
    final address = _selectedAddress ?? 
        Provider.of<WalletProvider>(context, listen: false).currentAddress;
    if (address != null) {
      _copyToClipboard(address, 'Address copied to clipboard');
    }
  }

  void _switchAddressType() {
    setState(() {
      _isShieldedAddress = !_isShieldedAddress;
      _selectedAddress = null;
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
              backgroundColor: const Color(0xFF4CAF50),
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create address: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Receive',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.list, size: 20),
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
            icon: const Icon(Icons.share, size: 20),
            onPressed: _shareAddress,
            tooltip: 'Share Address',
          ),
        ],
      ),
      body: SafeArea(
        child: Consumer<WalletProvider>(
          builder: (context, walletProvider, child) {
            final currentAddress = _selectedAddress ?? 
                walletProvider.getAddressByType(_isShieldedAddress) ?? 
                '';
            final qrData = _generateQRData();
            final hasAddresses = walletProvider.getAddressesOfType(_isShieldedAddress).isNotEmpty;
            
            return FadeTransition(
              opacity: _fadeAnimation,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Address Type Toggle
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A2A2A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.05),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                if (_isShieldedAddress) _switchAddressType();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: !_isShieldedAddress 
                                      ? const Color(0xFFFF6B00).withOpacity(0.2)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  border: !_isShieldedAddress
                                      ? Border.all(
                                          color: const Color(0xFFFF6B00).withOpacity(0.5),
                                        )
                                      : null,
                                ),
                                child: Center(
                                  child: Text(
                                    'Transparent',
                                    style: TextStyle(
                                      color: !_isShieldedAddress 
                                          ? const Color(0xFFFF6B00)
                                          : Colors.white.withOpacity(0.5),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                if (!_isShieldedAddress) _switchAddressType();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: _isShieldedAddress 
                                      ? const Color(0xFFFF6B00).withOpacity(0.2)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  border: _isShieldedAddress
                                      ? Border.all(
                                          color: const Color(0xFFFF6B00).withOpacity(0.5),
                                        )
                                      : null,
                                ),
                                child: Center(
                                  child: Text(
                                    'Shielded',
                                    style: TextStyle(
                                      color: _isShieldedAddress 
                                          ? const Color(0xFFFF6B00)
                                          : Colors.white.withOpacity(0.5),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // QR Code Container
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF2A2A2A),
                            const Color(0xFF1F1F1F),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.05),
                        ),
                      ),
                      child: Column(
                        children: [
                          // QR Code
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: qrData.isNotEmpty && hasAddresses
                                ? QrImageView(
                                    data: qrData,
                                    version: QrVersions.auto,
                                    size: 180,
                                    backgroundColor: Colors.white,
                                    foregroundColor: Colors.black,
                                    errorCorrectionLevel: QrErrorCorrectLevel.M,
                                  )
                                : Container(
                                    width: 180,
                                    height: 180,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.qr_code_2,
                                          size: 48,
                                          color: Colors.grey.withOpacity(0.5),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          hasAddresses 
                                              ? 'QR Code'
                                              : 'No address available',
                                          style: TextStyle(
                                            color: Colors.grey.withOpacity(0.5),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                          ),
                          
                          const SizedBox(height: 20),
                          
                          // Address Display
                          if (currentAddress.isNotEmpty) ...[
                            Text(
                              _isShieldedAddress ? 'SHIELDED ADDRESS' : 'TRANSPARENT ADDRESS',
                              style: TextStyle(
                                color: const Color(0xFFFF6B00).withOpacity(0.8),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: () => _copyToClipboard(currentAddress, 'Address copied'),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1A1A1A).withOpacity(0.8),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.1),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        currentAddress,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontFamily: 'monospace',
                                          color: Colors.white,
                                          height: 1.4,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(
                                      Icons.copy,
                                      size: 14,
                                      color: const Color(0xFFFF6B00),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // New Address Button
                    if (hasAddresses)
                      OutlinedButton.icon(
                        onPressed: walletProvider.isLoading ? null : _createNewAddress,
                        icon: walletProvider.isLoading 
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B00)),
                                ),
                              )
                            : const Icon(Icons.add, size: 18),
                        label: Text(
                          walletProvider.isLoading 
                              ? 'Creating...' 
                              : 'New ${_isShieldedAddress ? 'Shielded' : 'Transparent'} Address',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFFF6B00),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          side: BorderSide(
                            color: const Color(0xFFFF6B00).withOpacity(0.5),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      )
                    else
                      Container(
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [const Color(0xFFFF6B00), const Color(0xFFFFAA00)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: ElevatedButton.icon(
                          onPressed: walletProvider.isLoading ? null : _createNewAddress,
                          icon: walletProvider.isLoading 
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Icon(Icons.add, size: 18),
                          label: Text(
                            walletProvider.isLoading 
                                ? 'Creating...' 
                                : 'Create First Address',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                        ),
                      ),
                    
                    // Amount Request (Optional)
                    if (hasAddresses) ...[
                      const SizedBox(height: 24),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _showAmountField = !_showAmountField;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2A2A2A),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.05),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _showAmountField 
                                    ? Icons.keyboard_arrow_up 
                                    : Icons.keyboard_arrow_down,
                                color: Colors.white.withOpacity(0.5),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Request Specific Amount',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const Spacer(),
                              Icon(
                                Icons.attach_money,
                                color: const Color(0xFFFF6B00).withOpacity(0.6),
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      if (_showAmountField) ...[
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF2A2A2A),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.1),
                            ),
                          ),
                          child: TextField(
                            controller: _amountController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                            decoration: InputDecoration(
                              hintText: '0.00',
                              hintStyle: TextStyle(
                                color: Colors.white.withOpacity(0.3),
                                fontSize: 16,
                              ),
                              prefixIcon: Icon(
                                Icons.currency_bitcoin,
                                color: Colors.white.withOpacity(0.5),
                                size: 20,
                              ),
                              suffixText: 'BTCZ',
                              suffixStyle: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            ),
                            onChanged: (value) {
                              setState(() {}); // Rebuild to update QR code
                            },
                          ),
                        ),
                        
                        if (_isShieldedAddress) ...[
                          const SizedBox(height: 12),
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF2A2A2A),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.1),
                              ),
                            ),
                            child: TextField(
                              controller: _memoController,
                              maxLines: 2,
                              maxLength: 512,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.white,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Add a memo (optional)',
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
                              onChanged: (value) {
                                setState(() {}); // Rebuild to update QR code
                              },
                            ),
                          ),
                        ],
                      ],
                    ],
                    
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}