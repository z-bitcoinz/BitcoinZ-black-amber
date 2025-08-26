import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/contact_provider.dart';
import '../../models/contact_model.dart';
import '../wallet/qr_scanner_screen.dart';

class ContactFormScreen extends StatefulWidget {
  final ContactModel? contact; // null for add, provided for edit

  const ContactFormScreen({
    super.key,
    this.contact,
  });

  @override
  State<ContactFormScreen> createState() => _ContactFormScreenState();
}

class _ContactFormScreenState extends State<ContactFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  bool _isFavorite = false;
  bool _isLoading = false;
  String? _errorMessage;
  
  bool get _isEditing => widget.contact != null;

  @override
  void initState() {
    super.initState();
    
    if (_isEditing) {
      final contact = widget.contact!;
      _nameController.text = contact.name;
      _addressController.text = contact.address;
      _descriptionController.text = contact.description ?? '';
      _isFavorite = contact.isFavorite;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Name is required';
    }
    if (value.trim().length < 2) {
      return 'Name must be at least 2 characters';
    }
    return null;
  }

  String? _validateAddress(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Address is required';
    }
    
    final contactProvider = Provider.of<ContactProvider>(context, listen: false);
    if (!contactProvider.isValidAddress(value.trim())) {
      return 'Invalid BitcoinZ address';
    }
    
    return null;
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
          ),
        );
      }
    }
  }

  void _processQRCodeData(String qrData) {
    try {
      String address = qrData.trim();
      
      // Handle BitcoinZ URI format (bitcoinz:address)
      if (address.toLowerCase().startsWith('bitcoinz:')) {
        final uri = Uri.tryParse(address);
        if (uri != null) {
          address = uri.path;
          if (address.isEmpty && uri.host.isNotEmpty) {
            address = uri.host;
          }
        }
      }
      
      // Handle other URI formats
      if (address.contains(':') && !address.startsWith('t1') && !address.startsWith('zc') && !address.startsWith('zs')) {
        final uri = Uri.tryParse(address);
        if (uri != null && uri.scheme.isNotEmpty) {
          address = uri.path;
          if (address.isEmpty && uri.host.isNotEmpty) {
            address = uri.host;
          }
        }
      }
      
      _addressController.text = address;
      
      // Show success feedback
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Address scanned successfully'),
          backgroundColor: Color(0xFF4CAF50),
        ),
      );
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid QR code format'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _saveContact() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final contactProvider = Provider.of<ContactProvider>(context, listen: false);
      bool success = false;

      if (_isEditing) {
        // Update existing contact
        final updatedContact = widget.contact!.copyWith(
          name: _nameController.text.trim(),
          address: _addressController.text.trim(),
          description: _descriptionController.text.trim().isEmpty 
              ? null 
              : _descriptionController.text.trim(),
          isFavorite: _isFavorite,
        );
        success = await contactProvider.updateContact(updatedContact);
      } else {
        // Add new contact
        success = await contactProvider.addContact(
          name: _nameController.text.trim(),
          address: _addressController.text.trim(),
          description: _descriptionController.text.trim().isEmpty 
              ? null 
              : _descriptionController.text.trim(),
          isFavorite: _isFavorite,
        );
      }

      if (success && mounted) {
        Navigator.pop(context, true); // Return success
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing 
                  ? 'Contact updated successfully' 
                  : 'Contact added successfully'
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else if (mounted) {
        setState(() {
          _errorMessage = contactProvider.errorMessage ?? 'Failed to save contact';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Contact' : 'Add Contact'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _saveContact,
              child: Text(
                _isEditing ? 'Save' : 'Add',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Error message
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            // Name field
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Name *',
                hintText: 'e.g., John Doe',
                prefixIcon: const Icon(Icons.person),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: _validateName,
              textCapitalization: TextCapitalization.words,
              enabled: !_isLoading,
            ),
            
            const SizedBox(height: 16),
            
            // Address field
            TextFormField(
              controller: _addressController,
              decoration: InputDecoration(
                labelText: 'Address *',
                hintText: 't1... or zc...',
                prefixIcon: const Icon(Icons.account_balance_wallet),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.qr_code_scanner),
                  onPressed: _isLoading ? null : _scanQRCode,
                  tooltip: 'Scan QR Code',
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: _validateAddress,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
              enabled: !_isLoading,
            ),
            
            const SizedBox(height: 16),
            
            // Description field
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: 'Description (optional)',
                hintText: 'e.g., My friend, Business partner...',
                prefixIcon: const Icon(Icons.note),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              enabled: !_isLoading,
            ),
            
            const SizedBox(height: 24),
            
            // Favorite toggle
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
              child: SwitchListTile(
                title: const Text('Add to Favorites'),
                subtitle: const Text('Quick access to this contact'),
                value: _isFavorite,
                onChanged: _isLoading ? null : (value) {
                  setState(() {
                    _isFavorite = value;
                  });
                },
                secondary: Icon(
                  _isFavorite ? Icons.star : Icons.star_border,
                  color: _isFavorite ? Colors.amber : null,
                ),
                activeColor: Theme.of(context).colorScheme.primary,
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Save button
            SizedBox(
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _saveContact,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Icon(_isEditing ? Icons.save : Icons.person_add),
                label: Text(
                  _isLoading 
                      ? (_isEditing ? 'Saving...' : 'Adding...')
                      : (_isEditing ? 'Save Contact' : 'Add Contact'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Help text
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Supported Address Types',
                        style: TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '• Transparent addresses (t1...)\n'
                    '• Shielded addresses (zc... or zs...)\n'
                    '• Use QR scanner for quick address entry',
                    style: TextStyle(
                      color: Colors.blue,
                      fontSize: 12,
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