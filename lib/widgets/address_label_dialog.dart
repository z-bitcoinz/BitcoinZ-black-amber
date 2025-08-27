import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/address_label.dart';
import '../providers/wallet_provider.dart';

/// Dialog for creating and editing address labels
class AddressLabelDialog extends StatefulWidget {
  final AddressLabel? existingLabel;
  final String? prefilledAddress;

  const AddressLabelDialog({
    super.key,
    this.existingLabel,
    this.prefilledAddress,
  });

  @override
  State<AddressLabelDialog> createState() => _AddressLabelDialogState();
}

class _AddressLabelDialogState extends State<AddressLabelDialog> {
  final _formKey = GlobalKey<FormState>();
  final _addressController = TextEditingController();
  final _labelNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  AddressLabelCategory _selectedCategory = AddressLabelCategory.other;
  AddressLabelType _selectedType = AddressLabelType.custom;
  bool _isOwned = true;
  String _selectedColor = '#9E9E9E';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    
    if (widget.existingLabel != null) {
      // Editing existing label
      final label = widget.existingLabel!;
      _addressController.text = label.address;
      _labelNameController.text = label.labelName;
      _descriptionController.text = label.description ?? '';
      _selectedCategory = label.category;
      _selectedType = label.type;
      _isOwned = label.isOwned;
      _selectedColor = label.color;
    } else if (widget.prefilledAddress != null) {
      // Creating new label with prefilled address
      _addressController.text = widget.prefilledAddress!;
    }
    
    // Update type when category changes
    _updateTypeForCategory();
  }

  @override
  void dispose() {
    _addressController.dispose();
    _labelNameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _updateTypeForCategory() {
    final typesForCategory = AddressLabelManager.getLabelTypesForCategory(_selectedCategory);
    if (typesForCategory.isNotEmpty && !typesForCategory.contains(_selectedType)) {
      setState(() {
        _selectedType = typesForCategory.first;
        _selectedColor = AddressLabelManager.getColor(_selectedType);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existingLabel != null ? 'Edit Address Label' : 'Add Address Label'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Address field
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Address',
                  hintText: 'Enter BitcoinZ address',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an address';
                  }
                  if (value.length < 20) {
                    return 'Please enter a valid address';
                  }
                  return null;
                },
                maxLines: 2,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
              
              const SizedBox(height: 16),
              
              // Label name field
              TextFormField(
                controller: _labelNameController,
                decoration: const InputDecoration(
                  labelText: 'Label Name',
                  hintText: 'Enter a descriptive name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a label name';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 16),
              
              // Category dropdown
              DropdownButtonFormField<AddressLabelCategory>(
                value: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                items: AddressLabelCategory.values.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(AddressLabelManager.getCategoryDisplayName(category)),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedCategory = value;
                    });
                    _updateTypeForCategory();
                  }
                },
              ),
              
              const SizedBox(height: 16),
              
              // Type dropdown
              DropdownButtonFormField<AddressLabelType>(
                value: _selectedType,
                decoration: const InputDecoration(
                  labelText: 'Type',
                  border: OutlineInputBorder(),
                ),
                items: AddressLabelManager.getLabelTypesForCategory(_selectedCategory)
                    .map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Row(
                      children: [
                        Icon(
                          AddressLabelManager.getIcon(type),
                          size: 16,
                          color: Color(int.parse(AddressLabelManager.getColor(type).replaceFirst('#', '0xFF'))),
                        ),
                        const SizedBox(width: 8),
                        Text(AddressLabelManager.getDisplayName(type)),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedType = value;
                      _selectedColor = AddressLabelManager.getColor(value);
                    });
                  }
                },
              ),
              
              const SizedBox(height: 16),
              
              // Address ownership toggle
              SwitchListTile(
                title: const Text('Own Address'),
                subtitle: Text(_isOwned 
                    ? 'This is one of your addresses' 
                    : 'This is an external address'),
                value: _isOwned,
                onChanged: (value) {
                  setState(() {
                    _isOwned = value;
                  });
                },
              ),
              
              const SizedBox(height: 16),
              
              // Color picker
              Text(
                'Color',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  '#4CAF50', '#F44336', '#2196F3', '#FF9800', '#9C27B0',
                  '#00BCD4', '#FF5722', '#607D8B', '#795548', '#9E9E9E',
                ].map((color) {
                  final isSelected = _selectedColor == color;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedColor = color;
                      });
                    },
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Color(int.parse(color.replaceFirst('#', '0xFF'))),
                        shape: BoxShape.circle,
                        border: isSelected 
                            ? Border.all(color: Theme.of(context).colorScheme.primary, width: 3)
                            : null,
                      ),
                      child: isSelected 
                          ? const Icon(Icons.check, color: Colors.white, size: 16)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              
              const SizedBox(height: 16),
              
              // Description field
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (Optional)',
                  hintText: 'Add additional notes',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        if (widget.existingLabel != null)
          TextButton(
            onPressed: _isLoading ? null : _deleteLabel,
            child: Text(
              'Delete',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveLabel,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(widget.existingLabel != null ? 'Update' : 'Add'),
        ),
      ],
    );
  }

  Future<void> _saveLabel() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final walletProvider = Provider.of<WalletProvider>(context, listen: false);
      
      final label = AddressLabelManager.createLabel(
        address: _addressController.text.trim(),
        labelName: _labelNameController.text.trim(),
        type: _selectedType,
        isOwned: _isOwned,
        description: _descriptionController.text.trim().isEmpty 
            ? null 
            : _descriptionController.text.trim(),
        customColor: _selectedColor,
      );

      if (widget.existingLabel != null) {
        // Update existing label
        final updatedLabel = label.copyWith(id: widget.existingLabel!.id);
        await walletProvider.updateAddressLabel(updatedLabel);
      } else {
        // Create new label
        await walletProvider.addAddressLabel(label);
      }

      if (mounted) {
        Navigator.of(context).pop(true); // Return true to indicate success
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.existingLabel != null 
                ? 'Address label updated successfully' 
                : 'Address label added successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteLabel() async {
    if (widget.existingLabel == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Address Label'),
        content: Text('Are you sure you want to delete "${widget.existingLabel!.labelName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final walletProvider = Provider.of<WalletProvider>(context, listen: false);
      await walletProvider.deleteAddressLabel(widget.existingLabel!);

      if (mounted) {
        Navigator.of(context).pop(true); // Return true to indicate success
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Address label deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting label: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
