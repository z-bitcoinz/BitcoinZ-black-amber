import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import '../models/contact_model.dart';
import 'database_service.dart';
import 'storage_service.dart';

class ContactService {
  static ContactService? _instance;
  static ContactService get instance {
    _instance ??= ContactService._internal();
    return _instance!;
  }

  ContactService._internal();

  final DatabaseService _databaseService = DatabaseService.instance;

  // CRUD operations
  Future<void> addContact(ContactModel contact) async {
    await _databaseService.insertContact(contact);
  }

  Future<List<ContactModel>> getAllContacts({
    bool? isFavorite,
    String? searchQuery,
  }) async {
    return await _databaseService.getContacts(
      isFavorite: isFavorite,
      searchQuery: searchQuery,
    );
  }

  Future<ContactModel?> getContactByAddress(String address) async {
    return await _databaseService.getContactByAddress(address);
  }

  Future<void> updateContact(ContactModel contact) async {
    await _databaseService.updateContact(contact);
  }

  Future<void> deleteContact(int contactId) async {
    await _databaseService.deleteContact(contactId);
  }

  Future<int> getContactsCount() async {
    return await _databaseService.getContactsCount();
  }

  // Utility methods
  Future<ContactModel> createContact({
    required String name,
    required String address,
    String? description,
    String? pictureBase64,
    bool isFavorite = false,
  }) async {
    final type = _determineAddressType(address);
    final now = DateTime.now();
    
    final contact = ContactModel(
      name: name,
      address: address,
      type: type,
      description: description,
      pictureBase64: pictureBase64,
      isFavorite: isFavorite,
      createdAt: now,
      updatedAt: now,
    );
    
    await addContact(contact);
    return contact;
  }

  String _determineAddressType(String address) {
    if (address.startsWith('t1')) {
      return 'transparent';
    } else if (address.startsWith('zs')) {
      return 'shielded';
    }
    return 'transparent'; // Default to transparent
  }

  Future<bool> contactExists(String address) async {
    final contact = await getContactByAddress(address);
    return contact != null;
  }

  // Backup and restore functionality with encryption
  Future<String> exportContacts({required String password}) async {
    try {
      final contacts = await getAllContacts();
      
      // Convert contacts to JSON
      final contactsJson = contacts.map((contact) => contact.toJson()).toList();
      final contactsString = jsonEncode({
        'version': 1,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'contacts': contactsJson,
      });
      
      // Encrypt the contacts data
      final encrypted = await _encryptData(contactsString, password);
      
      // Return base64 encoded encrypted data
      return base64Encode(encrypted);
    } catch (e) {
      if (kDebugMode) print('❌ ContactService: Export failed: $e');
      rethrow;
    }
  }

  Future<List<ContactModel>> importContacts({
    required String encryptedData,
    required String password,
  }) async {
    try {
      // Decode base64 data
      final encrypted = base64Decode(encryptedData);
      
      // Decrypt the data
      final decryptedString = await _decryptData(encrypted, password);
      
      // Parse JSON
      final data = jsonDecode(decryptedString) as Map<String, dynamic>;
      final version = data['version'] as int;
      
      if (version != 1) {
        throw Exception('Unsupported backup version: $version');
      }
      
      final contactsJson = data['contacts'] as List<dynamic>;
      final contacts = contactsJson
          .map((json) => ContactModel.fromJson(json as Map<String, dynamic>))
          .toList();
      
      // Import contacts (replacing existing ones with same address)
      for (final contact in contacts) {
        final newContact = contact.copyWith(
          id: null, // Reset ID for new insertion
          updatedAt: DateTime.now(),
        );
        await addContact(newContact);
      }
      
      return contacts;
    } catch (e) {
      if (kDebugMode) print('❌ ContactService: Import failed: $e');
      rethrow;
    }
  }

  // Auto-backup to secure storage
  Future<void> autoBackupContacts({required String password}) async {
    try {
      final encryptedBackup = await exportContacts(password: password);
      await StorageService.write(
        key: 'contacts_backup',
        value: encryptedBackup,
      );
      
      // Store backup timestamp
      await StorageService.write(
        key: 'contacts_backup_timestamp',
        value: DateTime.now().millisecondsSinceEpoch.toString(),
      );
      
      if (kDebugMode) print('✅ ContactService: Auto-backup completed');
    } catch (e) {
      if (kDebugMode) print('❌ ContactService: Auto-backup failed: $e');
    }
  }

  Future<bool> restoreFromAutoBackup({required String password}) async {
    try {
      final encryptedBackup = await StorageService.read(key: 'contacts_backup');
      if (encryptedBackup == null) {
        return false; // No backup found
      }
      
      await importContacts(
        encryptedData: encryptedBackup,
        password: password,
      );
      
      if (kDebugMode) print('✅ ContactService: Restored from auto-backup');
      return true;
    } catch (e) {
      if (kDebugMode) print('❌ ContactService: Auto-restore failed: $e');
      return false;
    }
  }

  Future<DateTime?> getLastBackupTime() async {
    final timestampStr = await StorageService.read(key: 'contacts_backup_timestamp');
    if (timestampStr == null) return null;
    
    final timestamp = int.tryParse(timestampStr);
    if (timestamp == null) return null;
    
    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }

  // Encryption helpers
  Future<Uint8List> _encryptData(String data, String password) async {
    // Simple XOR encryption with password hash (for demo purposes)
    // In production, use proper encryption like AES
    final passwordBytes = utf8.encode(password);
    final passwordHash = sha256.convert(passwordBytes).bytes;
    final dataBytes = utf8.encode(data);
    
    final encrypted = Uint8List(dataBytes.length);
    for (int i = 0; i < dataBytes.length; i++) {
      encrypted[i] = dataBytes[i] ^ passwordHash[i % passwordHash.length];
    }
    
    return encrypted;
  }

  Future<String> _decryptData(Uint8List encrypted, String password) async {
    // Simple XOR decryption with password hash
    final passwordBytes = utf8.encode(password);
    final passwordHash = sha256.convert(passwordBytes).bytes;
    
    final decrypted = Uint8List(encrypted.length);
    for (int i = 0; i < encrypted.length; i++) {
      decrypted[i] = encrypted[i] ^ passwordHash[i % passwordHash.length];
    }
    
    return utf8.decode(decrypted);
  }

  // Address validation
  bool isValidBitcoinZAddress(String address) {
    if (address.isEmpty) return false;

    // Transparent addresses
    if (address.startsWith('t1') && address.length >= 34) {
      return true;
    }

    // Shielded addresses (zs only)
    if (address.startsWith('zs') && address.length >= 60) {
      return true;
    }

    return false;
  }

  // Search and filter
  Future<List<ContactModel>> searchContacts(String query) async {
    if (query.isEmpty) {
      return await getAllContacts();
    }
    
    return await getAllContacts(searchQuery: query);
  }

  Future<List<ContactModel>> getFavoriteContacts() async {
    return await getAllContacts(isFavorite: true);
  }

  // Contact management helpers
  Future<void> toggleFavorite(ContactModel contact) async {
    final updatedContact = contact.copyWith(
      isFavorite: !contact.isFavorite,
      updatedAt: DateTime.now(),
    );
    
    await updateContact(updatedContact);
  }

  Future<bool> isDuplicateAddress(String address, {int? excludeContactId}) async {
    final existing = await getContactByAddress(address);
    if (existing == null) return false;
    
    // If we're editing a contact, allow the same address for that contact
    if (excludeContactId != null && existing.id == excludeContactId) {
      return false;
    }
    
    return true;
  }
}