#!/usr/bin/env dart

import 'dart:io';
import 'dart:ffi';
import 'dart:convert';
import 'package:ffi/ffi.dart';
import 'package:args/args.dart';
import 'package:path/path.dart' as path;

// C function signatures for FFI
typedef BitcoinZInitC = Pointer<Utf8> Function(Pointer<Utf8> serverUrl);
typedef BitcoinZInitDart = Pointer<Utf8> Function(Pointer<Utf8> serverUrl);

typedef BitcoinZCreateWalletC = Pointer<Utf8> Function(Pointer<Utf8> seedPhrase);
typedef BitcoinZCreateWalletDart = Pointer<Utf8> Function(Pointer<Utf8> seedPhrase);

typedef BitcoinZRestoreWalletC = Pointer<Utf8> Function(Pointer<Utf8> seedPhrase, Uint32 birthdayHeight);
typedef BitcoinZRestoreWalletDart = Pointer<Utf8> Function(Pointer<Utf8> seedPhrase, int birthdayHeight);

typedef BitcoinZGetAddressesC = Pointer<Utf8> Function();
typedef BitcoinZGetAddressesDart = Pointer<Utf8> Function();

typedef BitcoinZGetBalanceC = Pointer<Utf8> Function();
typedef BitcoinZGetBalanceDart = Pointer<Utf8> Function();

typedef BitcoinZSyncC = Pointer<Utf8> Function();
typedef BitcoinZSyncDart = Pointer<Utf8> Function();

typedef BitcoinZSyncStatusC = Pointer<Utf8> Function();
typedef BitcoinZSyncStatusDart = Pointer<Utf8> Function();

typedef BitcoinZSendTransactionC = Pointer<Utf8> Function(Pointer<Utf8> toAddress, Uint64 amountZatoshis, Pointer<Utf8> memo);
typedef BitcoinZSendTransactionDart = Pointer<Utf8> Function(Pointer<Utf8> toAddress, int amountZatoshis, Pointer<Utf8> memo);

typedef BitcoinZGetTransactionsC = Pointer<Utf8> Function();
typedef BitcoinZGetTransactionsDart = Pointer<Utf8> Function();

typedef BitcoinZNewAddressC = Pointer<Utf8> Function(Pointer<Utf8> addressType);
typedef BitcoinZNewAddressDart = Pointer<Utf8> Function(Pointer<Utf8> addressType);

typedef BitcoinZEncryptMessageC = Pointer<Utf8> Function(Pointer<Utf8> zAddress, Pointer<Utf8> message);
typedef BitcoinZEncryptMessageDart = Pointer<Utf8> Function(Pointer<Utf8> zAddress, Pointer<Utf8> message);

typedef BitcoinZDecryptMessageC = Pointer<Utf8> Function(Pointer<Utf8> encryptedData);
typedef BitcoinZDecryptMessageDart = Pointer<Utf8> Function(Pointer<Utf8> encryptedData);

typedef BitcoinZGetPrivateKeyC = Pointer<Utf8> Function(Uint32 addressIndex);
typedef BitcoinZGetPrivateKeyDart = Pointer<Utf8> Function(int addressIndex);

// Debug FFI functions - optional, may not be available  
typedef DebugFFIWalletCreationC = Pointer<Utf8> Function();
typedef DebugFFIWalletCreationDart = Pointer<Utf8> Function();

typedef BitcoinZFreeStringC = Void Function(Pointer<Utf8> ptr);
typedef BitcoinZFreeStringDart = void Function(Pointer<Utf8> ptr);

/// Persistent wallet state structure
class WalletState {
  final String walletId;
  final String seedPhrase;
  final int birthdayHeight;
  final List<String> transparentAddresses;
  final List<String> shieldedAddresses;
  final DateTime lastSync;
  final String serverUrl;
  
  WalletState({
    required this.walletId,
    required this.seedPhrase,
    required this.birthdayHeight,
    required this.transparentAddresses,
    required this.shieldedAddresses,
    required this.lastSync,
    required this.serverUrl,
  });
  
