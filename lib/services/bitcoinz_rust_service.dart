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
import '../utils/logger.dart';

/// Pending transaction data for tracking change amounts
class PendingTransaction {
  final DateTime sentTime;
  final double totalSpent;
  final double changeAmount;
  
  PendingTransaction({
    required this.sentTime,
    required this.totalSpent,
    required this.changeAmount,
  });
}

class BitcoinzRustService {
  static BitcoinzRustService? _instance;
  static BitcoinzRustService get instance {
    if (_instance == null) {
      _instance = BitcoinzRustService._();
      Logger.rust('Creating new BitcoinzRustService singleton instance');
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
  
  // Balance fetch caching for log reduction
  DateTime? _lastBalanceFetch;
  String? _lastBalanceHash;
  static const Duration _balanceCacheTimeout = Duration(seconds: 10);
  
  // Transaction fetch caching for log reduction
  DateTime? _lastTransactionFetch;
  String? _lastTransactionHash;
  static const Duration _transactionCacheTimeout = Duration(seconds: 15);
  
  // Pending transaction tracking (like BitcoinZ Blue)
  final Map<String, PendingTransaction> _pendingTransactions = {};
  static const Duration _pendingTimeout = Duration(seconds: 60); // 1 minute timeout
  
  // Update throttling
  bool _isUpdating = false;
  DateTime? _lastUpdateTime;
  static const Duration _minUpdateInterval = Duration(seconds: 2);
  
  // Sync state tracking to prevent interruption
  bool _isSyncing = false;
  
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
      Logger.rust('Initialize called - serverUri: $serverUri, createNew: $createNew, birthdayHeight: $birthdayHeight, platform: ${Platform.operatingSystem}');
      
      Logger.rust('Initializing Rust Bridge - Platform: ${Platform.isAndroid ? "Android" : Platform.isMacOS ? "macOS" : "Other"}');
      
      // Check if bridge is already initialized (done in main.dart)
      if (!_bridgeInitialized) {
        try {
          Logger.rust('ANDROID: Attempting to load Rust native library...');
          await RustLib.init();
          _bridgeInitialized = true;
          Logger.rust('Rust bridge initialized successfully on Android');
        } catch (e) {
          // Bridge might already be initialized from main.dart
          if (e.toString().contains('Should not initialize flutter_rust_bridge twice')) {
            _bridgeInitialized = true;
            Logger.rust('Rust bridge already initialized');
          } else {
            if (kDebugMode) {
              Logger.rust('ANDROID: Failed to load Rust library - native .so files may not be loading', level: LogLevel.error);
            }
            rethrow;
          }
        }
      } else {
        Logger.rust('Rust bridge already initialized, skipping');
      }
      
      // Get the wallet data directory for Black Amber (where wallet.dat will be stored)
      // This ensures we don't use BitcoinZ Blue's wallet directory
      String? walletDirPath;
      try {
        final walletDir = await WalletStorageService.getWalletDataDirectory();
        walletDirPath = walletDir.path;
        if (kDebugMode) {
          Logger.rust('Using Black Amber wallet directory: $walletDirPath');
          
          // Check if wallet.dat already exists
          final walletFile = File('$walletDirPath/wallet.dat');
          if (await walletFile.exists()) {
            final stat = await walletFile.stat();
            Logger.rust('Found existing wallet.dat - Size: ${stat.size} bytes, Modified: ${stat.modified}');
          } else {
            Logger.rust('No existing wallet.dat found, will create new or restore');
          }
        }
      } catch (e) {
        Logger.rust('Failed to get wallet directory, using default', level: LogLevel.warning);
        walletDirPath = null;
      }
      
      // Initialize wallet
      if (createNew) {
        // Create new wallet
        if (kDebugMode) {
          Logger.rust('Creating new wallet via Rust - Server: $serverUri, Directory: ${walletDirPath ?? "default"}');
        }
        
        // Use Black Amber's wallet directory to avoid conflicts with BitcoinZ Blue
        Logger.rust('Creating wallet in: ${walletDirPath ?? "default"}');
        
        String result;
        try {
          result = await rust_api.initializeNewWithInfo(
            serverUri: serverUri,
            walletDir: walletDirPath, // Use Black Amber directory
          );
        } catch (e) {
          if (kDebugMode) {
            Logger.rust('Exception calling initializeNewWithInfo: $e', level: LogLevel.error);
          }
          return false;
        }
        
        if (result.startsWith('Error:')) {
          Logger.rust('Failed to create wallet: $result', level: LogLevel.error);
          return false;
        }
        
        // Parse JSON response to get seed and birthday
        try {
          
          // The response structure is:
          // {"seed": "{\"seed\":\"actual words here\",\"birthday\":1612745}", "birthday": 1612745, "latest_block": 1612845}
          // We need to handle this double-nested structure
          
          // First, find the actual seed phrase using a more robust regex
          // Look for the innermost seed value (the actual words)
          final innerSeedMatch = RegExp(r'\\"seed\\":\\"([^"\\]+)\\"').firstMatch(result);
          if (innerSeedMatch != null) {
            _seedPhrase = innerSeedMatch.group(1)!;
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
            Logger.info('New wallet created', category: 'rust');
            print('   Seed phrase: ${_seedPhrase!.split(' ').length} words');
            print('   Birthday block: $_birthday');
          }
        } catch (e) {
          if (kDebugMode) {
            Logger.error('Failed to parse wallet creation response: $e', category: 'rust');
            print('   Error type: ${e.runtimeType}');
            print('   Stack trace:');
            print(StackTrace.current);
          }
          return false;
        }
      } else if (seedPhrase != null) {
        // Restore from seed
        Logger.debug('Restoring wallet from seed...', category: 'rust');
        
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
          
          // Use the full function with wallet directory with timeout
          // Initializing from phrase
          // Parameters set for initialization
          print('   serverUri: $serverUri');
          print('   seedPhrase length: ${seedPhrase.length}');
          print('   birthday: ${BigInt.from(birthdayToUse)}');
          print('   overwrite: true');
          print('   walletDir: $walletDirPath');
          
          result = await rust_api.initializeFromPhrase(
            serverUri: serverUri,
            seedPhrase: seedPhrase,
            birthday: BigInt.from(birthdayToUse), // Use provided birthday or 0
            overwrite: true, // Overwrite if exists
            walletDir: walletDirPath,
          ).timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              if (kDebugMode) print('⏱️ Wallet restore timed out after 30 seconds');
              // FFI call timed out
              return 'Error: Wallet restore timed out';
            },
          );
          
          // Initialization result received
        } catch (e) {
          if (kDebugMode) print('⚠️ Restore with custom directory failed: $e');
          return false;
        }
        
