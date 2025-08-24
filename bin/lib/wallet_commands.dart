import 'dart:io';
import 'dart:ffi';
import 'dart:convert';
import 'package:ffi/ffi.dart';
import 'package:chalkdart/chalkdart.dart';

import 'wallet_session.dart';
import 'ui_helpers.dart';

// Import the existing CLI functionality
// We'll create a bridge to reuse the BitcoinZCLI class

/// Bridge to integrate existing CLI wallet functionality with interactive shell
class WalletCommands {
  final WalletSession session;
  final UIHelpers ui;
  
  // FFI function pointers (copied from cli_test.dart)
  late DynamicLibrary _lib;
  late _BitcoinZInitDart _init;
  late _BitcoinZCreateWalletDart _createWallet;
  late _BitcoinZRestoreWalletDart _restoreWallet;
  late _BitcoinZGetAddressesDart _getAddresses;
  late _BitcoinZGetBalanceDart _getBalance;
  late _BitcoinZSyncDart _sync;
  late _BitcoinZSyncStatusDart _syncStatus;
  late _BitcoinZSendTransactionDart _sendTransaction;
  late _BitcoinZGetTransactionsDart _getTransactions;
  late _BitcoinZNewAddressDart _newAddress;
  late _BitcoinZEncryptMessageDart _encryptMessage;
  late _BitcoinZDecryptMessageDart _decryptMessage;
  late _BitcoinZFreeStringDart _freeString;

  bool _isInitialized = false;
  
  WalletCommands({required this.session, required this.ui});

