import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:local_auth/local_auth.dart';
import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../services/storage_service.dart';
import '../services/wallet_storage_service.dart';
// import '../services/cli_wallet_detector.dart'; // Removed - CLI no longer used

class AuthProvider with ChangeNotifier {
  static const String _hasWalletKey = 'has_wallet';
  static const String _walletIdKey = 'wallet_id';
  static const String _biometricsEnabledKey = 'biometrics_enabled';
  static const String _pinHashKey = 'pin_hash';
  static const String _seedPhraseKey = 'seed_phrase_encrypted';
  static const String _walletDataKey = 'wallet_data';
  static const String _cliWalletImportedKey = 'cli_wallet_imported';

  bool _isAuthenticated = false;
  bool _hasWallet = false;
  String? _walletId;
  bool _biometricsEnabled = false;
  bool _isLoading = false;
  String? _error;
  bool _cliWalletImported = false;
  bool _hasLegacyWallet = false;
  final LocalAuthentication _localAuth = LocalAuthentication();
  // final CliWalletDetector _cliDetector = CliWalletDetector(); // Removed - CLI no longer used

  // Caching for log reduction
  DateTime? _lastDataLoad;
  String? _lastLoadedDataHash;
  static const Duration _cacheTimeout = Duration(seconds: 30);

  // Getters
  bool get isAuthenticated => _isAuthenticated;
  bool get hasWallet => _hasWallet;
  String? get walletId => _walletId;
  bool get biometricsEnabled => _biometricsEnabled;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get cliWalletImported => _cliWalletImported;
  bool get hasLegacyWallet => _hasLegacyWallet;

