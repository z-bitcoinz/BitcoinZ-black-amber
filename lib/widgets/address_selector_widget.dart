import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/wallet_provider.dart';
import '../models/address_label.dart';
import '../utils/responsive.dart';

/// Widget for selecting addresses with labels in the receive screen
class AddressSelectorWidget extends StatefulWidget {
  final bool isShieldedAddress;
  final String? selectedAddress;
  final Function(String?) onAddressSelected;

  const AddressSelectorWidget({
    super.key,
    required this.isShieldedAddress,
    required this.selectedAddress,
    required this.onAddressSelected,
  });

  @override
  State<AddressSelectorWidget> createState() => _AddressSelectorWidgetState();
}

class _AddressSelectorWidgetState extends State<AddressSelectorWidget> {
  Map<String, AddressLabel?> _addressLabels = {};

  @override
  void initState() {
    super.initState();
    _loadAddressLabels();
  }

  @override
  void didUpdateWidget(AddressSelectorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isShieldedAddress != widget.isShieldedAddress) {
      _loadAddressLabels();
    }
  }

  Future<void> _loadAddressLabels() async {
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    final addresses = walletProvider.getAddressesOfType(widget.isShieldedAddress);

    final Map<String, AddressLabel?> labels = {};
    for (final address in addresses) {
      final addressLabels = await walletProvider.getAddressLabels(address);
      labels[address] = addressLabels.isNotEmpty ? addressLabels.first : null;
    }

    setState(() {
      _addressLabels = labels;
    });
  }

  String _getAddressDisplayName(String address, AddressLabel? label) {
    if (label != null) {
      return label.labelName;
    }
    
    // Generate a friendly name based on address position
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    final addresses = walletProvider.getAddressesOfType(widget.isShieldedAddress);
    final index = addresses.indexOf(address);
    
    if (index >= 0) {
      final addressType = widget.isShieldedAddress ? 'Shielded' : 'Transparent';
      return '$addressType Address ${index + 1}';
    }
    
    return 'Address';
  }

  String _formatAddress(String address) {
    if (address.length <= 16) return address;
    return '${address.substring(0, 8)}...${address.substring(address.length - 8)}';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WalletProvider>(
      builder: (context, walletProvider, child) {
        final addresses = walletProvider.getAddressesOfType(widget.isShieldedAddress);
        
        if (addresses.isEmpty) {
          return Container(
            padding: EdgeInsets.all(ResponsiveUtils.getHorizontalPadding(context)),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(ResponsiveUtils.getCardBorderRadius(context)),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange,
                  size: ResponsiveUtils.getIconSize(context, base: 20),
                ),
                SizedBox(width: ResponsiveUtils.isSmallScreen(context) ? 8 : 12),
                Expanded(
                  child: Text(
                    'No ${widget.isShieldedAddress ? 'shielded' : 'transparent'} addresses available',
                    style: TextStyle(
                      fontSize: ResponsiveUtils.getBodyTextSize(context),
                      color: Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        final currentAddress = widget.selectedAddress ?? addresses.first;
        final currentLabel = _addressLabels[currentAddress];

        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(ResponsiveUtils.getCardBorderRadius(context)),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: EdgeInsets.all(ResponsiveUtils.getHorizontalPadding(context) * 0.75),
                child: Row(
                  children: [
                    Icon(
                      widget.isShieldedAddress ? Icons.shield : Icons.visibility,
                      size: ResponsiveUtils.getIconSize(context, base: 20),
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    SizedBox(width: ResponsiveUtils.isSmallScreen(context) ? 8 : 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Selected Address',
                            style: TextStyle(
                              fontSize: ResponsiveUtils.getBodyTextSize(context) * 0.9,
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                            ),
                          ),
                          SizedBox(height: ResponsiveUtils.isSmallScreen(context) ? 2 : 4),
                          Text(
                            _getAddressDisplayName(currentAddress, currentLabel),
                            style: TextStyle(
                              fontSize: ResponsiveUtils.getBodyTextSize(context),
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (addresses.length > 1)
                      IconButton(
                        onPressed: _showAddressSelector,
                        icon: Icon(
                          Icons.keyboard_arrow_down,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        tooltip: 'Select Address',
                      ),
                  ],
                ),
              ),
              
              // Address preview
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(ResponsiveUtils.getHorizontalPadding(context) * 0.75),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface.withOpacity(0.5),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(ResponsiveUtils.getCardBorderRadius(context)),
                    bottomRight: Radius.circular(ResponsiveUtils.getCardBorderRadius(context)),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _formatAddress(currentAddress),
                        style: TextStyle(
                          fontSize: ResponsiveUtils.getBodyTextSize(context) * 0.85,
                          fontFamily: 'monospace',
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                        ),
                      ),
                    ),
                    if (currentLabel != null) ...[
                      SizedBox(width: ResponsiveUtils.isSmallScreen(context) ? 8 : 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Color(int.parse(currentLabel.color.replaceFirst('#', '0xFF'))).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              AddressLabelManager.getIcon(currentLabel.type),
                              size: 12,
                              color: Color(int.parse(currentLabel.color.replaceFirst('#', '0xFF'))),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              currentLabel.labelName,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Color(int.parse(currentLabel.color.replaceFirst('#', '0xFF'))),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddressSelector() {
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    final addresses = walletProvider.getAddressesOfType(widget.isShieldedAddress);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text(
                'Select ${widget.isShieldedAddress ? 'Shielded' : 'Transparent'} Address',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            
            // Address list
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: addresses.length,
                itemBuilder: (context, index) {
                  final address = addresses[index];
                  final label = _addressLabels[address];
                  final isSelected = address == widget.selectedAddress;
                  
                  return ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isSelected 
                            ? Theme.of(context).colorScheme.primary.withOpacity(0.2)
                            : Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected 
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.outline.withOpacity(0.3),
                        ),
                      ),
                      child: Icon(
                        isSelected ? Icons.check : (widget.isShieldedAddress ? Icons.shield : Icons.visibility),
                        color: isSelected 
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        size: 20,
                      ),
                    ),
                    title: Text(
                      _getAddressDisplayName(address, label),
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        color: isSelected 
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatAddress(address),
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                        if (label != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                AddressLabelManager.getIcon(label.type),
                                size: 12,
                                color: Color(int.parse(label.color.replaceFirst('#', '0xFF'))),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                label.labelName,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(int.parse(label.color.replaceFirst('#', '0xFF'))),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                    onTap: () {
                      widget.onAddressSelected(address);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
            
            // Bottom padding
            SizedBox(height: MediaQuery.of(context).padding.bottom > 0 
                ? MediaQuery.of(context).padding.bottom * 0.5 
                : 8),
          ],
        ),
      ),
    );
  }
}
