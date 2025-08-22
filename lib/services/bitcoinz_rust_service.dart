/// BitcoinZ Rust Service - Uses native Rust library for unconfirmed transactions
/// This service uses the Rust FFI bridge to access zecwalletlitelib
/// which properly monitors the mempool for unconfirmed transactions

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../models/balance_model.dart';
import '../models/transaction_model.dart';
import '../services/database_service.dart';
import '../services/wallet_storage_service.dart';
import '../src/rust/api.dart' as rust_api;
import '../src/rust/frb_generated.dart';

class BitcoinzRustService {
  static BitcoinzRustService? _instance;
  static BitcoinzRustService get instance {
    if (_instance == null) {
      _instance = BitcoinzRustService._();
      if (kDebugMode) print('🔨 Creating new BitcoinzRustService singleton instance');
    }
    return _instance!;
  }
  
  BitcoinzRustService._();
  
  bool _initialized = false;
  static bool _bridgeInitialized = false;
  String? _seedPhrase;
  int? _birthday;
  
  /// Check if the service is initialized
  bool get initialized => _initialized;
  
  // Callbacks (same as BitcoinZ Blue)
  Function(BalanceModel)? fnSetTotalBalance;
  Function(List<TransactionModel>)? fnSetTransactionsList;
  Function(Map<String, List<String>>)? fnSetAllAddresses;
  Function(Map<String, dynamic>)? fnSetInfo;
  
  // Timers (EXACT copy of BitcoinZ Blue)
  Timer? refreshTimerID;
  Timer? updateTimerId;
  
  // State tracking
  String? lastTxId;
  double? lastBalance;
  int? lastTxCount;
  
  // Update throttling
  bool _isUpdating = false;
  DateTime? _lastUpdateTime;
  static const Duration _minUpdateInterval = Duration(seconds: 2);
  
  // Blockchain info caching
  int? _currentBlockHeight;
  DateTime? _blockHeightLastFetch;
  static const Duration _blockHeightCacheDuration = Duration(seconds: 30);
  
