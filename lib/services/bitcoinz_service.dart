import 'dart:ffi';
import 'dart:io';
import 'dart:convert';
import 'package:ffi/ffi.dart';
import 'package:logger/logger.dart';
import '../models/wallet_model.dart';
import '../models/balance_model.dart';
import '../models/transaction_model.dart';
import '../utils/constants.dart';

// C function signatures
typedef BitcoinZInitC = Pointer<Utf8> Function(Pointer<Utf8> serverUrl);
typedef BitcoinZInitDart = Pointer<Utf8> Function(Pointer<Utf8> serverUrl);

typedef BitcoinZCreateWalletC = Pointer<Utf8> Function(Pointer<Utf8> seedPhrase);
typedef BitcoinZCreateWalletDart = Pointer<Utf8> Function(Pointer<Utf8> seedPhrase);

typedef BitcoinZRestoreWalletC = Pointer<Utf8> Function(Pointer<Utf8> seedPhrase, Uint32 birthdayHeight);
typedef BitcoinZRestoreWalletDart = Pointer<Utf8> Function(Pointer<Utf8> seedPhrase, int birthdayHeight);

typedef BitcoinZGetBalanceC = Pointer<Utf8> Function();
typedef BitcoinZGetBalanceDart = Pointer<Utf8> Function();

typedef BitcoinZGetAddressesC = Pointer<Utf8> Function();
typedef BitcoinZGetAddressesDart = Pointer<Utf8> Function();

typedef BitcoinZNewAddressC = Pointer<Utf8> Function(Pointer<Utf8> addressType);
typedef BitcoinZNewAddressDart = Pointer<Utf8> Function(Pointer<Utf8> addressType);

typedef BitcoinZSyncC = Pointer<Utf8> Function();
typedef BitcoinZSyncDart = Pointer<Utf8> Function();

typedef BitcoinZSyncStatusC = Pointer<Utf8> Function();
typedef BitcoinZSyncStatusDart = Pointer<Utf8> Function();

typedef BitcoinZSendTransactionC = Pointer<Utf8> Function(Pointer<Utf8> toAddress, Uint64 amountZatoshis, Pointer<Utf8> memo);
typedef BitcoinZSendTransactionDart = Pointer<Utf8> Function(Pointer<Utf8> toAddress, int amountZatoshis, Pointer<Utf8> memo);

typedef BitcoinZGetTransactionsC = Pointer<Utf8> Function();
typedef BitcoinZGetTransactionsDart = Pointer<Utf8> Function();

typedef BitcoinZEncryptMessageC = Pointer<Utf8> Function(Pointer<Utf8> zAddress, Pointer<Utf8> message);
typedef BitcoinZEncryptMessageDart = Pointer<Utf8> Function(Pointer<Utf8> zAddress, Pointer<Utf8> message);

typedef BitcoinZDecryptMessageC = Pointer<Utf8> Function(Pointer<Utf8> encryptedData);
typedef BitcoinZDecryptMessageDart = Pointer<Utf8> Function(Pointer<Utf8> encryptedData);

typedef BitcoinZFreeStringC = Void Function(Pointer<Utf8> ptr);
typedef BitcoinZFreeStringDart = void Function(Pointer<Utf8> ptr);

typedef BitcoinZDestroyC = Pointer<Utf8> Function();
typedef BitcoinZDestroyDart = Pointer<Utf8> Function();

class BitcoinZService {
  static BitcoinZService? _instance;
  static final Logger _logger = Logger();
  
  late DynamicLibrary _lib;
  bool _initialized = false;
  
  // Function bindings
  late BitcoinZInitDart _init;
  late BitcoinZCreateWalletDart _createWallet;
  late BitcoinZRestoreWalletDart _restoreWallet;
  late BitcoinZGetBalanceDart _getBalance;
  late BitcoinZGetAddressesDart _getAddresses;
  late BitcoinZNewAddressDart _newAddress;
  late BitcoinZSyncDart _sync;
  late BitcoinZSyncStatusDart _syncStatus;
  late BitcoinZSendTransactionDart _sendTransaction;
  late BitcoinZGetTransactionsDart _getTransactions;
  late BitcoinZEncryptMessageDart _encryptMessage;
  late BitcoinZDecryptMessageDart _decryptMessage;
  late BitcoinZFreeStringDart _freeString;
  late BitcoinZDestroyDart _destroy;

  BitcoinZService._internal();

  static BitcoinZService get instance {
    _instance ??= BitcoinZService._internal();
    return _instance!;
  }