  Map<String, dynamic> toJson() => {
    'wallet_id': walletId,
    'seed_phrase': seedPhrase,
    'birthday_height': birthdayHeight,
    'transparent_addresses': transparentAddresses,
    'shielded_addresses': shieldedAddresses,
    'last_sync': lastSync.toIso8601String(),
    'server_url': serverUrl,
  };
  
  factory WalletState.fromJson(Map<String, dynamic> json) => WalletState(
    walletId: json['wallet_id'],
    seedPhrase: json['seed_phrase'],
    birthdayHeight: json['birthday_height'],
    transparentAddresses: List<String>.from(json['transparent_addresses']),
    shieldedAddresses: List<String>.from(json['shielded_addresses']),
    lastSync: DateTime.parse(json['last_sync']),
    serverUrl: json['server_url'],
  );
}

class BitcoinZCLI {
  late DynamicLibrary _lib;
  late BitcoinZInitDart _init;
  late BitcoinZCreateWalletDart _createWallet;
  late BitcoinZRestoreWalletDart _restoreWallet;
  late BitcoinZGetAddressesDart _getAddresses;
  late BitcoinZGetBalanceDart _getBalance;
  late BitcoinZSyncDart _sync;
  late BitcoinZSyncStatusDart _syncStatus;
  late BitcoinZSendTransactionDart _sendTransaction;
  late BitcoinZGetTransactionsDart _getTransactions;
  late BitcoinZNewAddressDart _newAddress;
  late BitcoinZEncryptMessageDart _encryptMessage;
  late BitcoinZDecryptMessageDart _decryptMessage;
  late BitcoinZGetPrivateKeyDart _getPrivateKey;
  DebugFFIWalletCreationDart? _debugFFI;
  late BitcoinZFreeStringDart _freeString;
  
  // Wallet state management
  WalletState? _currentWalletState;
  static const String _walletStateFile = '.bitcoinz_cli_wallet.json';

