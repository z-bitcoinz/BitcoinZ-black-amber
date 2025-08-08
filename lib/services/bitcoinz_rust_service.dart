/// BitcoinZ Rust Service - Uses native Rust library for unconfirmed transactions
/// This service uses the Rust FFI bridge to access zecwalletlitelib
/// which properly monitors the mempool for unconfirmed transactions

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/balance_model.dart';
import '../models/transaction_model.dart';
import '../src/rust/api.dart' as rust_api;
import '../src/rust/frb_generated.dart';

class BitcoinzRustService {
  static BitcoinzRustService? _instance;
  static BitcoinzRustService get instance => _instance ??= BitcoinzRustService._();
  
  BitcoinzRustService._();
  
  bool _initialized = false;
  static bool _bridgeInitialized = false;
  String? _seedPhrase;
  
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
  
  // Blockchain info caching
  int? _currentBlockHeight;
  DateTime? _blockHeightLastFetch;
  static const Duration _blockHeightCacheDuration = Duration(seconds: 30);
  
  /// Initialize the Rust bridge and wallet
  Future<bool> initialize({
    required String serverUri,
    String? seedPhrase,
    bool createNew = false,
  }) async {
    try {
      if (kDebugMode) print('🚀 Initializing Rust Bridge...');
      
      // Check if bridge is already initialized (done in main.dart)
      if (!_bridgeInitialized) {
        try {
          await RustLib.init();
          _bridgeInitialized = true;
          if (kDebugMode) print('✅ Rust bridge initialized');
        } catch (e) {
          // Bridge might already be initialized from main.dart
          if (e.toString().contains('Should not initialize flutter_rust_bridge twice')) {
            _bridgeInitialized = true;
            if (kDebugMode) print('✅ Rust bridge already initialized');
          } else {
            rethrow;
          }
        }
      } else {
        if (kDebugMode) print('✅ Rust bridge already initialized, skipping');
      }
      
      // Initialize wallet
      if (createNew) {
        // Create new wallet
        if (kDebugMode) print('📝 Creating new wallet...');
        _seedPhrase = await rust_api.initializeNew(serverUri: serverUri);
        
        if (_seedPhrase?.startsWith('Error:') ?? true) {
          if (kDebugMode) print('❌ Failed to create wallet: $_seedPhrase');
          return false;
        }
        if (kDebugMode) print('✅ New wallet created');
      } else if (seedPhrase != null) {
        // Restore from seed
        if (kDebugMode) print('🔄 Restoring wallet from seed...');
        final result = await rust_api.initializeFromPhrase(
          serverUri: serverUri,
          seedPhrase: seedPhrase,
          birthday: BigInt.zero, // Start from genesis
          overwrite: true,
        );
        
        if (result != 'OK' && !result.contains('seed')) {
          if (kDebugMode) print('❌ Failed to restore wallet: $result');
          return false;
        }
        _seedPhrase = seedPhrase;
        if (kDebugMode) print('✅ Wallet restored');
      } else {
        // Load existing wallet
        if (kDebugMode) print('📂 Loading existing wallet...');
        final result = await rust_api.initializeExisting(serverUri: serverUri);
        
        if (result != 'OK' && !result.contains('success')) {
          if (kDebugMode) print('❌ Failed to load existing wallet: $result');
          return false;
        }
        if (kDebugMode) print('✅ Existing wallet loaded');
      }
      
      _initialized = true;
      
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
  
  /// Start update timers (EXACT copy of BitcoinZ Blue)
  void startTimers() {
    if (kDebugMode) print('⏱️ Starting update timers...');
    
    // 60-second refresh timer
    refreshTimerID ??= Timer.periodic(const Duration(seconds: 60), (_) {
      refresh();
    });
    
    // 1-second update timer for fast change detection
    updateTimerId ??= Timer.periodic(const Duration(seconds: 1), (_) {
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
  
  /// Fast update - runs every 1 second
  Future<void> updateData() async {
    if (!_initialized) return;
    
    try {
      // Get transaction list
      final txListJson = await rust_api.execute(command: 'list', args: '');
      final txList = jsonDecode(txListJson) as List;
      
      // Get latest txid
      final latestTxid = txList.isNotEmpty ? txList[0]['txid'] : '';
      
      // Get balance
      final balanceJson = await rust_api.execute(command: 'balance', args: '');
      final balanceData = jsonDecode(balanceJson);
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
        
        // Fetch all data
        await fetchBalance();
        await fetchTransactions();
        await fetchAddresses();
      }
    } catch (e) {
      if (kDebugMode) print('❌ Update data failed: $e');
    }
  }
  
  /// Full refresh - runs every 60 seconds
  Future<void> refresh() async {
    if (!_initialized) return;
    
    if (kDebugMode) print('🔄 Full refresh via Rust...');
    
    try {
      // Sync with network
      await sync();
      
      // Fetch all data
      await fetchBalance();
      await fetchTransactions();
      await fetchAddresses();
      
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
      final result = await rust_api.execute(command: 'sync', args: '');
      if (kDebugMode) print('Sync result: $result');
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
    if (!_initialized) return;
    
    try {
      final balanceJson = await rust_api.execute(command: 'balance', args: '');
      final data = jsonDecode(balanceJson);
      
      if (kDebugMode) print('💰 Balance from Rust: $data');
      
      // Check for unconfirmed transactions in mempool
      final txListJson = await rust_api.execute(command: 'list', args: '');
      final txList = jsonDecode(txListJson) as List;
      
      double pendingBalance = 0;
      double pendingTransparent = 0;
      double pendingShielded = 0;
      
      for (final tx in txList) {
        if (tx['unconfirmed'] == true) {
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
    } catch (e) {
      if (kDebugMode) print('❌ Fetch balance failed: $e');
    }
  }
  
  /// Get current blockchain height (with caching)
  Future<int?> getCurrentBlockHeight() async {
    if (!_initialized) return null;
    
    // Check cache
    final now = DateTime.now();
    if (_currentBlockHeight != null && 
        _blockHeightLastFetch != null &&
        now.difference(_blockHeightLastFetch!).compareTo(_blockHeightCacheDuration) < 0) {
      return _currentBlockHeight;
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
          return _currentBlockHeight;
        }
      }
    } catch (e) {
      if (kDebugMode) print('❌ Failed to get block height: $e');
    }
    
    return _currentBlockHeight; // Return cached value if fetch fails
  }
  
  /// Fetch transactions
  Future<void> fetchTransactions() async {
    if (!_initialized) return;
    
    try {
      final txListJson = await rust_api.execute(command: 'list', args: '');
      final txList = jsonDecode(txListJson) as List;
      
      if (kDebugMode) {
        final unconfirmedCount = txList.where((tx) => tx['unconfirmed'] == true).length;
        print('📋 Transactions from Rust: ${txList.length} total, $unconfirmedCount unconfirmed');
      }
      
      // Get current block height for confirmation calculation
      final currentHeight = await getCurrentBlockHeight();
      
      final transactions = <TransactionModel>[];
      
      int index = 0;
      for (final tx in txList) {
        index++;
        
        // Debug log first transaction to see available fields
        if (kDebugMode && index == 1) {
          print('📋 First transaction fields: ${(tx as Map).keys.toList()}');
          print('📋 Transaction data sample: txid=${tx['txid']?.toString()?.substring(0, 8)}..., block_height=${tx['block_height']}, height=${tx['height']}, blockHeight=${tx['blockHeight']}');
        }
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
        
        if (tx['unconfirmed'] == true) {
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
        if (tx['unconfirmed'] == true) {
          if (kDebugMode) {
            print('🔄 UNCONFIRMED TX via Rust: ${tx['txid']} - $type $amount BTCZ');
          }
        }
        
        final transaction = TransactionModel(
          txid: tx['txid'] ?? '',
          type: type,
          amount: amount,
          blockHeight: blockHeight,
          fromAddress: type == 'received' ? address : null,
          toAddress: type == 'sent' ? address : null,
          timestamp: DateTime.fromMillisecondsSinceEpoch((tx['datetime'] ?? 0) * 1000),
          confirmations: confirmations,
          memo: tx['memo'],
          fee: type == 'sent' ? 0.0001 : 0.0,
        );
        
        transactions.add(transaction);
      }
      
      // Sort by timestamp (newest first)
      transactions.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      
      fnSetTransactionsList?.call(transactions);
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
  
  /// Get new address
  Future<String?> getNewAddress({bool transparent = true}) async {
    if (!_initialized) return null;
    
    try {
      final command = transparent ? 'new' : 'new z';
      final result = await rust_api.execute(command: command, args: '');
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
  
  /// Get seed phrase
  String? getSeedPhrase() => _seedPhrase;
  
  /// Dispose and cleanup
  Future<void> dispose() async {
    stopTimers();
    
    if (_initialized) {
      await rust_api.deinitialize();
      _initialized = false;
    }
  }
}