  /// Initialize the BitcoinZ service with mobile-first approach
  Future<void> initialize({String? serverUrl}) async {
    if (_initialized) {
      _logger.i('BitcoinZ service already initialized');
      return;
    }

    try {
      // Load the appropriate native library based on platform
      if (Platform.isAndroid) {
        _lib = DynamicLibrary.open('libbitcoinz_mobile.so');
      } else if (Platform.isIOS) {
        _lib = DynamicLibrary.process();
      } else if (Platform.isMacOS) {
        // Support for desktop development/testing
        try {
          // Use @rpath to find the library in app bundle
          _lib = DynamicLibrary.open('libbitcoinz_mobile.dylib');
        } catch (e) {
          try {
            // Try absolute path from app bundle
            _lib = DynamicLibrary.open('@executable_path/../Frameworks/libbitcoinz_mobile.dylib');
          } catch (e2) {
            try {
              // Fallback to relative path
              _lib = DynamicLibrary.open('./Frameworks/libbitcoinz_mobile.dylib');
            } catch (e3) {
              // Last resort
              _lib = DynamicLibrary.open('../../../Frameworks/libbitcoinz_mobile.dylib');
            }
          }
        }
      } else if (Platform.isWindows) {
        _lib = DynamicLibrary.open('bitcoinz_mobile.dll');
      } else if (Platform.isLinux) {
        _lib = DynamicLibrary.open('libbitcoinz_mobile.so');
      } else {
        throw UnsupportedError('Platform ${Platform.operatingSystem} is not supported');
      }

      // Bind all functions
      _bindFunctions();

      // Initialize the native wallet
      final serverPtr = (serverUrl ?? AppConstants.defaultLightwalletdServer).toNativeUtf8();
      final resultPtr = _init(serverPtr);
      
      final result = _parseResponse(resultPtr);
      calloc.free(serverPtr);
      
      if (!result['success']) {
        throw Exception('Failed to initialize wallet: ${result['error']}');
      }

      _initialized = true;
      _logger.i('BitcoinZ service initialized successfully');
    } catch (e) {
      _logger.e('Failed to initialize BitcoinZ service: $e');
      rethrow;
    }
  }

  void _bindFunctions() {
    _init = _lib.lookupFunction<BitcoinZInitC, BitcoinZInitDart>('bitcoinz_init');
    _createWallet = _lib.lookupFunction<BitcoinZCreateWalletC, BitcoinZCreateWalletDart>('bitcoinz_create_wallet');
    _restoreWallet = _lib.lookupFunction<BitcoinZRestoreWalletC, BitcoinZRestoreWalletDart>('bitcoinz_restore_wallet');
    _getBalance = _lib.lookupFunction<BitcoinZGetBalanceC, BitcoinZGetBalanceDart>('bitcoinz_get_balance');
    _getAddresses = _lib.lookupFunction<BitcoinZGetAddressesC, BitcoinZGetAddressesDart>('bitcoinz_get_addresses');
    _newAddress = _lib.lookupFunction<BitcoinZNewAddressC, BitcoinZNewAddressDart>('bitcoinz_new_address');
    _sync = _lib.lookupFunction<BitcoinZSyncC, BitcoinZSyncDart>('bitcoinz_sync');
    _syncStatus = _lib.lookupFunction<BitcoinZSyncStatusC, BitcoinZSyncStatusDart>('bitcoinz_sync_status');
    _sendTransaction = _lib.lookupFunction<BitcoinZSendTransactionC, BitcoinZSendTransactionDart>('bitcoinz_send_transaction');
    _getTransactions = _lib.lookupFunction<BitcoinZGetTransactionsC, BitcoinZGetTransactionsDart>('bitcoinz_get_transactions');
    _encryptMessage = _lib.lookupFunction<BitcoinZEncryptMessageC, BitcoinZEncryptMessageDart>('bitcoinz_encrypt_message');
    _decryptMessage = _lib.lookupFunction<BitcoinZDecryptMessageC, BitcoinZDecryptMessageDart>('bitcoinz_decrypt_message');
    _freeString = _lib.lookupFunction<BitcoinZFreeStringC, BitcoinZFreeStringDart>('bitcoinz_free_string');
    _destroy = _lib.lookupFunction<BitcoinZDestroyC, BitcoinZDestroyDart>('bitcoinz_destroy');
  }