  /// Initialize the Rust bridge and wallet
  Future<bool> initialize({
    required String serverUri,
    String? seedPhrase,
    bool createNew = false,
    int? birthdayHeight,
  }) async {
    try {
      if (kDebugMode) {
        print('🚀 Initializing Rust Bridge...');
        print('🎂 ANDROID BIRTHDAY FIX: Critical parameter analysis:');
        print('   Platform: ${Platform.isAndroid ? "Android" : Platform.isMacOS ? "macOS" : "Other"}');
        print('   serverUri: $serverUri');
        print('   seedPhrase: ${seedPhrase != null ? "[EXISTS ${seedPhrase.length} chars]" : "null"}');
        print('   createNew: $createNew');
        print('   🚨 BIRTHDAY HEIGHT: $birthdayHeight (${birthdayHeight.runtimeType})');
        print('     Is null: ${birthdayHeight == null}');
        print('     Is > 0: ${birthdayHeight != null && birthdayHeight > 0}');
        print('     Expected behavior: null/0 = sync from genesis, >0 = sync from that height');
      }
      
      // Check if bridge is already initialized (done in main.dart)
      if (!_bridgeInitialized) {
        try {
          if (kDebugMode) print('📱 ANDROID: Attempting to load Rust native library...');
          await RustLib.init();
          _bridgeInitialized = true;
          if (kDebugMode) print('✅ Rust bridge initialized successfully on Android');
        } catch (e) {
          // Bridge might already be initialized from main.dart
          if (e.toString().contains('Should not initialize flutter_rust_bridge twice')) {
            _bridgeInitialized = true;
            if (kDebugMode) print('✅ Rust bridge already initialized');
          } else {
            if (kDebugMode) {
              print('❌ ANDROID: Failed to load Rust library!');
              print('   Error: $e');
              print('   This means native .so files may not be loading');
              print('   Check if libbitcoinz_mobile.so is in the APK');
            }
            rethrow;
          }
        }
      } else {
        if (kDebugMode) print('✅ Rust bridge already initialized, skipping');
      }
      
      // Get the wallet data directory for Black Amber (where wallet.dat will be stored)
      // This ensures we don't use BitcoinZ Blue's wallet directory
      String? walletDirPath;
      try {
        final walletDir = await WalletStorageService.getWalletDataDirectory();
        walletDirPath = walletDir.path;
        if (kDebugMode) {
          print('📁 Using Black Amber wallet directory: $walletDirPath');
          
          // Check if wallet.dat already exists
          final walletFile = File('$walletDirPath/wallet.dat');
          if (await walletFile.exists()) {
            final stat = await walletFile.stat();
            print('✅ Found existing wallet.dat:');
            print('   Size: ${stat.size} bytes');
            print('   Modified: ${stat.modified}');
          } else {
            print('📝 No existing wallet.dat found, will create new or restore');
          }
        }
      } catch (e) {
        if (kDebugMode) print('⚠️ Failed to get wallet directory, using default: $e');
        walletDirPath = null;
      }
      
      // Initialize wallet
      if (createNew) {
        // Create new wallet
        if (kDebugMode) {
          print('📝 Creating new wallet via Rust...');
          print('   Server: $serverUri');
          print('   Directory: ${walletDirPath ?? "default"}');
        }
        
        // Use Black Amber's wallet directory to avoid conflicts with BitcoinZ Blue
        if (kDebugMode) print('📁 Creating wallet in: ${walletDirPath ?? "default"}');
        
        String result;
        try {
          result = await rust_api.initializeNewWithInfo(
            serverUri: serverUri,
            walletDir: walletDirPath, // Use Black Amber directory
          );
        } catch (e) {
          if (kDebugMode) {
            print('❌ Exception calling initializeNewWithInfo: $e');
            print('   Error type: ${e.runtimeType}');
          }
          return false;
        }
        
        if (result.startsWith('Error:')) {
          if (kDebugMode) print('❌ Failed to create wallet: $result');
          return false;
        }
        
        // Parse JSON response to get seed and birthday
        try {
          if (kDebugMode) print('📋 Raw response: $result');
          
          // The response structure is:
          // {"seed": "{\"seed\":\"actual words here\",\"birthday\":1612745}", "birthday": 1612745, "latest_block": 1612845}
          // We need to handle this double-nested structure
          
          // First, find the actual seed phrase using a more robust regex
          // Look for the innermost seed value (the actual words)
          final innerSeedMatch = RegExp(r'\\"seed\\":\\"([^"\\]+)\\"').firstMatch(result);
          if (innerSeedMatch != null) {
            _seedPhrase = innerSeedMatch.group(1)!;
            if (kDebugMode) print('📝 Extracted seed phrase via regex');
          } else {
            // Fallback: try to find any seed phrase pattern (24 words)
            final wordsMatch = RegExp(r'"([a-z]+(?: [a-z]+){23})"').firstMatch(result);
            if (wordsMatch != null) {
              _seedPhrase = wordsMatch.group(1)!;
              if (kDebugMode) print('📝 Extracted seed phrase via word pattern');
            }
          }
          
          // Extract birthday from the outer JSON (not escaped)
          final birthdayMatch = RegExp(r'"birthday"\s*:\s*(\d+)(?=[,}])').firstMatch(result);
          if (birthdayMatch != null) {
            _birthday = int.parse(birthdayMatch.group(1)!);
            if (kDebugMode) print('🎂 Extracted birthday: $_birthday');
          }
          
          if (kDebugMode) {
            print('✅ New wallet created');
            print('   Seed phrase: ${_seedPhrase!.split(' ').length} words');
            print('   Birthday block: $_birthday');
          }
        } catch (e) {
          if (kDebugMode) {
            print('❌ Failed to parse wallet creation response: $e');
            print('   Error type: ${e.runtimeType}');
            print('   Stack trace:');
            print(StackTrace.current);
          }
          return false;
        }
      } else if (seedPhrase != null) {
        // Restore from seed
        if (kDebugMode) print('🔄 Restoring wallet from seed...');
        
        // Use Black Amber's wallet directory for restoration
        String result;
        try {
          if (kDebugMode) print('📁 Restoring wallet to: ${walletDirPath ?? "default"}');
          
          // Use provided birthday height or default to 0 for full scan
          final birthdayToUse = birthdayHeight ?? 0;
          if (kDebugMode) {
            print('📅 SEED PHRASE RESTORATION:');
            print('   Input birthday height: $birthdayHeight');
            print('   Birthday to use: $birthdayToUse');
            print('   BigInt conversion: ${BigInt.from(birthdayToUse)}');
            print('   🚨 CRITICAL: If this is 0, Android will sync from genesis!');
            print('   🎯 ROOT CAUSE FIX: This was the missing birthday parameter!');
          }
          
          // Use the full function with wallet directory
          result = await rust_api.initializeFromPhrase(
            serverUri: serverUri,
            seedPhrase: seedPhrase,
            birthday: BigInt.from(birthdayToUse), // Use provided birthday or 0
            overwrite: true, // Overwrite if exists
            walletDir: walletDirPath,
          );
        } catch (e) {
          if (kDebugMode) print('⚠️ Restore with custom directory failed: $e');
          return false;
        }
        
        if (result != 'OK' && !result.contains('seed')) {
          if (kDebugMode) print('❌ Failed to restore wallet: $result');
          return false;
        }
        _seedPhrase = seedPhrase;
        _birthday = birthdayHeight ?? 0; // Store the birthday height
        if (kDebugMode) print('✅ Wallet restored with birthday: ${birthdayHeight ?? 0}');
      } else {
        // Load existing wallet
        if (kDebugMode) print('📂 Loading existing wallet...');
        
        // Load from Black Amber's wallet directory
        if (kDebugMode) print('📁 Loading wallet from: ${walletDirPath ?? "default"}');
        
        String result;
        // If birthday height is provided, use the new function with birthday
        if (birthdayHeight != null && birthdayHeight > 0) {
          if (kDebugMode) {
            print('📅 EXISTING WALLET LOAD (with birthday):');
            print('   Birthday height: $birthdayHeight');
            print('   BigInt conversion: ${BigInt.from(birthdayHeight)}');
            print('   🎯 This should preserve Android sync state!');
          }
          result = await rust_api.initializeExistingWithBirthday(
            serverUri: serverUri,
            walletDir: walletDirPath,
            birthday: BigInt.from(birthdayHeight),
          );
        } else {
          if (kDebugMode) {
            print('📅 EXISTING WALLET LOAD (no birthday):');
            print('   Birthday height: $birthdayHeight');
            print('   ⚠️ Using initializeExisting without birthday - may cause resync');
          }
          result = await rust_api.initializeExisting(
            serverUri: serverUri,
            walletDir: walletDirPath,
          );
        }
        
        if (!result.contains('OK') && !result.contains('success') && !result.contains('status')) {
          if (kDebugMode) print('❌ Failed to load existing wallet: $result');
          return false;
        }
        
        // Extract birthday from response if available
        if (result.contains('birthday')) {
          final birthdayMatch = RegExp(r'"birthday"\s*:\s*(\d+)').firstMatch(result);
          if (birthdayMatch != null) {
            _birthday = int.parse(birthdayMatch.group(1)!);
            if (kDebugMode) print('🎂 Loaded wallet with birthday: $_birthday');
          }
        }
        
        if (kDebugMode) print('✅ Existing wallet loaded');
      }
      
      _initialized = true;
      
      if (kDebugMode) {
        print('✅ Rust service marked as initialized');
        print('   Seed available: ${_seedPhrase != null}');
        print('   Birthday: $_birthday');
      }
      
      // Start update timers (like BitcoinZ Blue)
      startTimers();
      
      // Initial sync
      await sync();
      
      return true;
    } catch (e) {
      if (kDebugMode) print('❌ Initialization failed: $e');
      return false;
    }
  }
  
