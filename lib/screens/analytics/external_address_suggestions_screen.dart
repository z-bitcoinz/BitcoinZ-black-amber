import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/wallet_provider.dart';
import '../../models/address_label.dart';
import '../../widgets/address_label_dialog.dart';

/// Screen for managing external address suggestions and auto-labeling
class ExternalAddressSuggestionsScreen extends StatefulWidget {
  const ExternalAddressSuggestionsScreen({super.key});

  @override
  State<ExternalAddressSuggestionsScreen> createState() => _ExternalAddressSuggestionsScreenState();
}

class _ExternalAddressSuggestionsScreenState extends State<ExternalAddressSuggestionsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _unlabeledAddresses = [];
  Map<String, AddressLabelType> _suggestions = {};
  List<AddressLabel> _autoSuggestions = [];
  Set<String> _selectedAddresses = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSuggestions();
    });
  }

  Future<void> _loadSuggestions() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final walletProvider = Provider.of<WalletProvider>(context, listen: false);
      
      // Get unlabeled external addresses
      _unlabeledAddresses = await walletProvider.getUnlabeledExternalAddresses();
      
      // Get suggestions for these addresses
      _suggestions = await walletProvider.suggestLabelsForExternalAddresses(_unlabeledAddresses);
      
      // Get auto-generated suggestions
      _autoSuggestions = await walletProvider.autoSuggestExternalAddressLabels();
      
    } catch (e) {
      print('Error loading suggestions: $e');
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('External Address Suggestions'),
        elevation: 0,
        actions: [
          if (_selectedAddresses.isNotEmpty)
            TextButton(
              onPressed: _applySelectedSuggestions,
              child: Text('Apply ${_selectedAddresses.length}'),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSuggestions,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _unlabeledAddresses.isEmpty
              ? _buildEmptyState()
              : Column(
                  children: [
                    // Summary card
                    _buildSummaryCard(),
                    
                    // Suggestions list
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _unlabeledAddresses.length,
                        itemBuilder: (context, index) {
                          final addressData = _unlabeledAddresses[index];
                          return _buildSuggestionCard(addressData);
                        },
                      ),
                    ),
                  ],
                ),
      floatingActionButton: _selectedAddresses.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _applySelectedSuggestions,
              icon: const Icon(Icons.label),
              label: Text('Label ${_selectedAddresses.length}'),
            )
          : null,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle,
            size: 64,
            color: Colors.green.withOpacity(0.7),
          ),
          const SizedBox(height: 16),
          Text(
            'All External Addresses Labeled',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'You have labeled all frequently used external addresses',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primary.withOpacity(0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'External Address Analysis',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Found ${_unlabeledAddresses.length} frequently used external addresses that could benefit from labels',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildSummaryItem(
                  'Unlabeled',
                  '${_unlabeledAddresses.length}',
                  Icons.label_off,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSummaryItem(
                  'Selected',
                  '${_selectedAddresses.length}',
                  Icons.check_box,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 16),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.white70,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildSuggestionCard(Map<String, dynamic> addressData) {
    final address = addressData['address'] as String;
    final transactionCount = addressData['transactionCount'] as int;
    final totalAmount = addressData['totalAmount'] as double;
    final lastTransaction = addressData['lastTransaction'] as DateTime;
    final suggestedType = _suggestions[address] ?? AddressLabelType.unknown;
    final isSelected = _selectedAddresses.contains(address);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Checkbox(
                  value: isSelected,
                  onChanged: (value) {
                    setState(() {
                      if (value == true) {
                        _selectedAddresses.add(address);
                      } else {
                        _selectedAddresses.remove(address);
                      }
                    });
                  },
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            AddressLabelManager.getIcon(suggestedType),
                            size: 16,
                            color: Color(int.parse(AddressLabelManager.getColor(suggestedType).replaceFirst('#', '0xFF'))),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              AddressLabelManager.getDisplayName(suggestedType),
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Color(int.parse(AddressLabelManager.getColor(suggestedType).replaceFirst('#', '0xFF'))),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${address.substring(0, 12)}...${address.substring(address.length - 8)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _showCustomLabelDialog(address),
                  tooltip: 'Custom label',
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Statistics
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Transactions',
                    '$transactionCount',
                    Icons.receipt,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Total Amount',
                    '${totalAmount.toStringAsFixed(2)} BTCZ',
                    Icons.account_balance_wallet,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            Row(
              children: [
                Icon(
                  Icons.schedule,
                  size: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  'Last transaction: ${DateFormat('MMM dd, yyyy').format(lastTransaction)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          size: 14,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showCustomLabelDialog(String address) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AddressLabelDialog(prefilledAddress: address),
    );
    
    if (result == true) {
      // Reload suggestions if a custom label was added
      _loadSuggestions();
    }
  }

  Future<void> _applySelectedSuggestions() async {
    if (_selectedAddresses.isEmpty) return;

    try {
      final walletProvider = Provider.of<WalletProvider>(context, listen: false);
      
      for (final address in _selectedAddresses) {
        final addressData = _unlabeledAddresses.firstWhere(
          (data) => data['address'] == address,
        );
        final suggestedType = _suggestions[address] ?? AddressLabelType.unknown;
        final transactionCount = addressData['transactionCount'] as int;
        
        // Generate label name
        String labelName;
        switch (suggestedType) {
          case AddressLabelType.exchange:
            labelName = 'Exchange ($transactionCount txs)';
            break;
          case AddressLabelType.merchant:
            labelName = 'Merchant ($transactionCount txs)';
            break;
          case AddressLabelType.service:
            labelName = 'Service ($transactionCount txs)';
            break;
          case AddressLabelType.friend:
            labelName = 'Contact ($transactionCount txs)';
            break;
          default:
            labelName = 'External Address';
        }
        
        final label = AddressLabelManager.createLabel(
          address: address,
          labelName: labelName,
          type: suggestedType,
          isOwned: false,
          description: 'Auto-suggested based on transaction patterns',
        );
        
        await walletProvider.addAddressLabel(label);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully labeled ${_selectedAddresses.length} addresses'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Clear selection and reload
        setState(() {
          _selectedAddresses.clear();
        });
        _loadSuggestions();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error applying labels: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