  void initialize() {
    try {
      // Load the native library (using absolute path to ensure we get the latest version)
      if (Platform.isMacOS) {
        try {
          _lib = DynamicLibrary.open('libbitcoinz_mobile.dylib');
        } catch (e) {
          try {
              _lib = DynamicLibrary.open('@executable_path/../Frameworks/libbitcoinz_mobile.dylib');
            } catch (e3) {
              try {
                _lib = DynamicLibrary.open('./Frameworks/libbitcoinz_mobile.dylib');
              } catch (e4) {
                _lib = DynamicLibrary.open('../../../Frameworks/libbitcoinz_mobile.dylib');
              }
            }
          }
        }
      } else if (Platform.isAndroid) {
        _lib = DynamicLibrary.open('libbitcoinz_mobile.so');
      } else if (Platform.isIOS) {
        _lib = DynamicLibrary.process();
      } else if (Platform.isWindows) {
        _lib = DynamicLibrary.open('bitcoinz_mobile.dll');
      } else if (Platform.isLinux) {
        _lib = DynamicLibrary.open('libbitcoinz_mobile.so');
      } else {
        throw UnsupportedError('Platform ${Platform.operatingSystem} not supported');
      }

      // Bind functions
      _init = _lib.lookupFunction<BitcoinZInitC, BitcoinZInitDart>('bitcoinz_init');
      _createWallet = _lib.lookupFunction<BitcoinZCreateWalletC, BitcoinZCreateWalletDart>('bitcoinz_create_wallet');
      _restoreWallet = _lib.lookupFunction<BitcoinZRestoreWalletC, BitcoinZRestoreWalletDart>('bitcoinz_restore_wallet');
      _getAddresses = _lib.lookupFunction<BitcoinZGetAddressesC, BitcoinZGetAddressesDart>('bitcoinz_get_addresses');
      _getBalance = _lib.lookupFunction<BitcoinZGetBalanceC, BitcoinZGetBalanceDart>('bitcoinz_get_balance');
      _sync = _lib.lookupFunction<BitcoinZSyncC, BitcoinZSyncDart>('bitcoinz_sync');
      _syncStatus = _lib.lookupFunction<BitcoinZSyncStatusC, BitcoinZSyncStatusDart>('bitcoinz_sync_status');
      _sendTransaction = _lib.lookupFunction<BitcoinZSendTransactionC, BitcoinZSendTransactionDart>('bitcoinz_send_transaction');
      _getTransactions = _lib.lookupFunction<BitcoinZGetTransactionsC, BitcoinZGetTransactionsDart>('bitcoinz_get_transactions');
      _newAddress = _lib.lookupFunction<BitcoinZNewAddressC, BitcoinZNewAddressDart>('bitcoinz_new_address');
      _encryptMessage = _lib.lookupFunction<BitcoinZEncryptMessageC, BitcoinZEncryptMessageDart>('bitcoinz_encrypt_message');
      _decryptMessage = _lib.lookupFunction<BitcoinZDecryptMessageC, BitcoinZDecryptMessageDart>('bitcoinz_decrypt_message');
      _getPrivateKey = _lib.lookupFunction<BitcoinZGetPrivateKeyC, BitcoinZGetPrivateKeyDart>('bitcoinz_get_private_key');
      _freeString = _lib.lookupFunction<BitcoinZFreeStringC, BitcoinZFreeStringDart>('bitcoinz_free_string');
      
      // Try to bind debug function (optional)
      try {
        _debugFFI = _lib.lookupFunction<DebugFFIWalletCreationC, DebugFFIWalletCreationDart>('debug_ffi_wallet_creation');
      } catch (e) {
        print('⚠️  Debug FFI function not available: $e');
        _debugFFI = null;
      }

      print('✅ BitcoinZ CLI initialized successfully');
    
    // Try to load existing wallet state
    _loadWalletState();
    } catch (e) {
      print('❌ Failed to initialize CLI: $e');
      exit(1);
    }
  }
  
  /// Get the path to the wallet state file in user's home directory
  String get _walletStateFilePath {
    final homeDir = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '.';
    return path.join(homeDir, _walletStateFile);
  }
  
  /// Load wallet state from file if it exists
  void _loadWalletState() {
    try {
      final stateFile = File(_walletStateFilePath);
      if (stateFile.existsSync()) {
        final content = stateFile.readAsStringSync();
        final json = jsonDecode(content);
        _currentWalletState = WalletState.fromJson(json);
        print('📂 Loaded existing wallet state: ${_currentWalletState!.walletId}');
      }
    } catch (e) {
      print('⚠️  Failed to load wallet state: $e');
      _currentWalletState = null;
    }
  }
  
  /// Save current wallet state to file
  void _saveWalletState() {
    if (_currentWalletState == null) return;
    
    try {
      final stateFile = File(_walletStateFilePath);
      final json = jsonEncode(_currentWalletState!.toJson());
      stateFile.writeAsStringSync(json);
      print('💾 Wallet state saved');
    } catch (e) {
      print('⚠️  Failed to save wallet state: $e');
    }
  }
  
  /// Clear saved wallet state
  void clearWalletState() {
    try {
      final stateFile = File(_walletStateFilePath);
      if (stateFile.existsSync()) {
        stateFile.deleteSync();
        print('🗑️  Wallet state file deleted');
      }
      _currentWalletState = null;
      print('✅ Wallet state cleared');
    } catch (e) {
      print('❌ Failed to clear wallet state: $e');
    }
  }
  
  /// Show current wallet info
  void walletInfo() {
    if (_currentWalletState == null) {
      print('❌ No wallet loaded. Use \'create\' or \'restore\' to set up a wallet.');
      return;
    }
    
    final state = _currentWalletState!;
    print('\n📱 Current Wallet Info:');
    print('🆔 Wallet ID: ${state.walletId}');
    print('🎂 Birthday Height: ${state.birthdayHeight}');
    print('🌐 Server: ${state.serverUrl}');
    print('🕐 Last Sync: ${state.lastSync}');
    print('📍 Addresses:');
    print('  Transparent: ${state.transparentAddresses.length}');
    print('  Shielded: ${state.shieldedAddresses.length}');
    
    if (state.transparentAddresses.isNotEmpty) {
      print('\n📍 Transparent Addresses:');
      for (int i = 0; i < state.transparentAddresses.length; i++) {
        print('  [$i]: ${state.transparentAddresses[i]}');
      }
    }
    
    if (state.shieldedAddresses.isNotEmpty) {
      print('\n🛡️  Shielded Addresses:');
      for (int i = 0; i < state.shieldedAddresses.length; i++) {
        print('  [$i]: ${state.shieldedAddresses[i]}');
      }
    }
  }

  String _callFFI(Pointer<Utf8> Function() ffiCall) {
    final resultPtr = ffiCall();
    if (resultPtr == nullptr) {
      return 'null';
    }
    final result = resultPtr.toDartString();
    _freeString(resultPtr);
    return result;
  }

  void initWallet({String? serverUrl}) {
    print('\n🔧 Initializing wallet...');
    final server = serverUrl ?? 'https://lightd.btcz.rocks:9067';
    final serverPtr = server.toNativeUtf8();
    
    final result = _callFFI(() => _init(serverPtr));
    calloc.free(serverPtr);
    
    print('📤 Init Result: $result');
  }

  void createWallet(String seedPhrase, {String? serverUrl}) {
    print('\n🏗️  Creating wallet with seed phrase...');
    print('📝 Seed: ${seedPhrase.substring(0, 20)}...');
    
    final seedPtr = seedPhrase.toNativeUtf8();
    final result = _callFFI(() => _createWallet(seedPtr));
    calloc.free(seedPtr);
    
    print('📤 Create Wallet Result:');
    final addresses = _parseAndDisplayResult(result);
    
    // Save wallet state if creation was successful
    if (addresses != null && addresses['success'] == true) {
      final data = addresses['data'];
      _currentWalletState = WalletState(
        walletId: data['wallet_id'] ?? 'unknown',
        seedPhrase: seedPhrase,
        birthdayHeight: 0, // Scan from genesis to find all transactions
        transparentAddresses: List<String>.from(data['transparent_addresses'] ?? []),
        shieldedAddresses: List<String>.from(data['shielded_addresses'] ?? []),
        lastSync: DateTime.now(),
        serverUrl: serverUrl ?? 'https://lightd.btcz.rocks:9067',
      );
      _saveWalletState();
    }
  }

  void restoreWallet(String seedPhrase, {int birthdayHeight = 2400000, String? serverUrl}) {
    print('\n🔄 Restoring wallet from seed phrase...');
    print('📝 Seed: ${seedPhrase.substring(0, 20)}...');
    print('🎂 Birthday height: $birthdayHeight');
    
    final seedPtr = seedPhrase.toNativeUtf8();
    final result = _callFFI(() => _restoreWallet(seedPtr, birthdayHeight));
    calloc.free(seedPtr);
    
    print('📤 Restore Wallet Result:');
    final addresses = _parseAndDisplayResult(result);
    
    // Save wallet state if restoration was successful
    if (addresses != null && addresses['success'] == true) {
      final data = addresses['data'];
      _currentWalletState = WalletState(
        walletId: data['wallet_id'] ?? 'unknown',
        seedPhrase: seedPhrase,
        birthdayHeight: birthdayHeight,
        transparentAddresses: List<String>.from(data['transparent_addresses'] ?? []),
        shieldedAddresses: List<String>.from(data['shielded_addresses'] ?? []),
        lastSync: DateTime.now(),
        serverUrl: serverUrl ?? 'https://lightd.btcz.rocks:9067',
      );
      _saveWalletState();
    }
  }

  void getAddresses() {
    print('\n📍 Getting wallet addresses...');
    
    // If we have saved state, use it first
    if (_currentWalletState != null) {
      print('📤 Addresses from saved state:');
      
      if (_currentWalletState!.transparentAddresses.isNotEmpty) {
        print('\n📍 Transparent Addresses:');
        for (int i = 0; i < _currentWalletState!.transparentAddresses.length; i++) {
          final addr = _currentWalletState!.transparentAddresses[i];
          print('  [$i]: "$addr" (${addr.length} chars)');
        }
      }
      
      if (_currentWalletState!.shieldedAddresses.isNotEmpty) {
        print('\n🛡️  Shielded Addresses:');
        for (int i = 0; i < _currentWalletState!.shieldedAddresses.length; i++) {
          final addr = _currentWalletState!.shieldedAddresses[i];
          print('  [$i]: "$addr" (${addr.length} chars)');
        }
      }
      return;
    }
    
    // Fallback to FFI call
    final result = _callFFI(() => _getAddresses());
    print('📤 Get Addresses Result:');
    _parseAndDisplayResult(result);
  }

  void getBalance() {
    print('\n💰 Getting wallet balance...');
    
    if (_currentWalletState == null) {
      print('❌ No wallet loaded. Use \'create\' or \'restore\' first, or load with \'wallet-info\'.');
      return;
    }
    
    // First initialize the wallet with saved state
    _initializeFromSavedState();
    
    final result = _callFFI(() => _getBalance());
    print('📤 Get Balance Result:');
    _parseAndDisplayResult(result);
  }

  void syncWallet() {
    print('\n🔄 Syncing wallet with blockchain...');
    
    if (_currentWalletState == null) {
      print('❌ No wallet loaded. Use \'create\' or \'restore\' first.');
      return;
    }
    
    // Initialize from saved state
    _initializeFromSavedState();
    
    final result = _callFFI(() => _sync());
    print('📤 Sync Result:');
    _parseAndDisplayResult(result);
    
    // Update last sync time
    _currentWalletState = WalletState(
      walletId: _currentWalletState!.walletId,
      seedPhrase: _currentWalletState!.seedPhrase,
      birthdayHeight: _currentWalletState!.birthdayHeight,
      transparentAddresses: _currentWalletState!.transparentAddresses,
      shieldedAddresses: _currentWalletState!.shieldedAddresses,
      lastSync: DateTime.now(),
      serverUrl: _currentWalletState!.serverUrl,
    );
    _saveWalletState();
  }

  void getSyncStatus() {
    print('\n📊 Getting sync status...');
    
    if (_currentWalletState == null) {
      print('❌ No wallet loaded. Use \'create\' or \'restore\' first.');
      return;
    }
    
    // Initialize from saved state
    _initializeFromSavedState();
    
    final result = _callFFI(() => _syncStatus());
    print('📤 Sync Status Result:');
    _parseAndDisplayResult(result);
  }

  void debugFFI() {
    print('\n🔍 Running debug FFI wallet creation...');
    
    if (_debugFFI == null) {
      print('❌ Debug FFI function not available. Function not found in library.');
      return;
    }
    
    final result = _callFFI(() => _debugFFI!());
    print('📤 Debug FFI Result:');
    _parseAndDisplayResult(result);
  }

  void sendTransaction(String toAddress, double amount, {String? memo}) {
    print('\n💸 Sending transaction...');
    print('📍 To: $toAddress');
    print('💰 Amount: $amount BTCZ');
    if (memo != null) print('📝 Memo: $memo');
    
    final amountZatoshis = (amount * 100000000).toInt(); // Convert BTCZ to zatoshis
    print('🔢 Amount in zatoshis: $amountZatoshis');
    
    final toPtr = toAddress.toNativeUtf8();
    final memoPtr = memo?.toNativeUtf8() ?? nullptr;
    
    final result = _callFFI(() => _sendTransaction(toPtr, amountZatoshis, memoPtr));
    
    calloc.free(toPtr);
    if (memoPtr != nullptr) calloc.free(memoPtr);
    
    print('📤 Send Transaction Result:');
    _parseAndDisplayResult(result);
  }

  void getTransactions() {
    print('\n📜 Getting transaction history...');
    
    final result = _callFFI(() => _getTransactions());
    print('📤 Transaction History Result:');
    _parseAndDisplayResult(result);
  }

  void generateNewAddress(String addressType) {
    print('\n🔑 Generating new $addressType address...');
    
    if (_currentWalletState == null) {
      print('❌ No wallet loaded. Use \'create\' or \'restore\' first.');
      return;
    }
    
    // Initialize from saved state
    _initializeFromSavedState();
    
    final typePtr = addressType.toNativeUtf8();
    final result = _callFFI(() => _newAddress(typePtr));
    calloc.free(typePtr);
    
    print('📤 New Address Result:');
    final addressResult = _parseAndDisplayResult(result);
    
    // Update saved state with new address if generation was successful
    if (addressResult != null && addressResult['success'] == true) {
      final newAddress = addressResult['data']?['address'] as String?;
      if (newAddress != null) {
        final updatedTransparent = List<String>.from(_currentWalletState!.transparentAddresses);
        final updatedShielded = List<String>.from(_currentWalletState!.shieldedAddresses);
        
        if (addressType == 't' || addressType == 'transparent') {
          updatedTransparent.add(newAddress);
        } else if (addressType == 'z' || addressType == 'shielded') {
          updatedShielded.add(newAddress);
        }
        
        _currentWalletState = WalletState(
          walletId: _currentWalletState!.walletId,
          seedPhrase: _currentWalletState!.seedPhrase,
          birthdayHeight: _currentWalletState!.birthdayHeight,
          transparentAddresses: updatedTransparent,
          shieldedAddresses: updatedShielded,
          lastSync: _currentWalletState!.lastSync,
          serverUrl: _currentWalletState!.serverUrl,
        );
        _saveWalletState();
      }
    }
  }

  void encryptMessage(String zAddress, String message) {
    print('\n🔒 Encrypting message for z-address...');
    print('📍 Z-Address: ${zAddress.substring(0, 20)}...');
    print('📝 Message: $message');
    
    final addressPtr = zAddress.toNativeUtf8();
    final messagePtr = message.toNativeUtf8();
    
    final result = _callFFI(() => _encryptMessage(addressPtr, messagePtr));
    
    calloc.free(addressPtr);
    calloc.free(messagePtr);
    
    print('📤 Encrypt Message Result:');
    _parseAndDisplayResult(result);
  }

  void decryptMessage(String encryptedData) {
    print('\n🔓 Decrypting message...');
    print('🔐 Encrypted data: ${encryptedData.substring(0, 40)}...');
    
    final dataPtr = encryptedData.toNativeUtf8();
    final result = _callFFI(() => _decryptMessage(dataPtr));
    calloc.free(dataPtr);
    
    print('📤 Decrypt Message Result:');
    _parseAndDisplayResult(result);
  }

  void getPrivateKey(int addressIndex) {
    print('\n🔑 Getting private key for address index $addressIndex...');
    
    if (_currentWalletState == null) {
      print('❌ No wallet loaded. Use \'create\' or \'restore\' first.');
      return;
    }
    
    // Initialize from saved state
    _initializeFromSavedState();
    
    final result = _callFFI(() => _getPrivateKey(addressIndex));
    print('📤 Private Key Result:');
    final keyResult = _parseAndDisplayResult(result);
    
    if (keyResult != null && keyResult['success'] == true) {
      final privateKey = keyResult['data']?['private_key'] as String?;
      if (privateKey != null) {
        print('\n🔑 Private Key for Address Index $addressIndex:');
        print('   $privateKey');
        print('\n⚠️  IMPORTANT: Keep this private key secure and never share it!');
        
        // Show corresponding address if available
        if (addressIndex < _currentWalletState!.transparentAddresses.length) {
          print('🏠 Corresponding Address: ${_currentWalletState!.transparentAddresses[addressIndex]}');
        }
      }
    }
  }

  void compareAddressGeneration(String seedPhrase) {
    print('\n🔍 Comparing address generation methods...');
    print('📝 Seed: ${seedPhrase.substring(0, 20)}...');
    
    // First, call debug FFI which uses deterministic seed
    print('\n1️⃣  Debug FFI (deterministic seed):');
    debugFFI();
    
    // Then create wallet with provided seed
    print('\n2️⃣  Create Wallet (your seed):');
    createWallet(seedPhrase);
  }

  /// Initialize wallet from saved state
  void _initializeFromSavedState() {
    if (_currentWalletState == null) return;
    
    print('🔄 Initializing wallet from saved state...');
    initWallet(serverUrl: _currentWalletState!.serverUrl);
    
    // Restore the wallet to get it back into memory
    final seedPtr = _currentWalletState!.seedPhrase.toNativeUtf8();
    final result = _callFFI(() => _restoreWallet(seedPtr, _currentWalletState!.birthdayHeight));
    calloc.free(seedPtr);
    
    print('✅ Wallet state restored in memory');
  }
  
  Map<String, dynamic>? _parseAndDisplayResult(String result) {
    try {
      Map<String, dynamic>? parsedResult;
      
      // Try to parse as JSON
      if (result.contains('{')) {
        try {
          parsedResult = jsonDecode(result);
        } catch (e) {
          // If JSON parsing fails, create a simple structure
          parsedResult = {'raw': result};
        }
      } else {
        parsedResult = {'raw': result};
      }
      
      // Display raw result
      print('Raw: $result');
      
      // Try to extract and display addresses if present
      if (result.contains('transparent_addresses') || result.contains('shielded_addresses')) {
        final RegExp transparentRegex = RegExp(r'"transparent_addresses":\s*\[(.*?)\]');
        final RegExp shieldedRegex = RegExp(r'"shielded_addresses":\s*\[(.*?)\]');
        
        final transparentMatch = transparentRegex.firstMatch(result);
        final shieldedMatch = shieldedRegex.firstMatch(result);
        
        if (transparentMatch != null) {
          print('\n📍 Transparent Addresses:');
          final addresses = transparentMatch.group(1)?.split(',') ?? [];
          for (int i = 0; i < addresses.length; i++) {
            final addr = addresses[i].replaceAll('"', '').trim();
            if (addr.isNotEmpty) {
              print('  [$i]: "$addr" (${addr.length} chars)');
            }
          }
        }
        
        if (shieldedMatch != null) {
          print('\n🛡️  Shielded Addresses:');
          final addresses = shieldedMatch.group(1)?.split(',') ?? [];
          for (int i = 0; i < addresses.length; i++) {
            final addr = addresses[i].replaceAll('"', '').trim();
            if (addr.isNotEmpty) {
              print('  [$i]: "$addr" (${addr.length} chars)');
            }
          }
        }
      }
      
      return parsedResult;
    } catch (e) {
      print('📋 Raw result: $result');
      return null;
    }
  }
}