  /// Start update timers (Optimized version)
  void startTimers() {
    if (kDebugMode) print('⏱️ Starting update timers...');
    
    // 60-second refresh timer
    refreshTimerID ??= Timer.periodic(const Duration(seconds: 60), (_) {
      refresh();
    });
    
    // 10-second update timer for change detection (increased from 3 seconds to prevent resize timeout)
    // This still provides responsive updates while reducing system load
    updateTimerId ??= Timer.periodic(const Duration(seconds: 10), (_) {
      updateData();
    });
    
    // Immediately refresh on start
    Timer.run(() => refresh());
  }
  
  /// Stop all timers
  void stopTimers() {
    refreshTimerID?.cancel();
    refreshTimerID = null;
    
    updateTimerId?.cancel();
    updateTimerId = null;
    
    if (kDebugMode) print('🛑 Stopped all timers');
  }
  
  /// Fast update - runs every 3 seconds with throttling
  Future<void> updateData() async {
    if (!_initialized) return;
    
    // Prevent concurrent updates
    if (_isUpdating) {
      return;
    }
    
    // Throttle updates to prevent UI overload
    if (_lastUpdateTime != null) {
      final timeSinceLastUpdate = DateTime.now().difference(_lastUpdateTime!);
      if (timeSinceLastUpdate < _minUpdateInterval) {
        return;
      }
    }
    
    _isUpdating = true;
    _lastUpdateTime = DateTime.now();
    
    try {
      // Get transaction list
      final txListJson = await rust_api.execute(command: 'list', args: '');
      final txListDecoded = jsonDecode(txListJson);
      
      // Check if response is an error
      if (txListDecoded is Map && txListDecoded.containsKey('error')) {
        if (kDebugMode) print('⚠️ Transaction list error: ${txListDecoded['error']}');
        return;
      }
      
      final txList = txListDecoded as List;
      
      // Get latest txid
      final latestTxid = txList.isNotEmpty ? txList[0]['txid'] : '';
      
      // Get balance
      final balanceJson = await rust_api.execute(command: 'balance', args: '');
      final balanceData = jsonDecode(balanceJson);
      
      // Check if balance response is an error
      if (balanceData is Map && balanceData.containsKey('error')) {
        if (kDebugMode) print('⚠️ Balance error: ${balanceData['error']}');
        return;
      }
      
      final currentBalance = ((balanceData['tbalance'] ?? 0) + 
                              (balanceData['zbalance'] ?? 0)) / 100000000.0;
      
      // Get transaction count
      final currentTxCount = txList.length;
      
      // Triple change detection (EXACT copy of BitcoinZ Blue)
      final txidChanged = lastTxId != latestTxid;
      final balanceChanged = lastBalance != currentBalance;
      final txCountChanged = lastTxCount != currentTxCount;
      
      if (txidChanged || balanceChanged || txCountChanged) {
        if (kDebugMode) {
          print('🔄 CHANGE DETECTED via Rust!');
          print('   TxID changed: $txidChanged');
          print('   Balance changed: $balanceChanged');
          print('   Tx count changed: $txCountChanged');
        }
        
        lastTxId = latestTxid;
        lastBalance = currentBalance;
        lastTxCount = currentTxCount;
        
        // Fetch all data in parallel for better performance
        await Future.wait([
          fetchBalance(),
          fetchTransactions(),
          fetchAddresses(),
        ]);
      }
    } catch (e) {
      if (kDebugMode) print('❌ Update data failed: $e');
    } finally {
      _isUpdating = false;
    }
  }
  