  /// Create a new wallet with the given seed phrase
  Future<WalletModel> createWallet(String seedPhrase) async {
    _ensureInitialized();
    
    try {
      final seedPtr = seedPhrase.toNativeUtf8();
      final resultPtr = _createWallet(seedPtr);
      
      final result = _parseResponse(resultPtr);
      calloc.free(seedPtr);
      
      if (!result['success']) {
        throw Exception('Failed to create wallet: ${result['error']}');
      }

      final walletModel = WalletModel.fromJson(result['data']);
      
      // Debug logging to track addresses received from Rust FFI
      _logger.i('🔍 Flutter BitcoinZService.createWallet() - Received from Rust FFI:');
      _logger.i('  walletId: ${walletModel.walletId}');
      _logger.i('  transparent addresses: ${walletModel.transparentAddresses.length}');
      for (int i = 0; i < walletModel.transparentAddresses.length; i++) {
        final addr = walletModel.transparentAddresses[i];
        _logger.i('    [$i]: "$addr" (${addr.length} chars)');
      }
      _logger.i('  shielded addresses: ${walletModel.shieldedAddresses.length}');
      for (int i = 0; i < walletModel.shieldedAddresses.length; i++) {
        final addr = walletModel.shieldedAddresses[i];
        _logger.i('    [$i]: "$addr" (${addr.length} chars)');
      }
      
      return walletModel;
    } catch (e) {
      _logger.e('Error creating wallet: $e');
      rethrow;
    }
  }

  /// Restore wallet from seed phrase with birthday height
  Future<WalletModel> restoreWallet(String seedPhrase, {int birthdayHeight = 0}) async {
    _ensureInitialized();
    
    try {
      final seedPtr = seedPhrase.toNativeUtf8();
      final resultPtr = _restoreWallet(seedPtr, birthdayHeight);
      
      final result = _parseResponse(resultPtr);
      calloc.free(seedPtr);
      
      if (!result['success']) {
        throw Exception('Failed to restore wallet: ${result['error']}');
      }

      final walletModel = WalletModel.fromJson(result['data']);
      
      // Debug logging to track addresses received from Rust FFI  
      _logger.i('🔍 Flutter BitcoinZService.restoreWallet() - Received from Rust FFI:');
      _logger.i('  walletId: ${walletModel.walletId}');
      _logger.i('  transparent addresses: ${walletModel.transparentAddresses.length}');
      for (int i = 0; i < walletModel.transparentAddresses.length; i++) {
        final addr = walletModel.transparentAddresses[i];
        _logger.i('    [$i]: "$addr" (${addr.length} chars)');
      }
      _logger.i('  shielded addresses: ${walletModel.shieldedAddresses.length}');
      for (int i = 0; i < walletModel.shieldedAddresses.length; i++) {
        final addr = walletModel.shieldedAddresses[i];
        _logger.i('    [$i]: "$addr" (${addr.length} chars)');
      }
      
      return walletModel;
    } catch (e) {
      _logger.e('Error restoring wallet: $e');
      rethrow;
    }
  }

  /// Get wallet balance
  Future<BalanceModel> getBalance() async {
    // Return a default balance if not initialized
    // The actual balance will be provided by Rust service via callbacks
    if (!_initialized) {
      // Return empty balance when not initialized
      return BalanceModel(
        transparent: 0,
        shielded: 0,
        total: 0,
        unconfirmed: 0,
        unconfirmedTransparent: 0,
        unconfirmedShielded: 0,
      );
    }
    
    _ensureInitialized();
    
    try {
      final resultPtr = _getBalance();
      final result = _parseResponse(resultPtr);
      
      if (!result['success']) {
        throw Exception('Failed to get balance: ${result['error']}');
      }

      return BalanceModel.fromJson(result['data']);
    } catch (e) {
      _logger.e('Error getting balance: $e');
      rethrow;
    }
  }

  /// Get all wallet addresses
  Future<Map<String, List<String>>> getAddresses() async {
    _ensureInitialized();
    
    try {
      final resultPtr = _getAddresses();
      final result = _parseResponse(resultPtr);
      
      if (!result['success']) {
        throw Exception('Failed to get addresses: ${result['error']}');
      }

      return {
        'transparent': List<String>.from(result['data']['transparent'] ?? []),
        'shielded': List<String>.from(result['data']['shielded'] ?? []),
      };
    } catch (e) {
      _logger.e('Error getting addresses: $e');
      rethrow;
    }
  }

  /// Generate a new address
  Future<String> generateNewAddress(String addressType) async {
    _ensureInitialized();
    
    if (!['t', 'z', 'transparent', 'shielded'].contains(addressType)) {
      throw ArgumentError('Address type must be "t" or "z"');
    }
    
    try {
      final typePtr = addressType.toNativeUtf8();
      final resultPtr = _newAddress(typePtr);
      
      final result = _parseResponse(resultPtr);
      calloc.free(typePtr);
      
      if (!result['success']) {
        throw Exception('Failed to generate new address: ${result['error']}');
      }

      return result['data']['address'];
    } catch (e) {
      _logger.e('Error generating new address: $e');
      rethrow;
    }
  }