void main(List<String> arguments) {
  final parser = ArgParser()
    ..addFlag('help', abbr: 'h', help: 'Show help information')
    ..addOption('server', abbr: 's', help: 'LightwalletD server URL')
    ..addOption('seed', help: 'Seed phrase for wallet operations')
    ..addOption('birthday', abbr: 'b', help: 'Birthday block height', defaultsTo: '0')
    ..addOption('to', help: 'Recipient address for transactions')
    ..addOption('amount', abbr: 'a', help: 'Amount to send (in BTCZ)')
    ..addOption('memo', abbr: 'm', help: 'Optional memo for transactions')
    ..addOption('type', abbr: 't', help: 'Address type (t/transparent or z/shielded)', defaultsTo: 'transparent')
    ..addOption('message', help: 'Message to encrypt/decrypt')
    ..addOption('encrypted', help: 'Encrypted data to decrypt')
    ..addOption('index', abbr: 'i', help: 'Address index for private key', defaultsTo: '0');

  try {
    final results = parser.parse(arguments);
    
    if (results['help'] || arguments.isEmpty) {
      print('BitcoinZ Mobile Wallet CLI - Complete Testing Tool\n');
      print('Usage: dart run bin/cli_test.dart <command> [options]\n');
      print('📋 Wallet Management Commands:');
      print('  init                Initialize wallet service');
      print('  create              Create new wallet with --seed');
      print('  restore             Restore wallet from --seed (with --birthday)');
      print('  wallet-info         Show current wallet information');
      print('  destroy-wallet      Clear saved wallet state');
      print('  addresses           Get current wallet addresses');
      print('  generate            Generate new address (--type t/z)');
      print('\n💰 Balance & Sync Commands:');
      print('  balance             Get wallet balance');
      print('  sync                Sync wallet with blockchain');
      print('  sync-status         Get sync progress');
      print('\n💸 Transaction Commands:');
      print('  send                Send transaction (--to --amount --memo)');
      print('  transactions        Get transaction history');
      print('\n🔒 Message Commands:');
      print('  encrypt             Encrypt message (--to --message)');
      print('  decrypt             Decrypt message (--encrypted)');
      print('\n🔧 Debug Commands:');
      print('  debug-ffi           Run debug FFI test');
      print('  compare             Compare address generation methods');
      print('\nOptions:');
      print(parser.usage);
      print('\n📖 Examples:');
      print('  dart run bin/cli_test.dart init');
      print('  dart run bin/cli_test.dart create --seed "abandon abandon abandon..."');
      print('  dart run bin/cli_test.dart restore --seed "..." --birthday 2400000');
      print('  dart run bin/cli_test.dart wallet-info');
      print('  dart run bin/cli_test.dart addresses');
      print('  dart run bin/cli_test.dart balance');
      print('  dart run bin/cli_test.dart generate --type z');
      print('  dart run bin/cli_test.dart send --to t1abc... --amount 1.5 --memo "test"');
      print('  dart run bin/cli_test.dart encrypt --to zs1abc... --message "hello"');
      return;
    }

    if (arguments.isEmpty) {
      print('❌ Please specify a command. Use --help for usage information.');
      exit(1);
    }

    final cli = BitcoinZCLI();
    cli.initialize();

    final command = arguments[0];
    
    switch (command) {
      case 'init':
        final server = results['server'] as String?;
        cli.initWallet(serverUrl: server);
        break;
        
      case 'create':
        final seed = results['seed'] as String?;
        if (seed == null) {
          print('❌ --seed option is required for create command');
          exit(1);
        }
        cli.initWallet(serverUrl: results['server'] as String?); // Initialize first
        cli.createWallet(seed, serverUrl: results['server'] as String?);
        break;
        
      case 'restore':
        final seed = results['seed'] as String?;
        if (seed == null) {
          print('❌ --seed option is required for restore command');
          exit(1);
        }
        final birthday = int.tryParse(results['birthday'] as String) ?? 0;
        cli.initWallet(serverUrl: results['server'] as String?); // Initialize first
        cli.restoreWallet(seed, birthdayHeight: birthday, serverUrl: results['server'] as String?);
        break;
        
      case 'wallet-info':
        cli.walletInfo();
        break;
        
      case 'destroy-wallet':
        cli.clearWalletState();
        break;
        
      case 'addresses':
        cli.getAddresses();
        break;
        
      case 'balance':
        cli.getBalance();
        break;
        
      case 'generate':
        final type = results['type'] as String;
        cli.generateNewAddress(type);
        break;
        
      case 'sync':
        cli.syncWallet();
        break;
        
      case 'sync-status':
        cli.getSyncStatus();
        break;
        
      case 'send':
        final to = results['to'] as String?;
        final amountStr = results['amount'] as String?;
        if (to == null || amountStr == null) {
          print('❌ --to and --amount options are required for send command');
          exit(1);
        }
        final amount = double.tryParse(amountStr);
        if (amount == null || amount <= 0) {
          print('❌ Invalid amount: $amountStr');
          exit(1);
        }
        final memo = results['memo'] as String?;
        cli.sendTransaction(to, amount, memo: memo);
        break;
        
      case 'transactions':
        cli.getTransactions();
        break;
        
      case 'encrypt':
        final to = results['to'] as String?;
        final message = results['message'] as String?;
        if (to == null || message == null) {
          print('❌ --to and --message options are required for encrypt command');
          exit(1);
        }
        cli.encryptMessage(to, message);
        break;
        
      case 'decrypt':
        final encrypted = results['encrypted'] as String?;
        if (encrypted == null) {
          print('❌ --encrypted option is required for decrypt command');
          exit(1);
        }
        cli.decryptMessage(encrypted);
        break;
        
      case 'debug-ffi':
        cli.debugFFI();
        break;
        
      case 'private-key':
        final indexStr = results['index'] as String;
        final addressIndex = int.tryParse(indexStr) ?? 0;
        cli.getPrivateKey(addressIndex);
        break;
        
      case 'compare':
        final seed = results['seed'] as String?;
        if (seed == null) {
          print('❌ --seed option is required for compare command');
          exit(1);
        }
        cli.initWallet(); // Initialize first
        cli.compareAddressGeneration(seed);
        break;
        
      default:
        print('❌ Unknown command: $command');
        print('Use --help for usage information.');
        exit(1);
    }
    
  } catch (e) {
    print('❌ Error: $e');
    exit(1);
  }
}