  /// Initialize auth provider with mobile-first approach
  Future<void> initialize() async {
    // Use post-frame callback to avoid setState during build
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _setLoading(true);
    });
    
    try {
      await _loadStoredData();
      
      // Check for legacy BitcoinZ Blue wallet on macOS
      if (Platform.isMacOS && !_hasWallet) {
        final hasLegacy = await WalletStorageService.hasLegacyWallet();
        if (hasLegacy) {
          if (kDebugMode) {
            print('🔄 Found legacy BitcoinZ Blue wallet data');
          }
          _hasLegacyWallet = true;
          notifyListeners();
        }
      }
      
      // Check if biometrics are available on supported platforms
      if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
        final isAvailable = await isBiometricsAvailable();
        if (!isAvailable && _biometricsEnabled) {
          // Disable biometrics if not available
          await setBiometricsEnabled(false);
        }
      }
    } catch (e) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _setError('Failed to initialize authentication: $e');
      });
    } finally {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _setLoading(false);
      });
    }
  }

  /// Register new wallet with mobile-optimized flow
  Future<bool> registerWallet(String walletId, {String? seedPhrase, Map<String, dynamic>? walletData}) async {
    _setLoading(true);
    _clearError();

    try {
      if (kDebugMode) {
        print('💾 AuthProvider.registerWallet() - Starting storage writes...');
        print('  Keys to write: $_hasWalletKey, $_walletIdKey');
      }
      
      try {
        await StorageService.write(key: _hasWalletKey, value: 'true');
        if (kDebugMode) print('  ✅ $_hasWalletKey = "true" written');
      } catch (e) {
        if (kDebugMode) print('  ❌ Failed to write $_hasWalletKey: $e');
        throw e;
      }
      
      try {
        await StorageService.write(key: _walletIdKey, value: walletId);
        if (kDebugMode) print('  ✅ $_walletIdKey = "$walletId" written');
      } catch (e) {
        if (kDebugMode) print('  ❌ Failed to write $_walletIdKey: $e');
        throw e;
      }
      
      // Store encrypted seed phrase if provided
      if (seedPhrase != null) {
        try {
          await StorageService.write(key: _seedPhraseKey, value: seedPhrase);
          if (kDebugMode) print('  ✅ $_seedPhraseKey written (${seedPhrase.length} chars)');
        } catch (e) {
          if (kDebugMode) print('  ❌ Failed to write $_seedPhraseKey: $e');
          throw e;
        }
      }
      
      // Store wallet data if provided
      if (walletData != null) {
        try {
          await StorageService.write(key: _walletDataKey, value: jsonEncode(walletData));
          if (kDebugMode) print('  ✅ $_walletDataKey written');
        } catch (e) {
          if (kDebugMode) print('  ❌ Failed to write $_walletDataKey: $e');
          throw e;
        }
      }
      
      // Verify writes by reading back
      try {
        final testRead = await StorageService.read(key: _hasWalletKey);
        if (kDebugMode) {
          print('🔍 Verification read: $_hasWalletKey = "$testRead"');
          print('🔧 Using storage type: ${StorageService.storageType}');
        }
      } catch (e) {
        if (kDebugMode) print('  ❌ Failed to verify read $_hasWalletKey: $e');
      }
      
      _hasWallet = true;
      _walletId = walletId;
      _isAuthenticated = false; // Still need to authenticate
      
      // Debug logging
      if (kDebugMode) {
        print('✅ AuthProvider.registerWallet() completed successfully');
        print('  Final state: _hasWallet = $_hasWallet');
      }
      
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to register wallet: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Mobile-first authentication with biometrics support
  Future<bool> authenticate({String? pin}) async {
    if (!_hasWallet) {
      _setError('No wallet found');
      return false;
    }

    _setLoading(true);
    _clearError();

    try {
      bool authenticated = false;

      // Try biometric authentication first on supported platforms
      if (_biometricsEnabled && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS)) {
        authenticated = await _authenticateWithBiometrics();
      }
      
      // Fall back to PIN authentication if biometrics failed or not enabled
      if (!authenticated && pin != null) {
        authenticated = await _authenticateWithPin(pin);
      }
      
      // For unsupported desktop platforms, use simple authentication
      if (!authenticated && !Platform.isAndroid && !Platform.isIOS && !Platform.isMacOS) {
        authenticated = true; // Simplified for unsupported platforms
      }

      _isAuthenticated = authenticated;
      notifyListeners();
      return authenticated;
    } catch (e) {
      _setError('Authentication failed: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Set PIN for authentication with secure hashing
  Future<bool> setPin(String pin) async {
    try {
      // Use SHA-256 for secure PIN hashing
      // In production, consider using a salt and PBKDF2 or bcrypt
      final bytes = utf8.encode(pin);
      final digest = sha256.convert(bytes);
      final pinHash = digest.toString();
      
      await StorageService.write(key: _pinHashKey, value: pinHash);
      return true;
    } catch (e) {
      _setError('Failed to set PIN: $e');
      return false;
    }
  }

  /// Authenticate with PIN
  Future<bool> _authenticateWithPin(String pin) async {
    try {
      final storedPinHash = await StorageService.read(key: _pinHashKey);
      if (storedPinHash == null) {
        // No PIN set yet - user needs to set up a PIN
        return false;
      }
      
      // Hash the provided PIN and compare
      final bytes = utf8.encode(pin);
      final digest = sha256.convert(bytes);
      final pinHash = digest.toString();
      
      return pinHash == storedPinHash;
    } catch (e) {
      return false;
    }
  }

  /// Authenticate with biometrics
  Future<bool> _authenticateWithBiometrics() async {
    try {
      if (kDebugMode) {
        print('🔒 Starting biometric authentication...');
      }
      
      // Check if biometric authentication is available
      final isAvailable = await _localAuth.canCheckBiometrics;
      if (kDebugMode) {
        print('📱 Biometric availability: $isAvailable');
      }
      
      if (!isAvailable) {
        if (kDebugMode) {
          print('❌ Biometric authentication not available');
        }
        return false;
      }
      
      // Get available biometric types
      final availableBiometrics = await _localAuth.getAvailableBiometrics();
      if (kDebugMode) {
        print('🔍 Available biometrics: $availableBiometrics');
      }
      
      if (availableBiometrics.isEmpty) {
        if (kDebugMode) {
          print('❌ No biometric types available');
        }
        return false;
      }
      
      // Attempt biometric authentication with proper settings for fingerprint/face dialog
      final result = await _localAuth.authenticate(
        localizedReason: 'Authenticate to access your BitcoinZ wallet',
        options: const AuthenticationOptions(
          biometricOnly: true,  // Show only biometric dialog (fingerprint/face)
          stickyAuth: true,     // Keep authentication dialog sticky
          sensitiveTransaction: false, // Standard security level
        ),
      );
      
      if (kDebugMode) {
        print('🔐 Biometric authentication result: $result');
      }
      
      return result;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Biometric authentication error: $e');
      }
      return false;
    }
  }

  /// Logout user
  Future<void> logout() async {
    _isAuthenticated = false;
    _clearError();
    notifyListeners();
  }

  /// Reset wallet (clear all stored data)
  Future<void> resetWallet() async {
    _setLoading(true);
    
    try {
      await StorageService.deleteAll();
      
      _hasWallet = false;
      _walletId = null;
      _isAuthenticated = false;
      _biometricsEnabled = false;
      _clearError();
      
      notifyListeners();
    } catch (e) {
      _setError('Failed to reset wallet: $e');
    } finally {
      _setLoading(false);
    }
  }
  
  /// Force clear wallet data for debugging
  Future<void> forceResetForDebugging() async {
    if (kDebugMode) {
      // Force reset initiated for debugging
      await resetWallet();
      print('✅ All wallet data cleared. App will restart with fresh wallet creation.');
    }
  }
  
  /// Force clear wallet data immediately for testing address generation
  Future<void> forceCompleteReset() async {
    try {
      // Clear all known storage keys
      await StorageService.write(key: _hasWalletKey, value: 'false');
      await StorageService.write(key: _walletIdKey, value: '');
      await StorageService.write(key: _seedPhraseKey, value: '');
      await StorageService.write(key: _walletDataKey, value: '');
      await StorageService.write(key: _pinHashKey, value: '');
      await StorageService.write(key: _biometricsEnabledKey, value: 'false');
      
      _hasWallet = false;
      _walletId = null;
      _isAuthenticated = false;
      _biometricsEnabled = false;
      _clearError();
      
      if (kDebugMode) {
        print('🧹 Complete reset performed - all storage cleared');
        print('🔄 App should now show onboarding flow');
      }
      
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error during complete reset: $e');
      }
    }
  }

  /// Enable/disable biometrics
  Future<void> setBiometricsEnabled(bool enabled) async {
    try {
      if (enabled && !(await isBiometricsAvailable())) {
        _setError('Biometrics not available on this device');
        return;
      }

      await StorageService.write(key: _biometricsEnabledKey, value: enabled.toString());
      _biometricsEnabled = enabled;
      notifyListeners();
    } catch (e) {
      _setError('Failed to update biometrics setting: $e');
    }
  }

  /// Check if biometrics are available (cross-platform optimized)
  Future<bool> isBiometricsAvailable() async {
    try {
      // Support for mobile and desktop platforms
      if (!Platform.isAndroid && !Platform.isIOS && !Platform.isMacOS) {
        if (kDebugMode) {
          print('🔒 Biometrics: Platform ${Platform.operatingSystem} not supported');
        }
        return false;
      }
      
      final isAvailable = await _localAuth.canCheckBiometrics;
      // Biometric capability logging reduced to minimize log spam
      
      if (!isAvailable) return false;

      final availableBiometrics = await _localAuth.getAvailableBiometrics();
      // Platform biometric type logging reduced to minimize log spam
      if (kDebugMode && Platform.isMacOS) {
        print('🔒 macOS: Supports TouchID');
      }
      
      return availableBiometrics.isNotEmpty;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Biometrics availability check failed: $e');
      }
      return false;
    }
  }

  /// Get available biometric types
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      if (!Platform.isAndroid && !Platform.isIOS && !Platform.isMacOS) return [];
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      return [];
    }
  }

  /// Detect and import existing CLI wallet
  // Disabled - CLI detection no longer used
  /*
  Future<void> _detectAndImportCliWallet() async {
    try {
      if (kDebugMode) {
        print('🔍 AuthProvider: Checking for existing CLI wallet...');
      }
      
      final walletInfo = await _cliDetector.detectExistingWallet();
      
      if (walletInfo != null && walletInfo.isFound && walletInfo.isAccessible) {
        if (kDebugMode) {
          print('✅ CLI wallet detected! Auto-importing...');
          print('   Wallet path: ${walletInfo.walletPath}');
        }
        
        // Extract wallet summary
        final summary = _cliDetector.extractWalletSummary(walletInfo);
        if (summary != null && kDebugMode) {
          print('   Balance: ${summary.totalBalance} BTCZ');
          print('   Addresses: ${summary.addressCount}');
        }
        
        // Mark wallet as imported
        await StorageService.write(key: _hasWalletKey, value: 'true');
        await StorageService.write(key: _walletIdKey, value: 'cli_imported_${DateTime.now().millisecondsSinceEpoch}');
        await StorageService.write(key: _cliWalletImportedKey, value: 'true');
        
        // Store wallet info for later use
        if (walletInfo.balanceData != null) {
          await StorageService.write(key: _walletDataKey, value: jsonEncode({
            'source': 'cli_import',
            'imported_at': DateTime.now().toIso8601String(),
            'wallet_path': walletInfo.walletPath,
            'summary': summary != null ? {
              'total_balance': summary.totalBalance,
              'address_count': summary.addressCount,
              'has_transactions': summary.hasTransactions,
              'last_sync_status': summary.lastSyncStatus,
            } : null,
          }));
        }
        
        _hasWallet = true;
        _walletId = 'cli_imported_${DateTime.now().millisecondsSinceEpoch}';
        _cliWalletImported = true;
        
        if (kDebugMode) {
          print('✅ CLI wallet successfully imported to Flutter app state');
        }
        
      } else if (walletInfo != null) {
        if (kDebugMode) {
          print('⚠️ CLI wallet check completed but no accessible wallet found');
          if (walletInfo.error != null) {
            print('   Error: ${walletInfo.error}');
          }
        }
      }
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error detecting CLI wallet: $e');
      }
      // Don't fail initialization if CLI detection fails
    }
  }
  */

  /// Load stored authentication data
  Future<void> _loadStoredData() async {
    // Check if we have recent cached data
    final now = DateTime.now();
    if (_lastDataLoad != null && 
        now.difference(_lastDataLoad!).compareTo(_cacheTimeout) < 0) {
      // Data is still fresh, skip logging unless in debug mode
      return;
    }

    try {
      final shouldLog = _lastDataLoad == null || 
                       (kDebugMode && now.difference(_lastDataLoad!).inMinutes >= 1);
      
      if (shouldLog) {
        if (kDebugMode) {
          print('🔍 AuthProvider._loadStoredData() - Starting storage reads...');
          print('  Keys to read: $_hasWalletKey, $_walletIdKey, $_biometricsEnabledKey, $_cliWalletImportedKey');
        }
      }
      
      final hasWalletStr = await StorageService.read(key: _hasWalletKey);
      final walletId = await StorageService.read(key: _walletIdKey);
      final biometricsStr = await StorageService.read(key: _biometricsEnabledKey);
      final cliImportedStr = await StorageService.read(key: _cliWalletImportedKey);
      
      // Create hash of current data to detect changes
      final currentDataHash = '${hasWalletStr}_${walletId}_${biometricsStr}_${cliImportedStr}';
      final dataChanged = _lastLoadedDataHash != currentDataHash;
      
      if (shouldLog && dataChanged) {
        if (kDebugMode) {
          print('  Read $_hasWalletKey: "$hasWalletStr"');
          print('  Read $_walletIdKey: "$walletId"');
          print('  Read $_biometricsEnabledKey: "$biometricsStr"');
          print('  Read $_cliWalletImportedKey: "$cliImportedStr"');
        }
      }

      _hasWallet = hasWalletStr == 'true';
      _walletId = walletId;
      _biometricsEnabled = biometricsStr == 'true';
      _cliWalletImported = cliImportedStr == 'true';
      
      // Don't auto-authenticate for security
      _isAuthenticated = false;
      
      // Update cache
      _lastDataLoad = now;
      _lastLoadedDataHash = currentDataHash;
      
      // Debug logging only for changes or first load
      if ((shouldLog && dataChanged) || _lastDataLoad == null) {
        if (kDebugMode) {
          print('✅ AuthProvider._loadStoredData() completed:');
          print('  _hasWallet: $_hasWallet (from "$hasWalletStr")');
          print('  _walletId: $_walletId');
          print('  needsSetup: $needsSetup');
          print('  needsAuthentication: $needsAuthentication');
        }
      }
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ AuthProvider._loadStoredData() failed: $e');
      }
      // Set defaults on error
      _hasWallet = false;
      _walletId = null;
      _biometricsEnabled = false;
      _isAuthenticated = false;
    }
    
    notifyListeners();
  }

  /// Set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// Set error message
  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  /// Clear error message
  void _clearError() {
    _error = null;
    notifyListeners();
  }

  /// Check if app needs initial setup
  bool get needsSetup => !_hasWallet;

  /// Check if user needs to authenticate
  bool get needsAuthentication => _hasWallet && !_isAuthenticated;

  /// Check if PIN is set
  Future<bool> get hasPinSet async {
    final pinHash = await StorageService.read(key: _pinHashKey);
    return pinHash != null && pinHash.isNotEmpty;
  }
  
  /// Get stored seed phrase (requires authentication)
  Future<String?> getStoredSeedPhrase() async {
    if (!_isAuthenticated) return null;
    return await StorageService.read(key: _seedPhraseKey);
  }
  
  /// Get seed phrase synchronously (for initialization)
  String? getSeedPhrase() {
    // This is a temporary method to get the seed phrase during initialization
    // In production, this should be handled more securely
    return null; // Will be loaded asynchronously
  }
  
  /// Get stored wallet data
  /// Note: This data does not contain the seed phrase and is safe to read pre-auth for faster startup
  Future<Map<String, dynamic>?> getStoredWalletData() async {
    final dataString = await StorageService.read(key: _walletDataKey);
    if (dataString != null) {
      try {
        return jsonDecode(dataString) as Map<String, dynamic>;
      } catch (e) {
        return null;
      }
    }
    return null;
  }
  
  /// Update stored wallet data
  Future<void> updateWalletData(Map<String, dynamic> walletData) async {
    await StorageService.write(key: _walletDataKey, value: jsonEncode(walletData));
  }
  
  /// Migrate legacy BitcoinZ Blue wallet to Black Amber
  Future<bool> migrateLegacyWallet() async {
    if (!Platform.isMacOS || !_hasLegacyWallet) {
      return false;
    }
    
    _setLoading(true);
    _clearError();
    
    try {
      if (kDebugMode) {
        print('🔄 Starting migration from BitcoinZ Blue to Black Amber...');
      }
      
      // Perform the migration
      final success = await WalletStorageService.migrateLegacyWallet();
      
      if (success) {
        // Mark as having a wallet now
        _hasWallet = true;
        _hasLegacyWallet = false;
        
        // Save wallet state
        await StorageService.write(key: _hasWalletKey, value: 'true');
        await StorageService.write(key: _walletIdKey, value: 'migrated_from_blue');
        await StorageService.write(key: _walletDataKey, value: jsonEncode({
          'migrated': true,
          'migrated_at': DateTime.now().toIso8601String(),
          'source': 'BitcoinZ Blue',
        }));
        
        if (kDebugMode) {
          print('✅ Successfully migrated wallet to BitcoinZ Black Amber');
        }
        
        notifyListeners();
        return true;
      } else {
        _setError('Failed to migrate wallet data');
        return false;
      }
    } catch (e) {
      _setError('Migration failed: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }
}