        if (result.contains('Cannot create a new wallet from seed, because a wallet already exists')) {
          if (kDebugMode) print('⚠️ Existing wallet detected, attempting to deinitialize and retry...');
          
          // Deinitialize existing wallet first
          try {
            final deinitResult = await rust_api.deinitialize();
            if (kDebugMode) print('🔄 Deinitialize result: $deinitResult');
          } catch (e) {
            if (kDebugMode) print('⚠️ Deinitialize failed: $e');
          }
          
          // Try restoration again
          try {
            result = await rust_api.initializeFromPhrase(
              serverUri: serverUri,
              seedPhrase: seedPhrase,
              birthday: BigInt.from(birthdayHeight ?? 0),
              overwrite: true,
              walletDir: walletDirPath,
            ).timeout(
              const Duration(seconds: 30),
              onTimeout: () => 'Error: Wallet restore timed out',
            );
            
            // Retry attempt completed
          } catch (e) {
            if (kDebugMode) print('❌ Retry restoration failed: $e');
            return false;
          }
        }
        
        if (result != 'OK' && !result.contains('seed') && !result.contains('Cannot create')) {
          if (kDebugMode) print('❌ Failed to restore wallet: $result');
          return false;
        }
        _seedPhrase = seedPhrase;
        _birthday = birthdayHeight ?? 0; // Store the birthday height
        Logger.info('Wallet restored with birthday: ${birthdayHeight ?? 0}', category: 'rust');
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
        
