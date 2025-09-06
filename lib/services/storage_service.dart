import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

/// Storage service with fallback mechanism
/// Tries flutter_secure_storage first, falls back to shared_preferences for development
class StorageService {
  static const _secureStorage = FlutterSecureStorage();
  static SharedPreferences? _prefs;
  static bool _useSecureStorage = true;

  /// Initialize storage service
  static Future<void> initialize() async {
    try {
      // Try to write a test value to secure storage
      await _secureStorage.write(key: '_test_key', value: 'test');
      await _secureStorage.delete(key: '_test_key');
      _useSecureStorage = true;
      if (kDebugMode) print('💾 StorageService: Using flutter_secure_storage');
    } catch (e) {
      if (kDebugMode) {
        print('⚠️  StorageService: flutter_secure_storage failed ($e), falling back to SharedPreferences');
      }
      _useSecureStorage = false;
      _prefs = await SharedPreferences.getInstance();
    }
  }

  /// Write a key-value pair to storage
  static Future<void> write({required String key, required String value}) async {
    if (_useSecureStorage) {
      try {
        await _secureStorage.write(key: key, value: value);
        // Debug logging removed for performance
        return;
      } catch (e) {
        if (kDebugMode) {
          print('❌ StorageService: Secure storage write failed for $key: $e');
          print('   Falling back to SharedPreferences');
        }
        _useSecureStorage = false;
        _prefs ??= await SharedPreferences.getInstance();
      }
    }

    // Fallback to SharedPreferences
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setString(key, value);
    // Debug logging removed for performance
  }

  /// Read a value from storage
  static Future<String?> read({required String key}) async {
    if (_useSecureStorage) {
      try {
        final value = await _secureStorage.read(key: key);
        // Debug logging removed for performance
        return value;
      } catch (e) {
        if (kDebugMode) {
          print('❌ StorageService: Secure storage read failed for $key: $e');
          print('   Falling back to SharedPreferences');
        }
        _useSecureStorage = false;
        _prefs ??= await SharedPreferences.getInstance();
      }
    }

    // Fallback to SharedPreferences
    _prefs ??= await SharedPreferences.getInstance();
    final value = _prefs!.getString(key);
    // Debug logging removed for performance
    return value;
  }

  /// Delete a key from storage
  static Future<void> delete({required String key}) async {
    if (_useSecureStorage) {
      try {
        await _secureStorage.delete(key: key);
        if (kDebugMode) print('🗑️  StorageService.delete(secure): $key');
        return;
      } catch (e) {
        if (kDebugMode) {
          print('❌ StorageService: Secure storage delete failed for $key: $e');
          print('   Falling back to SharedPreferences');
        }
        _useSecureStorage = false;
        _prefs ??= await SharedPreferences.getInstance();
      }
    }

    // Fallback to SharedPreferences
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.remove(key);
    if (kDebugMode) print('🗑️  StorageService.delete(prefs): $key');
  }

  /// Delete all stored data
  static Future<void> deleteAll() async {
    if (_useSecureStorage) {
      try {
        await _secureStorage.deleteAll();
        if (kDebugMode) print('🗑️  StorageService.deleteAll(secure): all keys deleted');
        return;
      } catch (e) {
        if (kDebugMode) {
          print('❌ StorageService: Secure storage deleteAll failed: $e');
          print('   Falling back to SharedPreferences');
        }
        _useSecureStorage = false;
        _prefs ??= await SharedPreferences.getInstance();
      }
    }

    // Fallback to SharedPreferences
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.clear();
    if (kDebugMode) print('🗑️  StorageService.deleteAll(prefs): all keys deleted');
  }

  /// Check if using secure storage
  static bool get isUsingSecureStorage => _useSecureStorage;

  /// Get storage type for debugging
  static String get storageType => _useSecureStorage ? 'flutter_secure_storage' : 'shared_preferences';
}