  /// Full refresh - runs every 60 seconds
  Future<void> refresh() async {
    if (!_initialized) return;
    
    if (kDebugMode) print('🔄 Full refresh via Rust...');
    
    try {
      // Sync with network
      await sync();
      
      // Fetch all data in parallel for better performance  
      await Future.wait([
        fetchBalance(),
        fetchTransactions(), 
        fetchAddresses(),
      ]);
      
      // Save wallet
      await save();
      
      if (kDebugMode) print('✅ Full refresh complete');
    } catch (e) {
      if (kDebugMode) print('❌ Full refresh failed: $e');
    }
  }
  
  /// Sync with network
  Future<void> sync() async {
    if (!_initialized) return;
    
    try {
      if (kDebugMode) print('🔄 Syncing with network via Rust...');
      // Add timeout to prevent hanging indefinitely on Android
      final result = await rust_api.execute(command: 'sync', args: '').timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          if (kDebugMode) print('⏱️ Sync command timed out after 15 seconds');
          return '{"status": "timeout"}';
        },
      );
      if (kDebugMode) print('Sync result: ${result.substring(0, math.min(100, result.length))}...');
    } catch (e) {
      if (kDebugMode) print('❌ Sync failed: $e');
    }
  }
  
  /// Save wallet
  Future<void> save() async {
    if (!_initialized) return;
    
    try {
      final result = await rust_api.execute(command: 'save', args: '');
      if (kDebugMode) print('💾 Wallet saved: $result');
    } catch (e) {
      if (kDebugMode) print('❌ Save failed: $e');
    }
  }
  
  /// Fetch balance
  Future<void> fetchBalance() async {
    if (!_initialized) {
      if (kDebugMode) print('❌ fetchBalance: Rust service not initialized');
      return;
    }
    
    if (kDebugMode) print('💰 fetchBalance: Starting balance fetch...');
    
    try {
      if (kDebugMode) print('💰 fetchBalance: Executing "balance" command...');
      // Add timeout to prevent hanging
      final balanceJson = await rust_api.execute(command: 'balance', args: '').timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          if (kDebugMode) print('⏱️ fetchBalance: Timeout after 10 seconds');
          return '{"tbalance": 0, "zbalance": 0}'; // Return empty balance on timeout
        },
      );
      if (kDebugMode) print('💰 fetchBalance: Got response');
      final data = jsonDecode(balanceJson);
      
      if (kDebugMode) print('💰 Balance from Rust: $data');
      
      // Check for unconfirmed transactions in mempool
      final txListJson = await rust_api.execute(command: 'list', args: '');
      var txListDecoded = jsonDecode(txListJson);
      
      // Check if response is an error
      if (txListDecoded is Map && txListDecoded.containsKey('error')) {
        if (kDebugMode) print('⚠️ Transaction list error in fetchBalance: ${txListDecoded['error']}');
        // Return empty list for transactions when error
        txListDecoded = [];
      }
      
      final txList = txListDecoded as List;
      
      // Debug: Log first transaction to see structure
      if (kDebugMode && txList.isNotEmpty) {
        print('🔍 First transaction data:');
        print('   Full tx: ${txList.first}');
        print('   unconfirmed field: ${txList.first['unconfirmed']}');
        print('   block_height field: ${txList.first['block_height']}');
      }
      
      double pendingBalance = 0;
      double pendingTransparent = 0;
      double pendingShielded = 0;
      
      for (final tx in txList) {
        // Check for unconfirmed: either explicit flag OR no block height
        final bool isUnconfirmed = tx['unconfirmed'] == true || 
                                   tx['block_height'] == null || 
                                   tx['block_height'] == 0;
        
        if (isUnconfirmed) {
          final amount = (tx['amount'] ?? 0).abs() / 100000000.0;
          if (tx['outgoing_metadata'] == null) {
            // Incoming unconfirmed
            pendingBalance += amount;
            
            // Determine if it's to a transparent or shielded address
            final address = tx['address'] as String?;
            if (address != null) {
              if (address.startsWith('t1') || address.startsWith('t3')) {
                pendingTransparent += amount;
                if (kDebugMode) {
                  print('🔄 UNCONFIRMED TRANSPARENT INCOMING: ${tx['txid']} - $amount BTCZ to $address');
                }
              } else if (address.startsWith('zs1') || address.startsWith('zc')) {
                pendingShielded += amount;
                if (kDebugMode) {
                  print('🔄 UNCONFIRMED SHIELDED INCOMING: ${tx['txid']} - $amount BTCZ to $address');
                }
              } else {
                // Unknown address type, add to shielded by default
                pendingShielded += amount;
                if (kDebugMode) {
                  print('🔄 UNCONFIRMED INCOMING (unknown type): ${tx['txid']} - $amount BTCZ');
                }
              }
            } else {
              // No address info, add to shielded by default
              pendingShielded += amount;
            }
          }
        }
      }
      
      final balance = BalanceModel(
        transparent: (data['tbalance'] ?? 0) / 100000000.0,
        shielded: (data['zbalance'] ?? 0) / 100000000.0,
        total: ((data['tbalance'] ?? 0) + (data['zbalance'] ?? 0)) / 100000000.0,
        unconfirmed: pendingBalance,
        unconfirmedTransparent: pendingTransparent,
        unconfirmedShielded: pendingShielded,
      );
      
      fnSetTotalBalance?.call(balance);
      if (kDebugMode) print('✅ Balance fetched successfully');
    } catch (e) {
      if (kDebugMode) print('❌ Fetch balance failed: $e');
    }
  }
  
  /// Get current blockchain height (with caching)
  Future<int> getCurrentBlockHeight() async {
    if (!_initialized) return 1600000; // Return reasonable default if not initialized
    
    // Check cache
    final now = DateTime.now();
    if (_currentBlockHeight != null && 
        _blockHeightLastFetch != null &&
        now.difference(_blockHeightLastFetch!).compareTo(_blockHeightCacheDuration) < 0) {
      return _currentBlockHeight!;
    }
    
    try {
      final infoJson = await rust_api.execute(command: 'info', args: '');
      final info = jsonDecode(infoJson);
      
      if (kDebugMode) {
        print('📊 Info response keys: ${info.keys.toList()}');
        print('📊 Full info: $info');
      }
      
      // Check multiple possible field names for block height
      dynamic heightValue = info['latest_block_height'] ??  // This is the correct field!
                           info['height'] ?? 
                           info['blockHeight'] ?? 
                           info['block_height'] ?? 
                           info['latestBlock'] ?? 
                           info['latest_block'] ??
                           info['synced_to'];
      
      if (heightValue != null) {
        _currentBlockHeight = heightValue is int ? heightValue : int.tryParse(heightValue.toString());
        if (_currentBlockHeight != null) {
          _blockHeightLastFetch = now;
          if (kDebugMode) {
            print('📊 Current block height: $_currentBlockHeight (from field: ${info.keys.where((k) => info[k] == heightValue).first})');
          }
          return _currentBlockHeight!;
        }
      }
    } catch (e) {
      if (kDebugMode) print('❌ Failed to get block height: $e');
    }
    
    return _currentBlockHeight ?? 1600000; // Return cached value or default if fetch fails
  }
  
  /// Fetch transactions with timeout
  Future<void> fetchTransactions() async {
    if (!_initialized) {
      if (kDebugMode) print('❌ fetchTransactions: Rust service not initialized');
      return;
    }
    
    if (kDebugMode) print('🔍 fetchTransactions: Starting transaction fetch...');
    
    try {
      // Add timeout to prevent infinite loading
      if (kDebugMode) print('🔍 fetchTransactions: Executing "list" command...');
      final txListJson = await rust_api.execute(command: 'list', args: '').timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          if (kDebugMode) print('⏱️ fetchTransactions: Timeout after 10 seconds');
          return '[]'; // Return empty array on timeout
        },
      );
      
      if (kDebugMode) print('🔍 fetchTransactions: Got response: ${txListJson.substring(0, math.min(100, txListJson.length))}...');
      final txListDecoded = jsonDecode(txListJson);
      
      // Check if response is an error
      if (txListDecoded is Map && txListDecoded.containsKey('error')) {
        if (kDebugMode) print('⚠️ Transaction list error in fetchTransactions: ${txListDecoded['error']}');
        return;
      }
      
      final txList = txListDecoded as List;
      
      if (kDebugMode) {
        final unconfirmedCount = txList.where((tx) => tx['unconfirmed'] == true).length;
        print('📋 Transactions from Rust: ${txList.length} total, $unconfirmedCount unconfirmed');
        if (txList.isEmpty) {
          print('📋 No transactions found - wallet may be empty or not synced');
        }
      }
      
      // Get current block height for confirmation calculation
      final currentHeight = await getCurrentBlockHeight();
      
      // Load memo read status from database
      final memoReadStatus = await DatabaseService.instance.getMemoReadStatus();
      
      final transactions = <TransactionModel>[];
      
      int index = 0;
      for (final tx in txList) {
        index++;
        
        // Debug log first transaction to see available fields
        if (kDebugMode && index == 1) {
          print('📋 First transaction fields: ${(tx as Map).keys.toList()}');
          print('📋 Transaction data: txid=${tx['txid']?.toString()?.substring(0, 8)}..., unconfirmed=${tx['unconfirmed']}, block_height=${tx['block_height']}');
        }
        
        // Check if transaction is unconfirmed (multiple ways)
        final bool txUnconfirmed = tx['unconfirmed'] == true || 
                                   tx['block_height'] == null || 
                                   tx['block_height'] == 0;
        
        final type = tx['outgoing_metadata'] != null ? 'sent' : 'received';
        final address = type == 'sent'
            ? (tx['outgoing_metadata'].isNotEmpty ? tx['outgoing_metadata'][0]['address'] : '')
            : tx['address'];
        
        final amount = (tx['amount'] ?? 0).abs() / 100000000.0;
        
        // Calculate real confirmations
        int confirmations = 0;
        
        // Check multiple possible field names for transaction block height
        dynamic txHeightValue = tx['block_height'] ?? 
                                tx['blockHeight'] ?? 
                                tx['height'] ??
                                tx['blockheight'];
        
        final blockHeight = txHeightValue is int ? txHeightValue : 
                           (txHeightValue != null ? int.tryParse(txHeightValue.toString()) : null);
        
        if (txUnconfirmed) {
          confirmations = 0;
          if (kDebugMode) {
            print('🔄 Unconfirmed TX: ${(tx['txid'] as String).substring(0, 8)}...');
          }
        } else if (blockHeight != null && blockHeight > 0 && currentHeight != null) {
          confirmations = currentHeight - blockHeight + 1;
          if (confirmations < 0) confirmations = 1; // Safety check
          if (kDebugMode && index < 3) { // Log first 3 transactions
            print('📊 TX ${(tx['txid'] as String).substring(0, 8)}...: blockHeight=$blockHeight, currentHeight=$currentHeight, confirmations=$confirmations');
          }
        } else {
          // Default to 1 if we can't calculate
          confirmations = 1;
          if (kDebugMode && index < 3) { // Log first 3 transactions
            print('⚠️ TX ${(tx['txid'] as String).substring(0, 8)}...: Cannot calculate confirmations (blockHeight=$blockHeight, currentHeight=$currentHeight)');
          }
        }
        
        // Log unconfirmed transactions
        if (txUnconfirmed) {
          if (kDebugMode) {
            print('🔄 UNCONFIRMED TX via Rust: ${tx['txid']} - $type $amount BTCZ');
            print('   unconfirmed flag: ${tx['unconfirmed']}');
            print('   block_height: ${tx['block_height']}');
          }
        }
        
        final txid = tx['txid'] ?? '';
        final hasMemo = tx['memo'] != null && tx['memo'].toString().isNotEmpty;
        
        // Get memo read status from database, default to false for new transactions
        final isRead = hasMemo ? (memoReadStatus[txid] ?? false) : false;
        
        final transaction = TransactionModel(
          txid: txid,
          type: type,
          amount: amount,
          blockHeight: blockHeight,
          fromAddress: type == 'received' ? address : null,
          toAddress: type == 'sent' ? address : null,
          timestamp: DateTime.fromMillisecondsSinceEpoch((tx['datetime'] ?? 0) * 1000),
          confirmations: confirmations,
          memo: tx['memo'],
          fee: type == 'sent' ? 0.0001 : 0.0,
          memoRead: isRead,
        );
        
        transactions.add(transaction);
      }
      
      // Sort by timestamp (newest first)
      transactions.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      
      // Store transactions in database to persist memo read status
      await DatabaseService.instance.insertTransactions(transactions);
      
      if (kDebugMode) print('📋 Calling fnSetTransactionsList with ${transactions.length} transactions');
      fnSetTransactionsList?.call(transactions);
      
      if (fnSetTransactionsList == null && kDebugMode) {
        print('⚠️ fnSetTransactionsList callback is null - transactions not sent to provider');
      }
    } catch (e) {
      if (kDebugMode) print('❌ Fetch transactions failed: $e');
    }
  }
  
  /// Fetch addresses
  Future<void> fetchAddresses() async {
    if (!_initialized) return;
    
    try {
      final addressesJson = await rust_api.execute(command: 'addresses', args: '');
      final data = jsonDecode(addressesJson);
      
      final addresses = <String, List<String>>{
        'transparent': [],
        'shielded': [],
      };
      
      // Handle both array and object formats
      if (data is List) {
        for (final addr in data) {
          if (addr is Map && addr['address'] != null) {
            final address = addr['address'] as String;
            if (address.startsWith('t1') || address.startsWith('t3')) {
              addresses['transparent']!.add(address);
            } else if (address.startsWith('zs1')) {
              addresses['shielded']!.add(address);
            }
          }
        }
      } else if (data is Map) {
        // Handle t_addresses and z_addresses arrays
        if (data['t_addresses'] != null) {
          for (final addr in data['t_addresses']) {
            if (addr is Map && addr['address'] != null) {
              addresses['transparent']!.add(addr['address']);
            } else if (addr is String) {
              addresses['transparent']!.add(addr);
            }
          }
        }
        if (data['z_addresses'] != null) {
          for (final addr in data['z_addresses']) {
            if (addr is Map && addr['address'] != null) {
              addresses['shielded']!.add(addr['address']);
            } else if (addr is String) {
              addresses['shielded']!.add(addr);
            }
          }
        }
      }
      
      fnSetAllAddresses?.call(addresses);
    } catch (e) {
      if (kDebugMode) print('❌ Fetch addresses failed: $e');
    }
  }
  
  /// Send transaction
  Future<String?> sendTransaction(String address, double amount, String? memo) async {
    if (!_initialized) return null;
    
    try {
      if (kDebugMode) print('📤 Sending $amount BTCZ to $address via Rust...');
      
      // Convert BTCZ to zatoshis (1 BTCZ = 100,000,000 zatoshis)
      final zatoshis = (amount * 100000000).toInt();
      
      // Build send command arguments  
      final args = '$address $zatoshis ${memo ?? ""}';
      
      final result = await rust_api.execute(command: 'send', args: args);
      final data = jsonDecode(result);
      
      if (data['txid'] != null) {
        final txid = data['txid'] as String;
        if (kDebugMode) print('✅ Transaction sent via Rust: $txid');
        
        // Force immediate refresh to pick up the new transaction
        Timer.run(() => refresh());
        
        return txid;
      } else if (data['error'] != null) {
        throw Exception(data['error']);
      }
      
      return null;
    } catch (e) {
      if (kDebugMode) print('❌ Send transaction failed: $e');
      throw e;
    }
  }
  
  /// Get new address with timeout
  Future<String?> getNewAddress({bool transparent = true}) async {
    if (!_initialized) return null;
    
    try {
      final command = 'new';
      final args = transparent ? 't' : 'z';
      // Add timeout to prevent infinite loading
      final result = await rust_api.execute(command: command, args: args).timeout(
        const Duration(seconds: 10),
        onTimeout: () => '{"error": "Timeout generating address"}',
      );
      final data = jsonDecode(result);
      
      if (data is List && data.isNotEmpty) {
        return data[0] as String;
      }
      
      return null;
    } catch (e) {
      if (kDebugMode) print('❌ Get new address failed: $e');
      return null;
    }
  }
  
  /// Get seed phrase (stored in memory)
  String? getSeedPhrase() => _seedPhrase;
  
  /// Get seed phrase from wallet using 'seed' command
  Future<String?> getSeedPhraseFromWallet() async {
    if (!_initialized) return null;
    
    try {
      // Execute the 'seed' command to get seed phrase from wallet
      final result = await rust_api.execute(command: 'seed', args: '').timeout(
        const Duration(seconds: 10),
        onTimeout: () => '{"error": "Timeout getting seed phrase"}',
      );
      
      final data = jsonDecode(result);
      
      // Check for error
      if (data is Map && data.containsKey('error')) {
        if (kDebugMode) print('❌ Seed command error: ${data['error']}');
        return null;
      }
      
      // Extract seed phrase from response
      if (data is Map && data.containsKey('seed')) {
        return data['seed'] as String?;
      }
      
      // Some responses might have the seed directly
      if (data is String && data.isNotEmpty) {
        return data;
      }
      
      if (kDebugMode) print('❌ Unexpected seed response format: $data');
      return null;
    } catch (e) {
      if (kDebugMode) print('❌ Get seed phrase from wallet failed: $e');
      return null;
    }
  }
  
  /// Get birthday block height
  int? getBirthday() => _birthday;
  
  
  /// Get sync status for progress display
  Future<Map<String, dynamic>?> getSyncStatus() async {
    if (!_initialized) {
      if (kDebugMode) print('⚠️ getSyncStatus: Rust service not initialized');
      return null;
    }
    
    try {
      if (kDebugMode) print('🔍 Calling syncstatus command...');
      
      // Add timeout to prevent hanging on Android
      // Use shorter timeout on Android where syncstatus tends to hang
      final timeout = Platform.isAndroid 
          ? const Duration(seconds: 2) 
          : const Duration(seconds: 5);
      
      final statusStr = await rust_api.execute(
        command: 'syncstatus', 
        args: ''
      ).timeout(
        timeout,
        onTimeout: () {
          if (kDebugMode) print('⏱️ Syncstatus command timed out after ${timeout.inSeconds}s');
          // Return a JSON string indicating sync is complete when timeout occurs
          // This prevents the sync polling from continuing forever
          return '{"sync_id": 1, "in_progress": false, "last_error": null}';
        },
      );
      
      if (kDebugMode) {
        print('📊 Raw sync status from Rust: "$statusStr"');
        print('   Type: ${statusStr.runtimeType}');
        print('   Length: ${statusStr.length}');
      }
      
      // Try to parse as JSON first
      try {
        final status = jsonDecode(statusStr);
        if (status is Map<String, dynamic>) {
          return status;
        }
      } catch (e) {
        // Not JSON, parse the text format: "id: 1, batch: 0/9, blocks: 0/50000"
        if (statusStr.contains('batch:') && statusStr.contains('blocks:')) {
          if (kDebugMode) print('   Parsing text format sync status...');
          
          final parts = statusStr.split(',').map((s) => s.trim()).toList();
          
          int? batchNum, batchTotal, syncedBlocks, totalBlocks;
          bool inProgress = false;
          
          for (final part in parts) {
            if (part.contains('batch:')) {
              // Find the batch: part even if not at the start
              final batchMatch = RegExp(r'batch:\s*(\d+)/(\d+)').firstMatch(part);
              if (batchMatch != null) {
                batchNum = int.tryParse(batchMatch.group(1)!) ?? 0;
                batchTotal = int.tryParse(batchMatch.group(2)!) ?? 0;
                // Add 1 to batch number since it's 0-indexed for display
                if (batchTotal > 0) batchNum = batchNum + 1;
                if (kDebugMode) print('   Found batch: $batchNum/$batchTotal');
              }
            }
            if (part.contains('blocks:')) {
              // Find the blocks: part even if not at the start
              final blockMatch = RegExp(r'blocks:\s*(\d+)/(\d+)').firstMatch(part);
              if (blockMatch != null) {
                syncedBlocks = int.tryParse(blockMatch.group(1)!) ?? 0;
                totalBlocks = int.tryParse(blockMatch.group(2)!) ?? 0;
                if (kDebugMode) print('   Found blocks: $syncedBlocks/$totalBlocks');
              }
            }
          }
          
          // Consider it in progress if we have batch/block info and not completed
          inProgress = (batchTotal != null && batchTotal > 0 && batchNum != null && batchNum <= batchTotal) || 
                      (totalBlocks != null && totalBlocks > 0 && syncedBlocks != null && syncedBlocks < totalBlocks);
          
          final parsedStatus = {
            'in_progress': inProgress,
            'batch_num': batchNum ?? 0,
            'batch_total': batchTotal ?? 0,
            'synced_blocks': syncedBlocks ?? 0,
            'total_blocks': totalBlocks ?? 0,
          };
          
          if (kDebugMode) {
            print('📊 Parsed sync status: $parsedStatus');
          }
          
          return parsedStatus;
        } else {
          if (kDebugMode) {
            print('   Status does not contain batch/blocks info');
          }
        }
      }
      
      // Default response if we can't parse
      return {
        'in_progress': false,
        'batch_num': 0,
        'batch_total': 0,
        'synced_blocks': 0,
        'total_blocks': 0,
      };
    } catch (e) {
      if (kDebugMode) print('❌ Failed to get sync status: $e');
      // On error (including timeout), assume sync is complete to prevent infinite polling
      return {
        'in_progress': false,
        'timeout': true,
        'batch_num': 0,
        'batch_total': 0,
        'synced_blocks': 0,
        'total_blocks': 0,
      };
    }
  }
  
  /// Dispose and cleanup
  Future<void> dispose() async {
    stopTimers();
    
    if (_initialized) {
      await rust_api.deinitialize();
      _initialized = false;
    }
  }
}