        Logger.info('Existing wallet loaded', category: 'rust');
      }
      
      _initialized = true;
      
      if (kDebugMode) {
        Logger.info('Rust service marked as initialized', category: 'rust');
        print('   Seed available: ${_seedPhrase != null}');
        print('   Birthday: $_birthday');
      }
      
      // Initialize progress stream for real-time updates
      final streamInitialized = await initializeProgressStream();
      if (kDebugMode) print('📤 Progress stream initialized: $streamInitialized');
      
      // Start update timers (like BitcoinZ Blue)
      startTimers();
      
      // Initial sync - don't await for genesis sync as it takes too long
      // The sync will continue in background and UI will show progress
      if (_birthday == 0) {
        if (kDebugMode) print('🌍 Genesis sync - starting in background (not awaiting)...');
        sync(); // Start without await - let it run in background
      } else {
        // For non-genesis, await the sync as it's quick
        await sync();
      }
      
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
    
    Logger.debug('Full refresh via Rust...', category: 'rust');
    
    try {
      // Decide if we actually need a sync before calling it
      bool needsSync = false;
      try {
        final statusStr = await Future<String>(() => rust_api.getSyncStatus()).timeout(
          const Duration(seconds: 5),
          onTimeout: () => '{}',
        );
        if (statusStr.isNotEmpty && statusStr != '{}') {
          final data = jsonDecode(statusStr) as Map<String, dynamic>;
          final inProgress = data['in_progress'] == true;
          final total = (data['total_blocks'] ?? 0) as int;
          final synced = (data['synced_blocks'] ?? 0) as int;
          needsSync = inProgress || (total > 0 && synced < total);
        }
      } catch (_) {
        // If status fails, be conservative and do not force sync immediately
      }

      if (needsSync && !_isSyncing) {
        await sync();
      } else if (kDebugMode) {
        print('⏭️ refresh(): No sync needed now (inProgress=$_isSyncing / needsSync=$needsSync)');
      }

      // Fetch all data in parallel for better performance
      await Future.wait([
        fetchBalance(),
        fetchTransactions(),
        fetchAddresses(),
      ]);

      // Save wallet
      await save();

      Logger.debug('Full refresh complete', category: 'rust');
    } catch (e) {
      if (kDebugMode) print('❌ Full refresh failed: $e');
    }
  }
  
  /// Sync with network
  Future<void> sync() async {
    if (!_initialized) return;
    
    // Prevent concurrent syncs
    if (_isSyncing) {
      if (kDebugMode) print('⏭️ Sync already in progress, skipping...');
      return;
    }
    
    _isSyncing = true;
    
    try {
      Logger.debug('Syncing with network via Rust...', category: 'rust');
      // For full sync from genesis (birthday 0), we need much longer timeout
      // Regular sync: 15 seconds, Genesis sync: no timeout (let it complete)
      final isGenesisSync = _birthday == 0;
      
      if (isGenesisSync) {
        // No timeout for genesis sync - let it complete fully
        if (kDebugMode) print('🌍 Genesis sync detected - no timeout, this may take a while...');
        final result = await rust_api.execute(command: 'sync', args: '');
        if (kDebugMode) print('Sync result: ${result.substring(0, math.min(100, result.length))}...');
      } else {
        // Regular sync with timeout
        final result = await rust_api.execute(command: 'sync', args: '').timeout(
          const Duration(seconds: 15),
          onTimeout: () {
            if (kDebugMode) print('⏱️ Sync command timed out after 15 seconds');
            return '{"status": "timeout"}';
          },
        );
        if (kDebugMode) print('Sync result: ${result.substring(0, math.min(100, result.length))}...');
      }
    } catch (e) {
      if (kDebugMode) print('❌ Sync failed: $e');
    } finally {
      _isSyncing = false;
      // Save wallet after sync to persist state
      await save();
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
    
    // Debug logging reduced for performance
    
    try {
      // Debug logging reduced for performance
      // Add timeout to prevent hanging
      final balanceJson = await rust_api.execute(command: 'balance', args: '').timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          if (kDebugMode) print('⏱️ fetchBalance: Timeout after 10 seconds');
          return '{"tbalance": 0, "zbalance": 0}'; // Return empty balance on timeout
        },
      );
      // Debug logging reduced for performance
      final data = jsonDecode(balanceJson);
      
      // Get current block height for confirmation calculations
      final currentBlockHeight = await getCurrentBlockHeight();
      if (kDebugMode) print('📊 Current block height for spendable calculation: $currentBlockHeight');
      
      // Check for unconfirmed transactions in mempool and calculate proper spendable amounts
      final txListJson = await rust_api.execute(command: 'list', args: '');
      var txListDecoded = jsonDecode(txListJson);
      
      // Check if response is an error
      if (txListDecoded is Map && txListDecoded.containsKey('error')) {
        if (kDebugMode) print('⚠️ Transaction list error in fetchBalance: ${txListDecoded['error']}');
        // Return empty list for transactions when error
        txListDecoded = [];
      }
      
      final txList = txListDecoded as List;
      
      // Debug: Log first transaction only when needed for specific debugging
      // Commented out to reduce log spam in production
      // if (kDebugMode && txList.isNotEmpty) {
      //   print('🔍 First transaction data:');
      //   print('   Full tx: ${txList.first}');
      //   print('   unconfirmed field: ${txList.first['unconfirmed']}');
      //   print('   block_height field: ${txList.first['block_height']}');
      // }
      
      // TRUST the Rust backend's spendable amounts - they know the complex wallet state
      double rustSpendableTransparent = (data['spendable_tbalance'] ?? 0) / 100000000.0;
      double rustSpendableShielded = (data['spendable_zbalance'] ?? 0) / 100000000.0;
      
      // Debug logging reduced for performance
      
      // Get total balances for display
      double totalTransparent = (data['tbalance'] ?? 0) / 100000000.0;
      double totalShielded = (data['zbalance'] ?? 0) / 100000000.0;
      
      // Debug logging reduced for performance
      
      // Calculate unconfirmed amounts - separate incoming vs change
      double pureIncomingBalance = 0;      // Only from others
      double pureIncomingTransparent = 0;
      double pureIncomingShielded = 0;
      double changeBalance = 0;            // Our change returning  
      double changeTransparent = 0;
      double changeShielded = 0;
      
      // Track transactions that are confirmed but not yet spendable
      // We need to analyze ALL transactions, not just unconfirmed ones
      
      for (final tx in txList) {
        final amount = (tx['amount'] ?? 0).abs() / 100000000.0;
        final address = tx['address'] as String?;
        final bool isTransparent = address != null && (address.startsWith('t1') || address.startsWith('t3'));
        final bool isIncoming = tx['outgoing_metadata'] == null;
        
        // Get confirmation status
        final bool isUnconfirmed = tx['unconfirmed'] == true || 
                                   tx['block_height'] == null || 
                                   tx['block_height'] == 0;
        
        // Debug logging reduced for performance
        
        // Only track transactions that aren't fully spendable yet
        // This includes both unconfirmed AND confirmed-but-not-enough-confirmations
        if (isUnconfirmed) {
          if (isIncoming) {
            // This is truly incoming from someone else - unconfirmed
            pureIncomingBalance += amount;
            if (isTransparent) {
              pureIncomingTransparent += amount;
            } else {
              pureIncomingShielded += amount;
            }
          } else {
            // This is our change returning from sent transactions - unconfirmed
            changeBalance += amount;
            if (isTransparent) {
              changeTransparent += amount;
            } else {
              changeShielded += amount;
            }
          }
        }
      }
      
      // Verbose balance breakdown logging removed to reduce log spam
      // Enable only for specific balance debugging if needed
      
      // Use native Rust spendable amounts directly - no manual tracking needed
      // The Rust backend handles all the complexity of change detection properly
      double actualSpendableTransparent = rustSpendableTransparent;
      double actualSpendableShielded = rustSpendableShielded;
      
      // SIMPLIFIED APPROACH: Only track actual unconfirmed transactions
      // Don't try to calculate change from balance differences - trust the transaction list
      final totalBalance = ((data['tbalance'] ?? 0) + (data['zbalance'] ?? 0)) / 100000000.0;
      final totalT = (data['tbalance'] ?? 0) / 100000000.0;
      final totalZ = (data['zbalance'] ?? 0) / 100000000.0;
      final totalSpendable = rustSpendableTransparent + rustSpendableShielded;

      // CORRECT LOGIC: Separate real incoming from change properly
      final totalNonSpendable = totalBalance - totalSpendable;
      
      // Change returning = non-spendable funds MINUS actual incoming transactions
      final actualChangeBalance = totalNonSpendable - pureIncomingBalance;
      
      // Handle edge case: if all non-spendable funds are incoming, no change
      if (actualChangeBalance < 0) {
        // All non-spendable funds are incoming, no change returning
        changeBalance = 0;
        changeTransparent = 0;
        changeShielded = 0;
        
        // Adjust incoming to match actual non-spendable amount
        pureIncomingBalance = totalNonSpendable;
        // Distribute proportionally between T and Z based on the balance composition
        if (totalBalance > 0) {
          pureIncomingTransparent = totalNonSpendable * (totalT / totalBalance);
          pureIncomingShielded = totalNonSpendable * (totalZ / totalBalance);
        }
      } else {
        // Normal case: both incoming and change exist
        changeBalance = actualChangeBalance;
        // Distribute change proportionally between T and Z
        if (totalBalance > 0) {
          changeTransparent = actualChangeBalance * (totalT / totalBalance);
          changeShielded = actualChangeBalance * (totalZ / totalBalance);
        }
      }
      
      // Debug logging reduced for performance

      // Debug logging reduced for performance
      
      final balance = BalanceModel(
        transparent: totalT,
        shielded: totalZ,
        total: totalBalance,
        unconfirmed: pureIncomingBalance + changeBalance,  // TOTAL unconfirmed (incoming + change)
        unconfirmedTransparent: pureIncomingTransparent + changeTransparent,
        unconfirmedShielded: pureIncomingShielded + changeShielded,
        // Verified balance fields (funds with sufficient confirmations)
        verifiedTransparent: (data['verified_tbalance'] ?? data['tbalance'] ?? 0) / 100000000.0,
        verifiedShielded: (data['verified_zbalance'] ?? data['zbalance'] ?? 0) / 100000000.0,
        // Unverified balance fields (actual change returning from sends)
        // Only use what we found in unconfirmed transactions, not calculated amounts
        unverifiedTransparent: changeTransparent,
        unverifiedShielded: changeShielded,
        // Spendable balance fields (funds available for spending)
        // Use native Rust spendable calculations (BitcoinZ Blue approach)
        // Transparent: 1+ confirmations, Shielded: 2+ confirmations
        spendableTransparent: actualSpendableTransparent,
        spendableShielded: actualSpendableShielded,
        // Pending change: Use 0 since we use native unverified field instead
        pendingChange: 0,
      );
      
      // Create hash for change detection after balance is created
      final balanceHash = '${balance.total}_${balance.transparent}_${balance.shielded}';
      final balanceChanged = _lastBalanceHash != balanceHash;
      
      // Update cache
      _lastBalanceFetch = DateTime.now();
      _lastBalanceHash = balanceHash;
      
      // Only log if balance changed or first fetch
      if (balanceChanged || _lastBalanceFetch == null) {
        Logger.rust('Balance fetch completed');
      }
      
      // Validation: Ensure spendable never exceeds total
      final calculatedSpendable = actualSpendableTransparent + actualSpendableShielded;
      
      if (calculatedSpendable > totalBalance) {
        Logger.error('VALIDATION ERROR: Spendable ($calculatedSpendable) > Total ($totalBalance). This should never happen! Using total balance as max spendable.', category: 'rust');
        // Cap spendable at total balance and proportionally reduce each type
        final ratio = totalBalance / calculatedSpendable;
        actualSpendableTransparent *= ratio;
        actualSpendableShielded *= ratio;
      }
      
      // Debug logging reduced for performance
      
      fnSetTotalBalance?.call(balance);
      
      // Only log success if balance actually changed
      if (balanceChanged || _lastBalanceFetch == null) {
        Logger.debug('Balance fetched successfully', category: 'rust');
      }
    } catch (e) {
      Logger.error('Fetch balance failed: $e', category: 'rust');
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
      
      Logger.debug('Info response keys: ${info.keys.toList()}', category: 'rust');
      Logger.debug('Full info: $info', category: 'rust');
      
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
          Logger.debug('Current block height: $_currentBlockHeight (from field: ${info.keys.where((k) => info[k] == heightValue).first})', category: 'rust');
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
    
    // Debug logging reduced for performance
    
    try {
      // Add timeout to prevent infinite loading
      // Debug logging reduced for performance
      final txListJson = await rust_api.execute(command: 'list', args: '').timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          if (kDebugMode) print('⏱️ fetchTransactions: Timeout after 10 seconds');
          return '[]'; // Return empty array on timeout
        },
      );
      
      // Debug logging reduced for performance
      final txListDecoded = jsonDecode(txListJson);
      
      // Check if response is an error
      if (txListDecoded is Map && txListDecoded.containsKey('error')) {
        if (kDebugMode) print('⚠️ Transaction list error in fetchTransactions: ${txListDecoded['error']}');
        return;
      }
      
      final txList = txListDecoded as List;
      
      // Create hash for transaction deduplication
      final txHash = '${txList.length}_${txList.take(3).map((tx) => tx['txid']).join('_')}';
      final txChanged = _lastTransactionHash != txHash;
      
      // Update cache
      _lastTransactionFetch = DateTime.now();
      _lastTransactionHash = txHash;
      
      // Only log if transactions changed or first fetch
      if (txChanged || _lastTransactionFetch == null) {
        Logger.transaction('Fetched ${txList.length} transactions from Rust');
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
        // Debug logging reduced for performance
        
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
          // Verbose TX confirmation logging removed to reduce log spam
        } else {
          // Default to 1 if we can't calculate
          confirmations = 1;
          // TX confirmation calculation logging removed to reduce log spam
        }
        
        // Log unconfirmed transactions only when needed for debugging
        // Verbose logging removed to reduce log spam
        
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
      
      // Check for pending transactions that now appear in the transaction list
      if (_pendingTransactions.isNotEmpty) {
        final completedTxIds = <String>[];
        
        for (final transaction in transactions) {
          final txId = transaction.txid;
          if (_pendingTransactions.containsKey(txId)) {
            final pendingTx = _pendingTransactions[txId]!;
            
            // Check if the transaction has enough confirmations for change to be spendable
            // Transparent change: 1 confirmation, Shielded change: 2 confirmations
            bool changeIsSpendable = false;
            final confirmations = transaction.confirmations ?? 0;
            if (confirmations >= 1) {
              changeIsSpendable = true; // For now, assume transparent (most common)
              // TODO: Could enhance this to check address type for proper confirmation requirements
            }
            
            if (changeIsSpendable) {
              // This pending change is now spendable
              if (kDebugMode) {
                print('✅ PENDING CHANGE NOW SPENDABLE: $txId');
                print('   Change amount: ${pendingTx.changeAmount} BTCZ');
                print('   Confirmations: $confirmations');
                // Debug logging reduced for performance
              }
              completedTxIds.add(txId);
            } else {
              if (kDebugMode) {
                print('⏳ Pending change still needs confirmations: $txId ($confirmations confs, need 1+)');
              }
            }
          }
        }
        
        // Remove completed transactions from pending tracking
        for (final txId in completedTxIds) {
          _pendingTransactions.remove(txId);
        }
        
        if (completedTxIds.isNotEmpty && kDebugMode) {
          print('🧹 Removed ${completedTxIds.length} confirmed change transactions (${_pendingTransactions.length} still pending)');
        }
      }
      
      // Transaction count logging removed to reduce log spam
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
  
  /// Get send progress from Rust (legacy polling method - deprecated)
  Future<Map<String, dynamic>?> getSendProgress() async {
    if (!_initialized) return null;

    try {
      final result = await rust_api.execute(command: 'sendprogress', args: '');

      if (kDebugMode) {
        print('📤 RUST SENDPROGRESS RAW RESULT: $result');
        print('   Type: ${result.runtimeType}');
        print('   Length: ${result.length}');
      }

      final parsed = jsonDecode(result);

      if (kDebugMode) {
        print('📤 RUST SENDPROGRESS PARSED: $parsed');
      }

      return parsed;
    } catch (e) {
      if (kDebugMode) print('⚠️ Failed to get send progress: $e');
      return null;
    }
  }

  /// Initialize progress stream for push-based updates
  Future<bool> initializeProgressStream() async {
    if (!_initialized) return false;

    try {
      final result = await rust_api.initProgressStream();
      if (kDebugMode) print('📤 PROGRESS STREAM: Initialized - $result');
      return result == 'OK';
    } catch (e) {
      if (kDebugMode) print('⚠️ Failed to initialize progress stream: $e');
      return false;
    }
  }

  /// Listen to progress updates via new stream system
  Stream<Map<String, dynamic>> listenToProgressUpdates() async* {
    if (!_initialized) {
      if (kDebugMode) print('⚠️ Progress stream: Not initialized');
      return;
    }

    if (kDebugMode) print('📤 PROGRESS STREAM: Starting new stream system...');

    // Use the new stream-based progress system
    bool hasSeenSending = false;

    while (true) {
      try {
        // Get next progress update from the stream
        final progressJson = await rust_api.getNextProgressUpdate();
        if (kDebugMode) {
          print('📤 PROGRESS STREAM: Received: $progressJson');
        }

        try {
          final progressData = jsonDecode(progressJson) as Map<String, dynamic>;

          // Convert new format to old format for compatibility
          final status = progressData['status'] as String? ?? 'idle';
          final progress = progressData['progress'] as int? ?? 0;
          final total = progressData['total'] as int? ?? 100;
          final error = progressData['error'] as String?;
          final txid = progressData['txid'] as String?;

          // Determine if sending is in progress
          final isSending = status == 'sending' || status == 'processing';

          if (isSending) {
            hasSeenSending = true;
          }

          // Create compatible format for existing code
          final compatibleData = {
            'status': status,
            'progress': progress,
            'total': total,
            'error': error,
            'txid': txid,
            'sending': isSending, // For compatibility with existing logic
          };

          if (kDebugMode) {
            print('📤 PROGRESS STREAM: Converted: $compatibleData');
          }

          yield compatibleData;

          // End stream when transaction completes or fails
          if (status == 'completed' || status == 'error' ||
              (hasSeenSending && !isSending && (txid != null || error != null))) {
            if (kDebugMode) print('📤 PROGRESS STREAM: Transaction complete, ending stream');
            break;
          }

          // Small delay between stream polls
          await Future.delayed(const Duration(milliseconds: 200));

        } catch (e) {
          if (kDebugMode) print('⚠️ Failed to parse progress update: $e');
          await Future.delayed(const Duration(seconds: 1));
        }
      } catch (e) {
        if (kDebugMode) print('⚠️ Progress poll error: $e');
        await Future.delayed(const Duration(seconds: 1));
      }
    }

    if (kDebugMode) print('📤 PROGRESS STREAM: Stream ended');
  }

  /// Helper to compare maps for equality
  bool _mapsEqual(Map<String, dynamic> map1, Map<String, dynamic> map2) {
    if (map1.length != map2.length) return false;
    for (final key in map1.keys) {
      if (map1[key] != map2[key]) return false;
    }
    return true;
  }

  /// Send transaction
  Future<String?> sendTransaction(String address, double amount, String? memo) async {
    if (!_initialized) return null;
    
    try {
      if (kDebugMode) print('📤 Sending $amount BTCZ to $address via Rust...');
      
      // Get current balances before sending (for change calculation after send)
      double balanceBeforeSend = 0;
      try {
        final balanceJson = await rust_api.execute(command: 'balance', args: '');
        final balanceData = jsonDecode(balanceJson);
        balanceBeforeSend = ((balanceData['tbalance'] ?? 0) + (balanceData['zbalance'] ?? 0)) / 100000000.0;
        if (kDebugMode) print('📊 Total balance before send: $balanceBeforeSend BTCZ');
      } catch (e) {
        if (kDebugMode) print('⚠️ Could not get balance before send: $e');
      }
      
      // Convert BTCZ to zatoshis (1 BTCZ = 100,000,000 zatoshis)
      final zatoshis = (amount * 100000000).toInt();
      
      // Safely handle memo encoding for Android compatibility
      String safeMemo = '';
      if (memo != null && memo.trim().isNotEmpty) {
        // Trim and validate memo length (max 512 bytes for shielded)
        safeMemo = memo.trim();
        if (safeMemo.length > 512) {
          safeMemo = safeMemo.substring(0, 512);
          if (kDebugMode) print('⚠️ Memo truncated to 512 characters for Android compatibility');
        }
        
        // Escape special characters that could break command parsing
        safeMemo = safeMemo
            .replaceAll('"', '\\"')      // Escape quotes
            .replaceAll('\\', '\\\\')    // Escape backslashes
            .replaceAll('\n', '\\n')     // Escape newlines
            .replaceAll('\r', '\\r')     // Escape carriage returns
            .replaceAll('\t', '\\t');    // Escape tabs
        
        if (kDebugMode) {
          print('📝 Android memo processing:');
          print('   Original length: ${memo.length} chars');
          print('   Safe length: ${safeMemo.length} chars');
          print('   Has content: ${memo.isNotEmpty}');
        }
      }
      
      if (kDebugMode) print('🔧 Using dedicated sendTransaction API: address=$address, amount=$zatoshis, memo=${safeMemo.isEmpty ? "null" : "[REDACTED]"}');
      
      final result = await rust_api.sendTransaction(
        address: address,
        amount: zatoshis,
        memo: safeMemo.isEmpty ? null : safeMemo,
      );
      
      // Debug logging reduced for performance
      
      final data = jsonDecode(result);
      
      if (data['txid'] != null) {
        final txid = data['txid'] as String;
        if (kDebugMode) print('✅ Transaction sent via Rust: $txid');
        
        // Calculate REAL change by checking actual balance after send
        try {
          // Give a moment for the transaction to be processed
          await Future.delayed(const Duration(milliseconds: 500));
          
          final newBalanceJson = await rust_api.execute(command: 'balance', args: '');
          final newBalanceData = jsonDecode(newBalanceJson);
          final balanceAfterSend = ((newBalanceData['tbalance'] ?? 0) + (newBalanceData['zbalance'] ?? 0)) / 100000000.0;
          
          // Calculate actual change: what we had minus what we have now minus what we sent
          final actualChange = balanceBeforeSend - balanceAfterSend - amount;
          
          if (kDebugMode) {
            print('📊 REAL CHANGE CALCULATION:');
            print('   Balance before: $balanceBeforeSend BTCZ');
            print('   Balance after: $balanceAfterSend BTCZ');  
            print('   Amount sent: $amount BTCZ');
            print('   Actual change: $actualChange BTCZ');
          }
          
          // Only track positive change amounts (account for fees and floating point precision)
          if (actualChange > 0.00000001) {
            // Track the REAL change amount that needs confirmations
            _pendingTransactions[txid] = PendingTransaction(
              sentTime: DateTime.now(),
              totalSpent: amount + actualChange, // Total spent including change
              changeAmount: actualChange,        // Real change amount
            );
            
            if (kDebugMode) {
              // Debug logging reduced for performance
              Logger.transaction('Tracking real pending change: $actualChange BTCZ');
            }
          } else {
            if (kDebugMode) {
              // Debug logging reduced for performance
              print('   Calculated change: $actualChange BTCZ');
            }
          }
        } catch (e) {
          if (kDebugMode) {
            print('⚠️ Could not calculate real change: $e');
            print('   Will not track pending change for this transaction');
          }
        }
        
        // Force immediate refresh to pick up the new transaction
        Timer.run(() => refresh());
        
        return txid;
      } else if (data['error'] != null) {
        throw Exception(data['error']);
      }
      
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Send transaction failed: $e');
        if (Platform.isAndroid) {
          print('🤖 Android-specific troubleshooting:');
          print('   - Check memo encoding and special characters');
          print('   - Verify wallet sync status');
          print('   - Ensure sufficient balance for fees');
          print('   - Check if memo is within 512 character limit');
        }
      }
      
      // Provide more user-friendly error messages for common Android issues
      String errorMessage = e.toString();
      if (errorMessage.contains('insufficient') || errorMessage.contains('balance')) {
        throw Exception('Insufficient balance. Please check your available funds and try again.');
      } else if (errorMessage.contains('memo') || errorMessage.contains('invalid')) {
        throw Exception('Invalid memo format. Please check for special characters and try again.');
      } else if (errorMessage.contains('address') || errorMessage.contains('invalid')) {
        throw Exception('Invalid recipient address. Please verify the address and try again.');
      } else if (errorMessage.contains('sync') || errorMessage.contains('chain')) {
        throw Exception('Wallet not fully synced. Please wait for sync to complete and try again.');
      } else {
        // Generic error handling
        throw Exception('Transaction failed: ${errorMessage.replaceAll('Exception: ', '')}');
      }
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

  /// Get the actual sync state from the Rust service (more reliable than syncstatus command)
  bool get isActuallySyncing => _isSyncing;

  /// Get sync status for progress display
  Future<Map<String, dynamic>?> getSyncStatus() async {
    if (!_initialized) {
      if (kDebugMode) print('⚠️ getSyncStatus: Rust service not initialized');
      return null;
    }
    
    try {
      // Debug logging reduced for performance
      
      // Add timeout to prevent hanging on Android
      // Use shorter timeout on Android where syncstatus tends to hang
      // Slightly longer timeout on Android to reduce false "in_progress" from timeouts
      final timeout = Platform.isAndroid
          ? const Duration(seconds: 5)
          : const Duration(seconds: 5);
      
      // Use direct FRB binding instead of the generic 'execute' command to
      // avoid SSE/codec issues and improve reliability during restoration
      final statusStr = await Future<String>(() => rust_api.getSyncStatus()).timeout(
        const Duration(milliseconds: 1200),
        onTimeout: () {
          if (kDebugMode) print('⏱️ Syncstatus command timed out after 1.2s');
          // On timeout, keep UI responsive. Assume current local state but don't block.
          return _isSyncing
              ? '{"sync_id": 1, "in_progress": true}'
              : '{"sync_id": 1, "in_progress": false}';
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
          // Check for stuck finalization and force save
          await _checkForStuckFinalization(status);
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

  /// Get raw sync status string - may contain text format with real-time data
  Future<String?> getRawSyncStatus() async {
    try {
      // Try to get the raw status string directly (short timeout to avoid UI stalls)
      final statusStr = await Future<String>(() => rust_api.getSyncStatus())
          .timeout(const Duration(milliseconds: 1000), onTimeout: () => '');
      return statusStr;
    } catch (e) {
      if (kDebugMode) print('❌ Failed to get raw sync status: $e');
      return null;
    }
  }

  DateTime? _lastFinalizationTime;
  int _stuckFinalizationCount = 0;
  
  /// Check if sync is stuck in finalization and force save
  Future<void> _checkForStuckFinalization(Map<String, dynamic> syncData) async {
    try {
      final syncedBlocks = syncData['synced_blocks'] as int? ?? 0;
      final totalBlocks = syncData['total_blocks'] as int? ?? 0;
      final txnScanBlocks = syncData['txn_scan_blocks'] as int? ?? 0;
      
      // Check if we have a stuck finalization (blocks synced but txn scan incomplete)
      final isStuckFinalization = syncedBlocks == totalBlocks && 
                                  totalBlocks > 0 && 
                                  txnScanBlocks < totalBlocks &&
                                  (totalBlocks - txnScanBlocks) <= 5; // Within 5 transactions of completion
      
      if (isStuckFinalization) {
        final now = DateTime.now();
        if (_lastFinalizationTime == null) {
          _lastFinalizationTime = now;
          _stuckFinalizationCount = 1;
          if (kDebugMode) print('🚨 Detected stuck finalization - starting timer');
        } else {
          final timeSinceStuck = now.difference(_lastFinalizationTime!).inSeconds;
          _stuckFinalizationCount++;
          
          if (kDebugMode) print('🚨 Stuck finalization: ${timeSinceStuck}s, count: $_stuckFinalizationCount');
          
          // If stuck for more than 30 seconds, force save
          if (timeSinceStuck > 30) {
            if (kDebugMode) print('🔧 FORCING SAVE due to stuck finalization');
            await _forceSave();
            _lastFinalizationTime = null; // Reset timer
            _stuckFinalizationCount = 0;
          }
        }
      } else {
        // Reset if not stuck
        _lastFinalizationTime = null;
        _stuckFinalizationCount = 0;
      }
    } catch (e) {
      if (kDebugMode) print('❌ Error checking stuck finalization: $e');
    }
  }
  
  /// Force save wallet data
  Future<void> _forceSave() async {
    try {
      if (kDebugMode) print('💾 Force saving wallet...');
      final result = await rust_api.execute(command: 'save', args: '');
      if (kDebugMode) print('💾 Force save result: $result');
    } catch (e) {
      if (kDebugMode) print('❌ Force save failed: $e');
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