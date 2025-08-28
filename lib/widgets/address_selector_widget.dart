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

class _AddressSelectorWidgetState extends State<AddressSelectorWidget> with WidgetsBindingObserver {
  Map<String, AddressLabel?> _addressLabels = {};
  bool _isLoading = false;
  WalletProvider? _walletProvider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadAddressLabels();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _walletProvider?.removeListener(_onWalletProviderChanged);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newWalletProvider = Provider.of<WalletProvider>(context, listen: false);
    if (_walletProvider != newWalletProvider) {
      _walletProvider?.removeListener(_onWalletProviderChanged);
      _walletProvider = newWalletProvider;
      _walletProvider?.addListener(_onWalletProviderChanged);
      // Refresh labels when provider changes
      _loadAddressLabels();
    }
  }

  void _onWalletProviderChanged() {
    // Refresh labels when wallet provider notifies changes
    if (mounted) {
      _loadAddressLabels();
    }
  }

  @override
  void didUpdateWidget(AddressSelectorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isShieldedAddress != widget.isShieldedAddress) {
      _loadAddressLabels();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Refresh labels when app becomes active (user returns from another screen)
    if (state == AppLifecycleState.resumed) {
      _loadAddressLabels();
    }
  }

  Future<void> _loadAddressLabels() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final walletProvider = Provider.of<WalletProvider>(context, listen: false);
      final addresses = walletProvider.getAddressesOfType(widget.isShieldedAddress);

      final Map<String, AddressLabel?> labels = {};
      for (final address in addresses) {
        final addressLabels = await walletProvider.getAddressLabels(address);
        labels[address] = addressLabels.isNotEmpty ? addressLabels.first : null;
      }

      if (mounted) {
        setState(() {
          _addressLabels = labels;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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

  /// Refresh address labels - can be called externally when returning from other screens
  Future<void> refreshLabels() async {
    await _loadAddressLabels();
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

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: addresses.length > 1 ? _showAddressSelector : null,
            borderRadius: BorderRadius.circular(ResponsiveUtils.getCardBorderRadius(context)),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(ResponsiveUtils.getCardBorderRadius(context)),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                ),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: ResponsiveUtils.getHorizontalPadding(context) * 0.5,
                  vertical: ResponsiveUtils.isSmallScreen(context) ? 8 : 10,
                ),
                child: Row(
                  children: [
                    // Address type icon
                    Icon(
                      widget.isShieldedAddress ? Icons.shield : Icons.visibility,
                      size: ResponsiveUtils.getIconSize(context, base: 18),
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    SizedBox(width: ResponsiveUtils.isSmallScreen(context) ? 6 : 8),

                    // Address info (two lines)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Line 1: Label name and tag
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _getAddressDisplayName(currentAddress, currentLabel),
                                  style: TextStyle(
                                    fontSize: ResponsiveUtils.getBodyTextSize(context) * 0.95,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (currentLabel != null) ...[
                                SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Color(int.parse(currentLabel.color.replaceFirst('#', '0xFF'))).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        AddressLabelManager.getIcon(currentLabel.type),
                                        size: 9,
                                        color: Color(int.parse(currentLabel.color.replaceFirst('#', '0xFF'))),
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        currentLabel.labelName,
                                        style: TextStyle(
                                          fontSize: 9,
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

                          SizedBox(height: 1),

                          // Line 2: Formatted address
                          Text(
                            _formatAddress(currentAddress),
                            style: TextStyle(
                              fontSize: ResponsiveUtils.getBodyTextSize(context) * 0.75,
                              fontFamily: 'monospace',
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),

                    // Dropdown arrow (if multiple addresses)
                    if (addresses.length > 1) ...[
                      SizedBox(width: 8),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _showAddressSelector,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            child: Icon(
                              Icons.keyboard_arrow_down,
                              size: ResponsiveUtils.getIconSize(context, base: 22),
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showAddressSelector() {
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    final addresses = walletProvider.getAddressesOfType(widget.isShieldedAddress);

    // Sort addresses: tagged addresses first, then unlabeled ones
    final sortedAddresses = List<String>.from(addresses);
    sortedAddresses.sort((a, b) {
      final labelA = _addressLabels[a];
      final labelB = _addressLabels[b];

      // Tagged addresses come first
      if (labelA != null && labelB == null) return -1;
      if (labelA == null && labelB != null) return 1;

      // If both have labels, sort by label name
      if (labelA != null && labelB != null) {
        return labelA.labelName.compareTo(labelB.labelName);
      }

      // If both are unlabeled, sort by address
      return a.compareTo(b);
    });
    
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
                itemCount: sortedAddresses.length,
                itemBuilder: (context, index) {
                  final address = sortedAddresses[index];
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
