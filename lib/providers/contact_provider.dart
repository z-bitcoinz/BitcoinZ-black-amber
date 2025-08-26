import 'package:flutter/foundation.dart';
import '../models/contact_model.dart';
import '../services/contact_service.dart';

class ContactProvider extends ChangeNotifier {
  final ContactService _contactService = ContactService.instance;
  
  List<ContactModel> _contacts = [];
  List<ContactModel> _filteredContacts = [];
  String _searchQuery = '';
  bool _isLoading = false;
  String? _errorMessage;
  
  // Getters
  List<ContactModel> get contacts => _filteredContacts.isEmpty && _searchQuery.isEmpty 
      ? _contacts 
      : _filteredContacts;
  
  List<ContactModel> get allContacts => _contacts;
  List<ContactModel> get favoriteContacts => _contacts.where((c) => c.isFavorite).toList();
  
  String get searchQuery => _searchQuery;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get contactsCount => _contacts.length;
  bool get hasContacts => _contacts.isNotEmpty;
  
  // Initialize and load contacts
  Future<void> loadContacts() async {
    try {
      _setLoading(true);
      _clearError();
      
      _contacts = await _contactService.getAllContacts();
      _applySearch(); // Apply current search if any
      
      if (kDebugMode) print('✅ ContactProvider: Loaded ${_contacts.length} contacts');
    } catch (e) {
      _setError('Failed to load contacts: $e');
      if (kDebugMode) print('❌ ContactProvider: Load failed: $e');
    } finally {
      _setLoading(false);
    }
  }
  
  // Add contact
  Future<bool> addContact({
    required String name,
    required String address,
    String? description,
    String? pictureBase64,
    bool isFavorite = false,
  }) async {
    try {
      _clearError();
      
      // Validate address
      if (!_contactService.isValidBitcoinZAddress(address)) {
        _setError('Invalid BitcoinZ address');
        return false;
      }
      
      // Check for duplicates
      if (await _contactService.isDuplicateAddress(address)) {
        _setError('Contact with this address already exists');
        return false;
      }
      
      // Create and add contact
      await _contactService.createContact(
        name: name.trim(),
        address: address.trim(),
        description: description?.trim(),
        pictureBase64: pictureBase64,
        isFavorite: isFavorite,
      );
      
      // Reload contacts
      await loadContacts();
      
      if (kDebugMode) print('✅ ContactProvider: Added contact: $name');
      return true;
    } catch (e) {
      _setError('Failed to add contact: $e');
      if (kDebugMode) print('❌ ContactProvider: Add failed: $e');
      return false;
    }
  }
  
  // Update contact
  Future<bool> updateContact(ContactModel contact) async {
    try {
      _clearError();
      
      // Validate address
      if (!_contactService.isValidBitcoinZAddress(contact.address)) {
        _setError('Invalid BitcoinZ address');
        return false;
      }
      
      // Check for duplicates (excluding current contact)
      if (await _contactService.isDuplicateAddress(contact.address, excludeContactId: contact.id)) {
        _setError('Another contact with this address already exists');
        return false;
      }
      
      // Update contact
      final updatedContact = contact.copyWith(updatedAt: DateTime.now());
      await _contactService.updateContact(updatedContact);
      
      // Reload contacts
      await loadContacts();
      
      if (kDebugMode) print('✅ ContactProvider: Updated contact: ${contact.name}');
      return true;
    } catch (e) {
      _setError('Failed to update contact: $e');
      if (kDebugMode) print('❌ ContactProvider: Update failed: $e');
      return false;
    }
  }
  
  // Delete contact
  Future<bool> deleteContact(ContactModel contact) async {
    try {
      _clearError();
      
      if (contact.id == null) {
        _setError('Cannot delete contact without ID');
        return false;
      }
      
      await _contactService.deleteContact(contact.id!);
      
      // Reload contacts
      await loadContacts();
      
      if (kDebugMode) print('✅ ContactProvider: Deleted contact: ${contact.name}');
      return true;
    } catch (e) {
      _setError('Failed to delete contact: $e');
      if (kDebugMode) print('❌ ContactProvider: Delete failed: $e');
      return false;
    }
  }
  