  /// Sync wallet with blockchain
  Future<Map<String, dynamic>> syncWallet() async {
    _ensureInitialized();
    
    try {
      final resultPtr = _sync();
      final result = _parseResponse(resultPtr);
      
      if (!result['success']) {
        throw Exception('Failed to sync wallet: ${result['error']}');
      }

      return result['data'];
    } catch (e) {
      _logger.e('Error syncing wallet: $e');
      rethrow;
    }
  }

  /// Get sync status
  Future<Map<String, dynamic>> getSyncStatus() async {
    _ensureInitialized();
    
    try {
      final resultPtr = _syncStatus();
      final result = _parseResponse(resultPtr);
      
      if (!result['success']) {
        throw Exception('Failed to get sync status: ${result['error']}');
      }

      return result['data'];
    } catch (e) {
      _logger.e('Error getting sync status: $e');
      rethrow;
    }
  }

  /// Send transaction
  Future<Map<String, dynamic>> sendTransaction({
    required String toAddress,
    required double amount,
    String? memo,
  }) async {
    _ensureInitialized();
    
    try {
      final amountZatoshis = (amount * AppConstants.zatoshisPerBtcz).toInt();
      final addressPtr = toAddress.toNativeUtf8();
      final memoPtr = memo?.toNativeUtf8() ?? nullptr;
      
      final resultPtr = _sendTransaction(addressPtr, amountZatoshis, memoPtr);
      
      final result = _parseResponse(resultPtr);
      calloc.free(addressPtr);
      if (memoPtr != nullptr) calloc.free(memoPtr);
      
      if (!result['success']) {
        throw Exception('Failed to send transaction: ${result['error']}');
      }

      return result['data'];
    } catch (e) {
      _logger.e('Error sending transaction: $e');
      rethrow;
    }
  }

  /// Get transaction history
  Future<List<TransactionModel>> getTransactions() async {
    _ensureInitialized();
    
    try {
      final resultPtr = _getTransactions();
      final result = _parseResponse(resultPtr);
      
      if (!result['success']) {
        throw Exception('Failed to get transactions: ${result['error']}');
      }

      final transactions = List<Map<String, dynamic>>.from(result['data']['transactions'] ?? []);
      return transactions.map((tx) => TransactionModel.fromJson(tx)).toList();
    } catch (e) {
      _logger.e('Error getting transactions: $e');
      rethrow;
    }
  }

  /// Encrypt message for z-address
  Future<String> encryptMessage(String zAddress, String message) async {
    _ensureInitialized();
    
    try {
      final addressPtr = zAddress.toNativeUtf8();
      final messagePtr = message.toNativeUtf8();
      
      final resultPtr = _encryptMessage(addressPtr, messagePtr);
      
      final result = _parseResponse(resultPtr);
      calloc.free(addressPtr);
      calloc.free(messagePtr);
      
      if (!result['success']) {
        throw Exception('Failed to encrypt message: ${result['error']}');
      }

      return result['data']['encrypted'];
    } catch (e) {
      _logger.e('Error encrypting message: $e');
      rethrow;
    }
  }

  /// Decrypt message
  Future<String> decryptMessage(String encryptedData) async {
    _ensureInitialized();
    
    try {
      final dataPtr = encryptedData.toNativeUtf8();
      final resultPtr = _decryptMessage(dataPtr);
      
      final result = _parseResponse(resultPtr);
      calloc.free(dataPtr);
      
      if (!result['success']) {
        throw Exception('Failed to decrypt message: ${result['error']}');
      }

      return result['data']['decrypted'];
    } catch (e) {
      _logger.e('Error decrypting message: $e');
      rethrow;
    }
  }

  /// Parse response from native library
  Map<String, dynamic> _parseResponse(Pointer<Utf8> responsePtr) {
    try {
      final responseStr = responsePtr.toDartString();
      _freeString(responsePtr);
      
      return jsonDecode(responseStr) as Map<String, dynamic>;
    } catch (e) {
      _logger.e('Error parsing response: $e');
      throw Exception('Failed to parse native response');
    }
  }

  void _ensureInitialized() {
    if (!_initialized) {
      throw Exception('BitcoinZ service not initialized. Call initialize() first.');
    }
  }

  /// Cleanup and destroy wallet instance
  Future<void> destroy() async {
    if (!_initialized) return;
    
    try {
      final resultPtr = _destroy();
      final result = _parseResponse(resultPtr);
      
      if (!result['success']) {
        _logger.w('Warning during wallet destruction: ${result['error']}');
      }
      
      _initialized = false;
      _logger.i('BitcoinZ service destroyed');
    } catch (e) {
      _logger.e('Error destroying BitcoinZ service: $e');
    }
  }
}