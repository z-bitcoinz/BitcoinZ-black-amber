import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/wallet_provider.dart';
import '../../models/address_label.dart';
import '../../widgets/address_label_dialog.dart';
import '../analytics/address_monitoring_screen.dart';
import '../../utils/responsive.dart';
import '../../utils/constants.dart';

class AddressListScreen extends StatefulWidget {
  const AddressListScreen({super.key});

  @override
  State<AddressListScreen> createState() => _AddressListScreenState();
}

class _AddressListScreenState extends State<AddressListScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  bool _isCreatingAddress = false;
  Map<String, List<AddressLabel>> _addressLabelsCache = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAddressLabels();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAddressLabels() async {
    try {
      final walletProvider = Provider.of<WalletProvider>(context, listen: false);
      final allLabels = await walletProvider.getAllAddressLabels();

      // Group labels by address
      _addressLabelsCache.clear();
      for (final label in allLabels) {
        if (!_addressLabelsCache.containsKey(label.address)) {
          _addressLabelsCache[label.address] = [];
        }
        _addressLabelsCache[label.address]!.add(label);
      }

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('Error loading address labels: $e');
    }
  }

  Future<void> _createNewAddress(String type) async {
    if (_isCreatingAddress) return;

    setState(() {
      _isCreatingAddress = true;
    });

    try {
      final walletProvider = Provider.of<WalletProvider>(context, listen: false);
      final newAddress = await walletProvider.generateNewAddress(type);

      if (newAddress != null && mounted) {
        HapticFeedback.lightImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('New ${type} address created'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create address: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingAddress = false;
        });
      }
    }
  }

  void _copyToClipboard(String address, String type) {
    Clipboard.setData(ClipboardData(text: address));
    HapticFeedback.lightImpact();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$type address copied to clipboard'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Addresses'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const AddressMonitoringScreen(),
                ),
              );
            },
            tooltip: 'Address Analytics',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              icon: Icon(Icons.visibility),
              text: 'Transparent',
            ),
            Tab(
              icon: Icon(Icons.security),
              text: 'Shielded',
            ),
          ],
        ),
      ),
      body: Consumer<WalletProvider>(
        builder: (context, walletProvider, child) {
          return TabBarView(
            controller: _tabController,
            children: [
              // Transparent Addresses Tab
              _buildAddressList(
                addresses: walletProvider.getAddressesOfType(false),
                type: 'Transparent',
                addressType: 'transparent',
                icon: Icons.visibility,
                color: Colors.blue,
                description: 'Public addresses for faster transactions',
              ),
              
              // Shielded Addresses Tab
              _buildAddressList(
                addresses: walletProvider.getAddressesOfType(true),
                type: 'Shielded',
                addressType: 'shielded',
                icon: Icons.security,
                color: Colors.green,
                description: 'Private addresses with enhanced privacy',
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAddressList({
    required List<String> addresses,
    required String type,
    required String addressType,
    required IconData icon,
    required Color color,
    required String description,
  }) {
    return Column(
      children: [
        // Header Section
        Container(
          width: double.infinity,
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$type Addresses',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          description,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: color.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isCreatingAddress ? null : () => _createNewAddress(addressType),
                  icon: _isCreatingAddress 
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Icon(Icons.add, size: 18),
                  label: Text(
                    _isCreatingAddress ? 'Creating...' : 'Create New $type Address',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Addresses List
        Expanded(
          child: addresses.isEmpty
              ? _buildEmptyState(type, icon, color)
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: addresses.length,
                  itemBuilder: (context, index) {
                    final address = addresses[index];
                    return _buildAddressCard(address, index, type, color);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String type, IconData icon, Color color) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: color.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No $type Addresses',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first $type address using the button above',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAddressCard(String address, int index, String type, Color color) {
    final labels = _addressLabelsCache[address] ?? [];
    final primaryLabel = labels.isNotEmpty ? labels.first : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (primaryLabel != null) ...[
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: Color(int.parse(primaryLabel.color.replaceFirst('#', '0xFF'))),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                primaryLabel.labelName,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Color(int.parse(primaryLabel.color.replaceFirst('#', '0xFF'))),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$type Address #${index + 1}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ] else ...[
                        Text(
                          '$type Address #${index + 1}',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: color,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        labels.isNotEmpty ? Icons.label : Icons.label_outline,
                        size: 18,
                      ),
                      onPressed: () => _showLabelDialog(address),
                      tooltip: labels.isNotEmpty ? 'Edit labels' : 'Add label',
                      color: labels.isNotEmpty
                          ? Color(int.parse(primaryLabel!.color.replaceFirst('#', '0xFF')))
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 18),
                      onPressed: () => _copyToClipboard(address, type),
                      tooltip: 'Copy address',
                      color: color,
                    ),
                  ],
                ),
              ],
            ),

            // Show additional labels if any
            if (labels.length > 1) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: labels.skip(1).map((label) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Color(int.parse(label.color.replaceFirst('#', '0xFF'))).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Color(int.parse(label.color.replaceFirst('#', '0xFF'))).withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    label.labelName,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Color(int.parse(label.color.replaceFirst('#', '0xFF'))),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                )).toList(),
              ),
            ],
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                ),
              ),
              child: SelectableText(
                address,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ),
            // Show label category and type info if labeled
            if (primaryLabel != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    AddressLabelManager.getIcon(primaryLabel.type),
                    size: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    AddressLabelManager.getCategoryDisplayName(primaryLabel.category),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    primaryLabel.isOwned ? 'Own Address' : 'External Address',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 16,
                    color: Colors.green.withOpacity(0.7),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Active',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.green.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showLabelDialog(String address) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AddressLabelDialog(prefilledAddress: address),
    );

    if (result == true) {
      // Reload labels if a label was added/updated
      _loadAddressLabels();
    }
  }
}