  /// Initialize FFI connections
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      await _loadLibrary();
      _bindFunctions();
      _isInitialized = true;
    } catch (e) {
      throw Exception('Failed to initialize wallet commands: $e');
    }
  }

  /// Load the native library
  Future<void> _loadLibrary() async {
    if (Platform.isMacOS) {
      try {
        _lib = DynamicLibrary.open('libbitcoinz_mobile.dylib');
      } catch (e) {
        _lib = DynamicLibrary.open('@executable_path/../Frameworks/libbitcoinz_mobile.dylib');
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
  }

  /// Bind FFI functions
  void _bindFunctions() {
    _init = _lib.lookupFunction<_BitcoinZInitC, _BitcoinZInitDart>('bitcoinz_init');
    _createWallet = _lib.lookupFunction<_BitcoinZCreateWalletC, _BitcoinZCreateWalletDart>('bitcoinz_create_wallet');
    _restoreWallet = _lib.lookupFunction<_BitcoinZRestoreWalletC, _BitcoinZRestoreWalletDart>('bitcoinz_restore_wallet');
    _getAddresses = _lib.lookupFunction<_BitcoinZGetAddressesC, _BitcoinZGetAddressesDart>('bitcoinz_get_addresses');
    _getBalance = _lib.lookupFunction<_BitcoinZGetBalanceC, _BitcoinZGetBalanceDart>('bitcoinz_get_balance');
    _sync = _lib.lookupFunction<_BitcoinZSyncC, _BitcoinZSyncDart>('bitcoinz_sync');
    _syncStatus = _lib.lookupFunction<_BitcoinZSyncStatusC, _BitcoinZSyncStatusDart>('bitcoinz_sync_status');
    _sendTransaction = _lib.lookupFunction<_BitcoinZSendTransactionC, _BitcoinZSendTransactionDart>('bitcoinz_send_transaction');
    _getTransactions = _lib.lookupFunction<_BitcoinZGetTransactionsC, _BitcoinZGetTransactionsDart>('bitcoinz_get_transactions');
    _newAddress = _lib.lookupFunction<_BitcoinZNewAddressC, _BitcoinZNewAddressDart>('bitcoinz_new_address');
    _encryptMessage = _lib.lookupFunction<_BitcoinZEncryptMessageC, _BitcoinZEncryptMessageDart>('bitcoinz_encrypt_message');
    _decryptMessage = _lib.lookupFunction<_BitcoinZDecryptMessageC, _BitcoinZDecryptMessageDart>('bitcoinz_decrypt_message');
    _freeString = _lib.lookupFunction<_BitcoinZFreeStringC, _BitcoinZFreeStringDart>('bitcoinz_free_string');
  }

  /// Create a new wallet
  Future<void> createWallet({String? seedPhrase, String? serverUrl}) async {
    await initialize();
    
    if (!session.hasWallet || ui.promptConfirm('A wallet already exists. Replace it?', defaultValue: false)) {
      print('');
      print(chalk.blue.bold('🏗️  Creating New Wallet'));
      print('');
      
      // Get seed phrase if not provided
      if (seedPhrase == null) {
        seedPhrase = ui.promptInput('Enter seed phrase (24 words)', required: true);
        if (seedPhrase == null) return;
      }
      
      // Get server URL if not provided
      serverUrl ??= ui.promptInput('Server URL', defaultValue: 'https://lightd.btcz.rocks:9067');
      
      try {
        // Initialize wallet service
        print(chalk.gray('🔧 Initializing wallet service...'));
        final serverPtr = (serverUrl ?? 'https://lightd.btcz.rocks:9067').toNativeUtf8();
        final initResult = _callFFI(() => _init(serverPtr));
        calloc.free(serverPtr);
        
        final initJson = jsonDecode(initResult);
        if (initJson['success'] != true) {
          throw Exception(initJson['error'] ?? 'Init failed');
        }
        
        // Create wallet
        print(chalk.gray('🔑 Creating wallet...'));
        ui.showProgress('Creating wallet', 0.3);
        
        final seedPtr = seedPhrase.toNativeUtf8();
        final createResult = _callFFI(() => _createWallet(seedPtr));
        calloc.free(seedPtr);
        
        ui.showProgress('Creating wallet', 1.0);
        
        final createJson = jsonDecode(createResult);
        if (createJson['success'] != true) {
          throw Exception(createJson['error'] ?? 'Wallet creation failed');
        }
        
        // Parse result and save state
        final data = createJson['data'];
        final newWalletState = WalletState(
          walletId: data['wallet_id'],
          seedPhrase: seedPhrase,
          birthdayHeight: 0,
          transparentAddresses: List<String>.from(data['transparent_addresses'] ?? []),
          shieldedAddresses: List<String>.from(data['shielded_addresses'] ?? []),
          lastSync: DateTime.now(),
          serverUrl: serverUrl ?? 'https://lightd.btcz.rocks:9067',
        );
        
        session.setWalletState(newWalletState);
        
        print('');
        print(chalk.green.bold('✅ Wallet created successfully!'));
        print('🆔 Wallet ID: ${newWalletState.walletId}');
        print('📍 Generated ${newWalletState.transparentAddresses.length} transparent addresses');
        print('🛡️  Generated ${newWalletState.shieldedAddresses.length} shielded addresses');
        print('');
        
      } catch (e) {
        print(chalk.red('❌ Failed to create wallet: $e'));
      }
    }
  }

  /// Restore wallet from seed phrase
  Future<void> restoreWallet({String? seedPhrase, int? birthdayHeight, String? serverUrl}) async {
    await initialize();
    
    print('');
    print(chalk.blue.bold('🔄 Restoring Wallet'));
    print('');
    
    // Get parameters
    seedPhrase ??= ui.promptInput('Enter seed phrase (24 words)', required: true);
    if (seedPhrase == null) return;
    
    birthdayHeight ??= int.tryParse(ui.promptInput('Birthday height (block number)', defaultValue: '0') ?? '0') ?? 0;
    serverUrl ??= ui.promptInput('Server URL', defaultValue: 'https://lightd.btcz.rocks:9067');
    
    try {
      // Initialize wallet service
      print(chalk.gray('🔧 Initializing wallet service...'));
      final serverPtr = serverUrl!.toNativeUtf8();
      final initResult = _callFFI(() => _init(serverPtr));
      calloc.free(serverPtr);
      
      final initJson = jsonDecode(initResult);
      if (initJson['success'] != true) {
        throw Exception(initJson['error'] ?? 'Init failed');
      }
      
      // Restore wallet
      print(chalk.gray('🔍 Restoring wallet...'));
      ui.showProgress('Restoring wallet', 0.5);
      
      final seedPtr = seedPhrase.toNativeUtf8();
      final restoreResult = _callFFI(() => _restoreWallet(seedPtr, birthdayHeight!));
      calloc.free(seedPtr);
      
      ui.showProgress('Restoring wallet', 1.0);
      
      final restoreJson = jsonDecode(restoreResult);
      if (restoreJson['success'] != true) {
        throw Exception(restoreJson['error'] ?? 'Wallet restoration failed');
      }
      
      // Parse result and save state
      final data = restoreJson['data'];
      final restoredWalletState = WalletState(
        walletId: data['wallet_id'],
        seedPhrase: seedPhrase,
        birthdayHeight: birthdayHeight!,
        transparentAddresses: List<String>.from(data['transparent_addresses'] ?? []),
        shieldedAddresses: List<String>.from(data['shielded_addresses'] ?? []),
        lastSync: DateTime.now(),
        serverUrl: serverUrl,
      );
      
      session.setWalletState(restoredWalletState);
      
      print('');
      print(chalk.green.bold('✅ Wallet restored successfully!'));
      print('🆔 Wallet ID: ${restoredWalletState.walletId}');
      print('🎂 Birthday Height: ${restoredWalletState.birthdayHeight}');
      print('📍 Restored ${restoredWalletState.transparentAddresses.length} transparent addresses');
      print('🛡️  Restored ${restoredWalletState.shieldedAddresses.length} shielded addresses');
      print('');
      
    } catch (e) {
      print(chalk.red('❌ Failed to restore wallet: $e'));
    }
  }

  /// Get wallet balance
  Future<void> showBalance() async {
    if (!session.hasWallet) {
      print(chalk.yellow('⚠️  No wallet loaded'));
      return;
    }
    
    await initialize();
    
    print('');
    print(chalk.blue.bold('💰 Getting Wallet Balance'));
    print('');
    
    try {
      await _initializeWalletFromSession();
      
      ui.showSpinner('Fetching balance from blockchain...', frame: 0);
      final balanceResult = _callFFI(() => _getBalance());
      ui.clearLine();
      
      final balanceJson = jsonDecode(balanceResult);
      if (balanceJson['success'] != true) {
        throw Exception(balanceJson['error'] ?? 'Balance query failed');
      }
      
      final data = balanceJson['data'];
      final transparent = data['transparent'] as int;
      final shielded = data['shielded'] as int;
      final total = data['total'] as int;
      final unconfirmed = data['unconfirmed'] as int;
      
      print(chalk.green.bold('💰 Current Balance:'));
      print('   Total:        ${ui.formatBTCZ(total)} BTCZ');
      print('   ├─ Transparent: ${ui.formatBTCZ(transparent)} BTCZ');
      print('   └─ Shielded:    ${ui.formatBTCZ(shielded)} BTCZ');
      
      if (unconfirmed > 0) {
        print('   Unconfirmed:  ${ui.formatBTCZ(unconfirmed)} BTCZ');
      }
      print('');
      
    } catch (e) {
      ui.clearLine();
      print(chalk.red('❌ Failed to get balance: $e'));
    }
  }

  /// Sync with blockchain
  Future<void> syncWallet() async {
    if (!session.hasWallet) {
      print(chalk.yellow('⚠️  No wallet loaded'));
      return;
    }
    
    await initialize();
    
    print('');
    print(chalk.blue.bold('🔄 Syncing with Blockchain'));
    print('');
    
    try {
      await _initializeWalletFromSession();
      
      ui.showProgress('Syncing with BitcoinZ network', 0.1);
      final syncResult = _callFFI(() => _sync());
      ui.showProgress('Syncing with BitcoinZ network', 1.0);
      
      final syncJson = jsonDecode(syncResult);
      if (syncJson['success'] != true) {
        throw Exception(syncJson['error'] ?? 'Sync failed');
      }
      
      final data = syncJson['data'];
      final blocksSynced = data['synced_blocks'] as int;
      final currentHeight = data['current_height'] as int;
      final totalHeight = data['total_height'] as int;
      
      print(chalk.green.bold('✅ Sync Complete!'));
      print('📦 Blocks synced: $blocksSynced');
      print('📏 Current height: $currentHeight');
      print('🎯 Network height: $totalHeight');
      print('');
      
      // Update last sync time
      final currentState = session.walletState!;
      final updatedState = WalletState(
        walletId: currentState.walletId,
        seedPhrase: currentState.seedPhrase,
        birthdayHeight: currentState.birthdayHeight,
        transparentAddresses: currentState.transparentAddresses,
        shieldedAddresses: currentState.shieldedAddresses,
        lastSync: DateTime.now(),
        serverUrl: currentState.serverUrl,
      );
      session.setWalletState(updatedState);
      
    } catch (e) {
      ui.clearLine();
      print(chalk.red('❌ Sync failed: $e'));
    }
  }

  /// Initialize wallet from session state
  Future<void> _initializeWalletFromSession() async {
    final state = session.walletState!;
    
    // Initialize wallet service
    final serverPtr = state.serverUrl.toNativeUtf8();
    final initResult = _callFFI(() => _init(serverPtr));
    calloc.free(serverPtr);
    
    final initJson = jsonDecode(initResult);
    if (initJson['success'] != true) {
      throw Exception(initJson['error'] ?? 'Init failed');
    }
    
    // Restore wallet state
    final seedPtr = state.seedPhrase.toNativeUtf8();
    final restoreResult = _callFFI(() => _restoreWallet(seedPtr, state.birthdayHeight));
    calloc.free(seedPtr);
    
    final restoreJson = jsonDecode(restoreResult);
    if (restoreJson['success'] != true) {
      throw Exception(restoreJson['error'] ?? 'Wallet restore failed');
    }
  }

  /// Call FFI function with proper memory management
  String _callFFI(Pointer<Utf8> Function() ffiCall) {
    final resultPtr = ffiCall();
    if (resultPtr == nullptr) {
      return '{"success": false, "error": "null result"}';
    }
    final result = resultPtr.toDartString();
    _freeString(resultPtr);
    return result;
  }
  
  /// Generate new address
  Future<void> generateAddress(String type) async {
    if (!session.hasWallet) {
      print(chalk.yellow('⚠️  No wallet loaded'));
      return;
    }
    
    await initialize();
    
    final isShielded = type.toLowerCase() == 'shielded' || type.toLowerCase() == 'z';
    final spinner = ui.spinner(
      isShielded ? 'Generating shielded address...' : 'Generating transparent address...'
    );
    
    final addressTypePtr = isShielded ? 'z'.toNativeUtf8() : 't'.toNativeUtf8();
    
    try {
      final resultPtr = _newAddress(addressTypePtr);
      
      if (resultPtr == nullptr) {
        spinner.fail('Failed to generate address');
        return;
      }
      
      final resultJson = resultPtr.cast<Utf8>().toDartString();
      _freeString(resultPtr);
      
      final result = json.decode(resultJson);
      if (result['error'] != null) {
        spinner.fail('Error: ${result['error']}');
        return;
      }
      
      final newAddress = result['address'];
      spinner.complete('Generated new ${isShielded ? "shielded" : "transparent"} address');
      
      print('');
      ui.printBox(
        title: isShielded ? '🔒 New Shielded Address' : '📬 New Transparent Address',
        content: newAddress,
        color: 'cyan'
      );
      
      // Update session state
      if (isShielded) {
        session.walletState!.shieldedAddresses.add(newAddress);
      } else {
        session.walletState!.transparentAddresses.add(newAddress);
      }
      session.save();
      
    } catch (e) {
      spinner.fail('Failed to generate address: $e');
    } finally {
      calloc.free(addressTypePtr);
    }
  }
  
  /// Send transaction
  Future<void> sendTransaction() async {
    if (!session.hasWallet) {
      print(chalk.yellow('⚠️  No wallet loaded'));
      return;
    }
    
    await initialize();
    
    print(chalk.cyan.bold('\n💸 Send Transaction'));
    print(chalk.gray('─' * 40));
    
    // Get recipient address
    stdout.write('Recipient address: ');
    final toAddress = stdin.readLineSync() ?? '';
    if (toAddress.isEmpty) {
      print(chalk.gray('Cancelled'));
      return;
    }
    
    // Get amount
    stdout.write('Amount (BTCZ): ');
    final amountStr = stdin.readLineSync() ?? '';
    if (amountStr.isEmpty) {
      print(chalk.gray('Cancelled'));
      return;
    }
    
    final amount = double.tryParse(amountStr);
    if (amount == null || amount <= 0) {
      print(chalk.red('❌ Invalid amount'));
      return;
    }
    
    // Get memo (optional for shielded)
    String? memo;
    if (toAddress.startsWith('zs')) {
      stdout.write('Memo (optional): ');
      memo = stdin.readLineSync();
    }
    
    // Confirm transaction
    print('');
    print(chalk.yellow('📋 Transaction Summary:'));
    print('  To: $toAddress');
    print('  Amount: $amount BTCZ');
    if (memo != null && memo.isNotEmpty) {
      print('  Memo: $memo');
    }
    
    stdout.write('\nConfirm send? (y/n): ');
    final confirm = stdin.readLineSync()?.toLowerCase();
    if (confirm != 'y') {
      print(chalk.gray('Cancelled'));
      return;
    }
    
    final spinner = ui.spinner('Sending transaction...');
    
    final toAddressPtr = toAddress.toNativeUtf8();
    final memoPtr = (memo ?? '').toNativeUtf8();
    
    try {
      final amountZatoshis = (amount * 100000000).round();
      
      final resultPtr = _sendTransaction(
        toAddressPtr,
        amountZatoshis,
        memoPtr
      );
      
      if (resultPtr == nullptr) {
        spinner.fail('Failed to send transaction');
        return;
      }
      
      final resultJson = resultPtr.cast<Utf8>().toDartString();
      _freeString(resultPtr);
      
      final result = json.decode(resultJson);
      if (result['error'] != null) {
        spinner.fail('Error: ${result['error']}');
        return;
      }
      
      spinner.complete('Transaction sent successfully!');
      
      print('');
      ui.printBox(
        title: '✅ Transaction Sent',
        content: 'TxID: ${result['txid'] ?? 'pending'}',
        color: 'green'
      );
      
    } catch (e) {
      spinner.fail('Failed to send transaction: $e');
    } finally {
      calloc.free(toAddressPtr);
      calloc.free(memoPtr);
    }
  }
  
  /// Show transaction history
  Future<void> showTransactionHistory() async {
    if (!session.hasWallet) {
      print(chalk.yellow('⚠️  No wallet loaded'));
      return;
    }
    
    await initialize();
    
    final spinner = ui.spinner('Loading transaction history...');
    
    try {
      final resultPtr = _getTransactions();
      
      if (resultPtr == nullptr) {
        spinner.fail('Failed to load transactions');
        return;
      }
      
      final resultJson = resultPtr.cast<Utf8>().toDartString();
      _freeString(resultPtr);
      
      final result = json.decode(resultJson);
      if (result['error'] != null) {
        spinner.fail('Error: ${result['error']}');
        return;
      }
      
      spinner.complete('Loaded transaction history');
      
      final transactions = result['transactions'] as List? ?? [];
      
      if (transactions.isEmpty) {
        print('');
        print(chalk.gray('No transactions found'));
        return;
      }
      
      print('');
      print(chalk.cyan.bold('📜 Transaction History'));
      print(chalk.gray('─' * 60));
      
      for (final tx in transactions) {
        final type = tx['type'] ?? 'unknown';
        final amount = tx['amount'] ?? 0;
        final date = tx['date'] ?? 'unknown';
        final status = tx['confirmed'] == true ? '✓' : '⏳';
        
        print('');
        print('$status ${type == 'received' ? chalk.green('↓') : chalk.red('↑')} '
              '${amount.toStringAsFixed(8)} BTCZ');
        print(chalk.gray('   ${tx['txid'] ?? 'unknown'}'));
        print(chalk.gray('   $date'));
      }
      
      print('');
      print(chalk.gray('─' * 60));
      print(chalk.gray('Total: ${transactions.length} transactions'));
      
    } catch (e) {
      spinner.fail('Failed to load transactions: $e');
    }
  }
}

// FFI type definitions (copied from cli_test.dart)
typedef _BitcoinZInitC = Pointer<Utf8> Function(Pointer<Utf8> serverUrl);
typedef _BitcoinZInitDart = Pointer<Utf8> Function(Pointer<Utf8> serverUrl);

typedef _BitcoinZCreateWalletC = Pointer<Utf8> Function(Pointer<Utf8> seedPhrase);
typedef _BitcoinZCreateWalletDart = Pointer<Utf8> Function(Pointer<Utf8> seedPhrase);

typedef _BitcoinZRestoreWalletC = Pointer<Utf8> Function(Pointer<Utf8> seedPhrase, Uint32 birthdayHeight);
typedef _BitcoinZRestoreWalletDart = Pointer<Utf8> Function(Pointer<Utf8> seedPhrase, int birthdayHeight);

typedef _BitcoinZGetAddressesC = Pointer<Utf8> Function();
typedef _BitcoinZGetAddressesDart = Pointer<Utf8> Function();

typedef _BitcoinZGetBalanceC = Pointer<Utf8> Function();
typedef _BitcoinZGetBalanceDart = Pointer<Utf8> Function();

typedef _BitcoinZSyncC = Pointer<Utf8> Function();
typedef _BitcoinZSyncDart = Pointer<Utf8> Function();

typedef _BitcoinZSyncStatusC = Pointer<Utf8> Function();
typedef _BitcoinZSyncStatusDart = Pointer<Utf8> Function();

typedef _BitcoinZSendTransactionC = Pointer<Utf8> Function(Pointer<Utf8> toAddress, Uint64 amountZatoshis, Pointer<Utf8> memo);
typedef _BitcoinZSendTransactionDart = Pointer<Utf8> Function(Pointer<Utf8> toAddress, int amountZatoshis, Pointer<Utf8> memo);

typedef _BitcoinZGetTransactionsC = Pointer<Utf8> Function();
typedef _BitcoinZGetTransactionsDart = Pointer<Utf8> Function();

typedef _BitcoinZNewAddressC = Pointer<Utf8> Function(Pointer<Utf8> addressType);
typedef _BitcoinZNewAddressDart = Pointer<Utf8> Function(Pointer<Utf8> addressType);

typedef _BitcoinZEncryptMessageC = Pointer<Utf8> Function(Pointer<Utf8> zAddress, Pointer<Utf8> message);
typedef _BitcoinZEncryptMessageDart = Pointer<Utf8> Function(Pointer<Utf8> zAddress, Pointer<Utf8> message);

typedef _BitcoinZDecryptMessageC = Pointer<Utf8> Function(Pointer<Utf8> encryptedData);
typedef _BitcoinZDecryptMessageDart = Pointer<Utf8> Function(Pointer<Utf8> encryptedData);

typedef _BitcoinZFreeStringC = Void Function(Pointer<Utf8> ptr);
typedef _BitcoinZFreeStringDart = void Function(Pointer<Utf8> ptr);