  // Toggle favorite
  Future<bool> toggleFavorite(ContactModel contact) async {
    try {
      _clearError();
      
      await _contactService.toggleFavorite(contact);
      
      // Update local state immediately
      final index = _contacts.indexWhere((c) => c.id == contact.id);
      if (index != -1) {
        _contacts[index] = contact.copyWith(
          isFavorite: !contact.isFavorite,
          updatedAt: DateTime.now(),
        );
        _applySearch();
        notifyListeners();
      }
      
      if (kDebugMode) print('✅ ContactProvider: Toggled favorite: ${contact.name}');
      return true;
    } catch (e) {
      _setError('Failed to toggle favorite: $e');
      if (kDebugMode) print('❌ ContactProvider: Toggle favorite failed: $e');
      return false;
    }
  }
  
  // Search contacts
  void searchContacts(String query) {
    _searchQuery = query.trim();
    _applySearch();
    
    if (kDebugMode) print('🔍 ContactProvider: Search: "$_searchQuery" (${_filteredContacts.length} results)');
  }
  
  void _applySearch() {
    if (_searchQuery.isEmpty) {
      _filteredContacts = [];
    } else {
      final lowerQuery = _searchQuery.toLowerCase();
      _filteredContacts = _contacts.where((contact) {
        return contact.name.toLowerCase().contains(lowerQuery) ||
               contact.address.toLowerCase().contains(lowerQuery) ||
               (contact.description?.toLowerCase().contains(lowerQuery) ?? false);
      }).toList();
    }
    notifyListeners();
  }
  
  // Clear search
  void clearSearch() {
    _searchQuery = '';
    _filteredContacts = [];
    notifyListeners();
    
    if (kDebugMode) print('🔍 ContactProvider: Search cleared');
  }
  
  // Get contact by address
  ContactModel? getContactByAddress(String address) {
    try {
      return _contacts.firstWhere((contact) => contact.address == address);
    } catch (e) {
      return null;
    }
  }
  
  // Backup and restore
  Future<String?> exportContacts(String password) async {
    try {
      _setLoading(true);
      _clearError();
      
      final backupData = await _contactService.exportContacts(password: password);
      
      if (kDebugMode) print('✅ ContactProvider: Exported ${_contacts.length} contacts');
      return backupData;
    } catch (e) {
      _setError('Failed to export contacts: $e');
      if (kDebugMode) print('❌ ContactProvider: Export failed: $e');
      return null;
    } finally {
      _setLoading(false);
    }
  }
  
  Future<bool> importContacts(String backupData, String password) async {
    try {
      _setLoading(true);
      _clearError();
      
      final importedContacts = await _contactService.importContacts(
        encryptedData: backupData,
        password: password,
      );
      
      // Reload contacts after import
      await loadContacts();
      
      if (kDebugMode) print('✅ ContactProvider: Imported ${importedContacts.length} contacts');
      return true;
    } catch (e) {
      _setError('Failed to import contacts: $e');
      if (kDebugMode) print('❌ ContactProvider: Import failed: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  Future<DateTime?> getLastBackupTime() async {
    return await _contactService.getLastBackupTime();
  }
  
  // Validation helpers
  bool isValidAddress(String address) {
    return _contactService.isValidBitcoinZAddress(address);
  }
  
  Future<bool> isAddressAlreadyExists(String address, {int? excludeContactId}) async {
    return await _contactService.isDuplicateAddress(address, excludeContactId: excludeContactId);
  }
  
  // Private helper methods
  void _setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }
  
  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }
  
  void _clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }
  
  // Clear all data (useful for logout)
  void clearData() {
    _contacts.clear();
    _filteredContacts.clear();
    _searchQuery = '';
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
    
    if (kDebugMode) print('🧹 ContactProvider: Data cleared');
  }
}