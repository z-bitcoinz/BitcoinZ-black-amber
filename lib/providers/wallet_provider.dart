import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:convert';
import '../models/wallet_model.dart';
import '../models/balance_model.dart';
import '../models/transaction_model.dart';
import '../models/address_model.dart';
import '../services/bitcoinz_service.dart';
import '../services/database_service.dart';
import '../services/bitcoinz_rust_service.dart';
import '../providers/auth_provider.dart';

class WalletProvider with ChangeNotifier {
  WalletModel? _wallet;
  BalanceModel _balance = BalanceModel.empty();
  List<TransactionModel> _transactions = [];
  bool _isLoading = false;
  bool _isSyncing = false;
  String? _error;
  Map<String, List<String>> _addresses = {'transparent': [], 'shielded': []};
  List<AddressModel> _addressModels = [];
  DateTime? _lastSyncTime;
  bool _isConnected = false;
  String _connectionStatus = 'Disconnected';
  DateTime? _lastConnectionCheck;
  Timer? _syncTimer;
  bool _autoSyncEnabled = true;
  
  // Pagination state
  int _currentPage = 0;
  static const int _pageSize = 50;
  bool _hasMoreTransactions = true;
  bool _isLoadingMore = false;
  String? _searchQuery;
  String? _filterType;
  
  // Block height caching for real confirmation calculation
  int? _cachedBlockHeight;
  DateTime? _blockHeightCacheTime;
  static const Duration _blockHeightCacheDuration = Duration(seconds: 30);
  
  final DatabaseService _databaseService = DatabaseService.instance;
  late final BitcoinzRustService _rustService; // Native Rust service with mempool monitoring
  
  // Constructor
  WalletProvider() {
    // Initialize Native Rust service with mempool monitoring
    _rustService = BitcoinzRustService.instance;
    _rustService.fnSetTotalBalance = (balance) {
      if (kDebugMode) print('🦀 Rust Bridge updated balance: ${balance.formattedTotal} BTCZ (unconfirmed: ${balance.unconfirmed})');
      _balance = balance;
      notifyListeners();
    };
    _rustService.fnSetTransactionsList = (transactions) {
      final unconfirmedCount = transactions.where((tx) => tx.confirmations == 0).length;
      if (kDebugMode) print('🦀 Rust Bridge updated transactions: ${transactions.length} txs ($unconfirmedCount unconfirmed)');
      _transactions = transactions;
      notifyListeners();
    };
    _rustService.fnSetAllAddresses = (addresses) {
      if (kDebugMode) {
        final tCount = addresses['transparent']?.length ?? 0;
        final sCount = addresses['shielded']?.length ?? 0;
        print('🦀 Rust Bridge updated addresses: ${tCount} transparent + ${sCount} shielded');
      }
      _addresses = addresses;
      notifyListeners();
    };
    _rustService.fnSetInfo = (info) {
      if (kDebugMode) print('🦀 Rust Bridge info: Block ${info['latestBlock']}');
    };
  }

  // Getters
  WalletModel? get wallet => _wallet;
  BalanceModel get balance => _balance;
  List<TransactionModel> get transactions => _transactions;
  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;
  String? get error => _error;
  Map<String, List<String>> get addresses => _addresses;
  List<AddressModel> get addressModels => _addressModels;
  bool get hasWallet => _wallet != null;
  DateTime? get lastSyncTime => _lastSyncTime;
  bool get isConnected => _isConnected;
  String get connectionStatus => _connectionStatus;
  DateTime? get lastConnectionCheck => _lastConnectionCheck;
  bool get autoSyncEnabled => _autoSyncEnabled;
  
  // Pagination getters
  bool get hasMoreTransactions => _hasMoreTransactions;
  bool get isLoadingMore => _isLoadingMore;
  int get currentPage => _currentPage;
  int get pageSize => _pageSize;
  String? get searchQuery => _searchQuery;
  String? get filterType => _filterType;

  // Mobile-optimized getters
  bool get isWalletInitialized => hasWallet;
  int get totalAddresses => _addresses['transparent']!.length + _addresses['shielded']!.length;
  bool get needsSync => _lastSyncTime == null || DateTime.now().difference(_lastSyncTime!).inMinutes > 5;

  /// Initialize or create wallet (mobile-first)
  Future<void> createWallet(String seedPhrase, {AuthProvider? authProvider}) async {
    _setLoading(true);
    _clearError();

    try {
      if (kDebugMode) {
        print('🏗️ WalletProvider.createWallet() starting...');
        print('  seedPhrase length: ${seedPhrase.split(' ').length} words');
        print('  authProvider provided: ${authProvider != null}');
      }
      
      final walletInfo = await BitcoinZService.instance.createWallet(seedPhrase);
      _wallet = walletInfo;
      await _refreshWalletData();
      await _checkConnection(); // Check connection after wallet creation
      
      if (kDebugMode) {
        print('📱 Wallet created successfully:');
        print('  walletId: ${walletInfo.walletId}');
        print('  transparent addresses: ${walletInfo.transparentAddresses.length}');
        print('  shielded addresses: ${walletInfo.shieldedAddresses.length}');
        if (walletInfo.shieldedAddresses.isNotEmpty) {
          print('  first shielded address: ${walletInfo.shieldedAddresses.first}');
        }
      }
      
      // Store wallet data persistently
      if (authProvider != null) {
        if (kDebugMode) print('💾 Calling authProvider.registerWallet()...');
        await authProvider.registerWallet(
          walletInfo.walletId,
          seedPhrase: seedPhrase,
          walletData: {
            'walletId': walletInfo.walletId,
            'transparentAddresses': walletInfo.transparentAddresses,
            'shieldedAddresses': walletInfo.shieldedAddresses,
            'createdAt': DateTime.now().toIso8601String(),
          },
        );
        if (kDebugMode) print('✅ Wallet storage completed!');
      } else {
        if (kDebugMode) print('⚠️ No authProvider - wallet will not persist!');
      }
      
      // Start auto-sync after wallet creation
      startAutoSync();
      
      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('❌ WalletProvider.createWallet() failed: $e');
      _setError('Failed to create wallet: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Restore wallet from seed phrase
  Future<void> restoreWallet(String seedPhrase, {int birthdayHeight = 0, AuthProvider? authProvider}) async {
    _setLoading(true);
    _clearError();

    try {
      final walletInfo = await BitcoinZService.instance.restoreWallet(
        seedPhrase,
        birthdayHeight: birthdayHeight,
      );
      _wallet = walletInfo;
      await _refreshWalletData();
      await _checkConnection(); // Check connection after wallet restoration
      
      // Store wallet data persistently
      if (authProvider != null) {
        await authProvider.registerWallet(
          walletInfo.walletId,
          seedPhrase: seedPhrase,
          walletData: {
            'walletId': walletInfo.walletId,
            'transparentAddresses': walletInfo.transparentAddresses,
            'shieldedAddresses': walletInfo.shieldedAddresses,
            'birthdayHeight': birthdayHeight,
            'restoredAt': DateTime.now().toIso8601String(),
          },
        );
      }
      
      // Start auto-sync after wallet restoration
      startAutoSync();
      
      notifyListeners();
    } catch (e) {
      _setError('Failed to restore wallet: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Load existing CLI wallet data
  Future<void> loadCliWallet(AuthProvider authProvider) async {
    if (!authProvider.hasWallet || !authProvider.cliWalletImported) return;
    
    _setLoading(true);
    _clearError();

    try {
      if (kDebugMode) {
        print('🔄 WalletProvider: Loading CLI wallet data...');
      }
      
      // Create a basic wallet model for CLI wallet FIRST (before checking connection)
      _wallet = WalletModel(
        walletId: authProvider.walletId ?? 'cli_wallet',
        transparentAddresses: [], // Will be populated by _refreshCliWalletData
        shieldedAddresses: [], // Will be populated by _refreshCliWalletData
      );
      
      // Get wallet data from CLI
      await _refreshCliWalletData();
      
      // Update wallet model with loaded addresses
      _wallet = WalletModel(
        walletId: _wallet!.walletId,
        transparentAddresses: _addresses['transparent'] ?? [],
        shieldedAddresses: _addresses['shielded'] ?? [],
      );
      
      // NOW check connection (after wallet is set)
      await _checkConnection();
      
      // Start auto-sync after loading CLI wallet
      startAutoSync();
      
      if (kDebugMode) {
        print('✅ CLI wallet loaded successfully');
        print('   Balance: ${_balance.total} BTCZ');
        print('   Addresses: ${totalAddresses}');
      }
      
      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('❌ Failed to load CLI wallet: $e');
      _setError('Failed to load CLI wallet: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Restore wallet from stored data
  Future<bool> restoreFromStoredData(AuthProvider authProvider) async {
    if (!authProvider.hasWallet || !authProvider.isAuthenticated) return false;
    
    // If this is a CLI wallet, use CLI loading instead
    if (authProvider.cliWalletImported) {
      await loadCliWallet(authProvider);
      return true;
    }
    
    _setLoading(true);
    _clearError();

    try {
      if (kDebugMode) {
        print('🔄 WalletProvider.restoreFromStoredData() starting...');
      }
      
      final seedPhrase = await authProvider.getStoredSeedPhrase();
      final walletData = await authProvider.getStoredWalletData();
      
      if (kDebugMode) {
        print('  seedPhrase found: ${seedPhrase != null}');
        print('  walletData found: ${walletData != null}');
        if (walletData != null) {
          print('  walletId: ${walletData['walletId']}');
          print('  transparent addresses: ${walletData['transparentAddresses']?.length ?? 0}');
          print('  shielded addresses: ${walletData['shieldedAddresses']?.length ?? 0}');
        }
      }
      
      if (seedPhrase != null && walletData != null) {
        // Recreate wallet from stored seed phrase
        final walletInfo = await BitcoinZService.instance.restoreWallet(
          seedPhrase,
          birthdayHeight: walletData['birthdayHeight'] ?? 0,
        );
        
        _wallet = walletInfo;
        
        // Use newly generated addresses from Rust backend (not old stored ones)
        _addresses['transparent'] = walletInfo.transparentAddresses;
        _addresses['shielded'] = walletInfo.shieldedAddresses;
        
        // Update stored wallet data with new correct addresses
        await authProvider.updateWalletData({
          'walletId': walletInfo.walletId,
          'transparentAddresses': walletInfo.transparentAddresses,
          'shieldedAddresses': walletInfo.shieldedAddresses,
          'birthdayHeight': walletData['birthdayHeight'] ?? 0,
          'createdAt': walletData['createdAt'] ?? DateTime.now().toIso8601String(),
          'updatedAt': DateTime.now().toIso8601String(),
        });
        
        if (kDebugMode) {
          print('✅ Wallet restored with regenerated addresses:');
          print('  transparent addresses: ${_addresses['transparent']!.length}');
          if (_addresses['transparent']!.isNotEmpty) {
            print('  first t-address: ${_addresses['transparent']!.first}');
            print('  t-address length: ${_addresses['transparent']!.first.length} chars');
          }
          print('  shielded addresses: ${_addresses['shielded']!.length}');
          if (_addresses['shielded']!.isNotEmpty) {
            print('  first z-address: ${_addresses['shielded']!.first}');
            print('  z-address length: ${_addresses['shielded']!.first.length} chars');
          }
        }
        
        // Initialize connection and sync
        await _checkConnection();
        await _refreshWalletData();
        
        // Start auto-sync after restoration
        startAutoSync();
        
        notifyListeners();
        return true;
      } else if (seedPhrase != null) {
        // Have seed phrase but no wallet data - recreate wallet
        if (kDebugMode) print('⚠️ Have seed phrase but no wallet data, recreating...');
        final walletInfo = await BitcoinZService.instance.createWallet(seedPhrase);
        _wallet = walletInfo;
        
        // Store the newly created wallet addresses
        _addresses['transparent'] = walletInfo.transparentAddresses;
        _addresses['shielded'] = walletInfo.shieldedAddresses;
        
        // Update stored wallet data
        await authProvider.updateWalletData({
          'walletId': walletInfo.walletId,
          'transparentAddresses': walletInfo.transparentAddresses,
          'shieldedAddresses': walletInfo.shieldedAddresses,
          'createdAt': DateTime.now().toIso8601String(),
        });
        
        await _checkConnection();
        await _refreshWalletData();
        startAutoSync();
        
        notifyListeners();
        return true;
      }
    } catch (e) {
      _setError('Failed to restore wallet from storage: $e');
    } finally {
      _setLoading(false);
    }
    
    return false;
  }
  
  /// Refresh wallet data with mobile-optimized handling
  Future<void> refreshWallet({bool force = false}) async {
    if (!hasWallet) return;
    
    // Skip if not forced and recently synced (mobile battery optimization)
    if (!force && !needsSync) return;
    
    _setLoading(true);
    _clearError();

    try {
      await _refreshWalletData();
      _lastSyncTime = DateTime.now();
    } catch (e) {
      _setError('Failed to refresh wallet: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Background sync for mobile (lighter operation)
  Future<void> syncWalletInBackground() async {
    if (!hasWallet || _isSyncing) return;

    _setSyncing(true);
    
    try {
      // Check if this is a CLI wallet
      if (_wallet?.walletId?.startsWith('cli_imported_') == true) {
        // For CLI wallets, just refresh the data from CLI
        await _loadCliBalance(); // Only load balance in background
      } else {
        // For Rust FFI wallets, use the original sync
        await BitcoinZService.instance.syncWallet();
        await _loadBalance(); // Only load balance in background
      }
      _lastSyncTime = DateTime.now();
    } catch (e) {
      // Don't show error for background sync failures
      debugPrint('Background sync failed: $e');
    } finally {
      _setSyncing(false);
    }
  }

  /// Full sync wallet with blockchain
  Future<void> syncWallet() async {
    if (!hasWallet) return;

    _setSyncing(true);
    _clearError();

    try {
      // Check if this is a CLI wallet
      if (_wallet?.walletId?.startsWith('cli_imported_') == true) {
        // For CLI wallets, refresh all data from CLI
        await _refreshCliWalletData();
      } else {
        // For Rust FFI wallets, use the original sync
        await BitcoinZService.instance.syncWallet();
        await _refreshWalletData();
      }
      _lastSyncTime = DateTime.now();
      await _checkConnection(); // Update connection status after sync
    } catch (e) {
      _setError('Failed to sync wallet: $e');
      _setConnectionStatus(false, 'Sync failed');
    } finally {
      _setSyncing(false);
    }
  }
  
  /// Check server connection status
  Future<void> _checkConnection() async {
    try {
      if (kDebugMode) {
        print('🔍 _checkConnection: walletId=${_wallet?.walletId}, isCliWallet=${_wallet?.walletId?.startsWith('cli_imported_')}');
      }
      
      // Check if this is a CLI wallet
      if (_wallet?.walletId?.startsWith('cli_imported_') == true) {
        // Initialize Rust bridge with existing wallet
        final rustInitialized = await _rustService.initialize(
          serverUri: 'https://lightd.btcz.rocks:9067',
          seedPhrase: null, // Will use existing wallet
          createNew: false,
        );
        if (rustInitialized) {
          _setConnectionStatus(true, 'Connected via CLI');
        } else {
          _setConnectionStatus(false, 'CLI unavailable');
        }
      } else {
        // For Rust FFI wallets, use the original logic
        final status = await BitcoinZService.instance.getSyncStatus();
        if (status != null && status.containsKey('is_syncing')) {
          _setConnectionStatus(true, 'Connected to server');
        } else {
          _setConnectionStatus(false, 'Server unreachable');
        }
      }
    } catch (e) {
      _setConnectionStatus(false, 'Connection error');
    }
  }
  
  /// Manually check connection status
  Future<void> checkConnectionStatus() async {
    await _checkConnection();
  }
  
  /// Set connection status
  void _setConnectionStatus(bool connected, String status) {
    _isConnected = connected;
    _connectionStatus = status;
    _lastConnectionCheck = DateTime.now();
    notifyListeners();
  }
  
  /// Start automatic syncing using BitcoinZ Blue's exact approach
  void startAutoSync() {
    if (_syncTimer?.isActive == true) return;
    
    _autoSyncEnabled = true;
    
    if (kDebugMode) {
      print('🦀 Starting Rust Bridge service with native mempool monitoring');
    }
    
    // Use Rust's dual timer system (1-second + 60-second)
    // Rust service auto-starts timers on initialization
    
    // Keep a backup timer for connection checks (less frequent)
    _syncTimer = Timer.periodic(const Duration(minutes: 10), (timer) async {
      if (hasWallet && _autoSyncEnabled) {
        try {
          if (kDebugMode) print('🔍 Running connection health check...');
          await _checkConnection(); // Ensure we're still connected
        } catch (e) {
          debugPrint('Connection check failed: $e');
        }
      }
    });
  }
  
  /// Stop automatic syncing
  void stopAutoSync() {
    _autoSyncEnabled = false;
    _syncTimer?.cancel();
    _syncTimer = null;
    _rustService.stopTimers(); // Stop the Rust service timers
    
    if (kDebugMode) {
      print('🛑 Stopped Rust Bridge service and fast mempool monitoring');
    }
  }
  
  /// Toggle automatic syncing
  void toggleAutoSync(bool enabled) {
    if (enabled) {
      startAutoSync();
    } else {
      stopAutoSync();
    }
  }

  /// Send transaction with mobile-optimized validation
  Future<String?> sendTransaction({
    required String toAddress,
    required double amount,
    String? memo,
  }) async {
    if (!hasWallet) {
      _setError('No wallet available');
      return null;
    }

    // Mobile-specific validation
    if (!_balance.hasSufficientBalance(amount)) {
      _setError('Insufficient balance');
      return null;
    }

    _setLoading(true);
    _clearError();

    try {
      String? txid;
      
      // Check if this is a CLI wallet
      if (_wallet?.walletId?.startsWith('cli_imported_') == true) {
        // For CLI wallets, use CLI service to send transactions
        if (kDebugMode) {
          print('📤 Sending via CLI: $amount BTCZ to $toAddress');
        }
        
        txid = await _rustService.sendTransaction(
          toAddress,
          amount,
          memo,
        );
        
        if (kDebugMode) {
          print('📤 Rust Send result: txid=$txid');
        }
        
        if (txid != null) {
          // Transaction sent successfully via Rust
          if (kDebugMode) {
            print('✅ Transaction sent via Rust! txid: $txid');
          }
        } else {
          throw Exception('Rust send failed');
        }
        
        // Quick refresh CLI data
        await _refreshCliWalletData();
        
        // Force immediate Rust Bridge refresh to detect the newly sent transaction
        if (kDebugMode) print('🦀 Forcing immediate Rust Bridge refresh after send...');
        
        // Give the wallet a moment to register the transaction
        await Future.delayed(const Duration(milliseconds: 500));
        
        // Rust service automatically triggers refresh after send
        
        // Also trigger the fast update detection immediately
        // Mempool monitoring will pick up the transaction immediately
      } else {
        // For Rust FFI wallets, use BitcoinZService
        final result = await BitcoinZService.instance.sendTransaction(
          toAddress: toAddress,
          amount: amount,
          memo: memo,
        );
        
        txid = result['txid'];
        
        // Quick refresh for mobile UX
        await _refreshWalletData();
      }
      
      return txid;
    } catch (e) {
      _setError('Failed to send transaction: $e');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Generate new address with type preference for mobile
  Future<String?> generateNewAddress([String? addressType]) async {
    if (!hasWallet) {
      _setError('No wallet available');
      return null;
    }

    // Default to transparent for mobile simplicity
    addressType ??= 'transparent';

    try {
      // Check if this is a CLI wallet
      if (_wallet?.walletId?.startsWith('cli_imported_') == true) {
        // CLI wallets can't generate new addresses dynamically, return existing one
        final existingAddresses = getAddressesOfType(addressType == 'shielded');
        if (existingAddresses.isNotEmpty) {
          // Return the first unused address or just the first one
          _setError('Using existing ${addressType} address from CLI wallet');
          return existingAddresses.first;
        } else {
          _setError('No ${addressType} addresses available in CLI wallet. Use CLI directly to generate new addresses.');
          return null;
        }
      } else {
        // For Rust FFI wallets, generate new address
        final address = await BitcoinZService.instance.generateNewAddress(addressType);
        await _loadAddresses(); // Refresh addresses
        return address;
      }
    } catch (e) {
      _setError('Failed to generate new address: $e');
      return null;
    }
  }

  /// Get primary receiving address (mobile-optimized)
  String? get primaryReceivingAddress {
    if (_addresses['transparent']!.isNotEmpty) {
      return _addresses['transparent']!.first;
    }
    if (_addresses['shielded']!.isNotEmpty) {
      return _addresses['shielded']!.first;
    }
    return null;
  }

  /// Get current address (alias for primaryReceivingAddress for compatibility)
  String? get currentAddress => primaryReceivingAddress;
  
  /// Get address by type preference
  String? getAddressByType(bool isShielded) {
    if (isShielded) {
      return _addresses['shielded']!.isNotEmpty ? _addresses['shielded']!.first : null;
    } else {
      return _addresses['transparent']!.isNotEmpty ? _addresses['transparent']!.first : null;
    }
  }
  
  /// Get all addresses of specific type
  List<String> getAddressesOfType(bool isShielded) {
    return isShielded ? _addresses['shielded']! : _addresses['transparent']!;
  }

  /// Refresh transactions only (lighter operation)
  Future<void> refreshTransactions() async {
    if (!hasWallet) return;

    try {
      await _loadTransactions();
      notifyListeners();
    } catch (e) {
      _setError('Failed to refresh transactions: $e');
    }
  }

  /// Get sync status with mobile-friendly formatting
  Future<Map<String, dynamic>?> getSyncStatus() async {
    if (!hasWallet) return null;

    try {
      final status = await BitcoinZService.instance.getSyncStatus();
      return status;
    } catch (e) {
      _setError('Failed to get sync status: $e');
      return null;
    }
  }

  /// Encrypt message for z-address
  Future<String?> encryptMessage(String zAddress, String message) async {
    if (!hasWallet) {
      _setError('No wallet available');
      return null;
    }

    try {
      return await BitcoinZService.instance.encryptMessage(zAddress, message);
    } catch (e) {
      _setError('Failed to encrypt message: $e');
      return null;
    }
  }

  /// Decrypt message
  Future<String?> decryptMessage(String encryptedData) async {
    if (!hasWallet) {
      _setError('No wallet available');
      return null;
    }

    try {
      return await BitcoinZService.instance.decryptMessage(encryptedData);
    } catch (e) {
      _setError('Failed to decrypt message: $e');
      return null;
    }
  }

  /// Private helper methods
  Future<void> _refreshWalletData() async {
    if (kDebugMode) print('🔄 _refreshWalletData called...');
    
    // Check if this is a CLI wallet (use Rust Bridge)
    if (_wallet?.walletId?.startsWith('cli_imported_') == true) {
      if (kDebugMode) print('   Using Rust Bridge for CLI wallet');
      await _rustService.refresh(); // Rust service handles everything
    } else {
      if (kDebugMode) print('   Using regular wallet refresh path');
      await Future.wait([
        _loadBalance(),
        _loadTransactions(),
        _loadAddresses(),
      ]);
      notifyListeners();
    }
    
    // Note: Rust Bridge service is now the single source of truth for all data
  }

  Future<void> _loadBalance() async {
    try {
      _balance = await BitcoinZService.instance.getBalance();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _loadTransactions() async {
    try {
      _transactions = await BitcoinZService.instance.getTransactions();
      // Sort by timestamp, newest first
      _transactions.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _loadAddresses() async {
    try {
      _addresses = await BitcoinZService.instance.getAddresses();
      if (kDebugMode) {
        print('📦 Loaded addresses from Rust backend:');
        print('  transparent: ${_addresses['transparent']!.length} addresses');
        if (_addresses['transparent']!.isNotEmpty) {
          print('    first: ${_addresses['transparent']!.first} (${_addresses['transparent']!.first.length} chars)');
        }
        print('  shielded: ${_addresses['shielded']!.length} addresses');
        if (_addresses['shielded']!.isNotEmpty) {
          print('    first: ${_addresses['shielded']!.first} (${_addresses['shielded']!.first.length} chars)');
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  /// CLI-specific wallet data refresh methods
  Future<void> _refreshCliWalletData() async {
    if (kDebugMode) print('🔄 Refreshing wallet data via Rust Bridge...');
    
    // Rust Bridge service is the single source of truth
    // It will update balance, transactions, and addresses via callbacks
    await _rustService.refresh();
    
    if (kDebugMode) print('✅ Wallet refresh requested from Rust Bridge');
  }

  Future<void> _loadCliBalance() async {
    try {
      // Rust service updates balance automatically via callbacks
      await _rustService.fetchBalance();
      final result = {'success': true};
      if (result['success'] == true) {
        // CLI service already parsed JSON, get the data directly
        final balanceData = result['data'] as Map<String, dynamic>?;
        if (balanceData != null) {
          _balance = _parseCliBalance(balanceData);
          if (kDebugMode) {
            print('✅ CLI Balance loaded: ${_balance.total} BTCZ');
          }
        }
      } else {
        throw Exception('CLI balance query failed: ${result['error']}');
      }
    } catch (e) {
      if (kDebugMode) print('❌ Error loading CLI balance: $e');
      rethrow;
    }
  }

  Future<void> _loadCliTransactions() async {
    try {
      // Rust service updates transactions automatically via callbacks
      await _rustService.fetchTransactions();
      final result = {'success': true};
      if (result['success'] == true) {
        // CLI service already parsed JSON, get the data directly
        // Transactions are already updated via Rust service callbacks
        // No need to parse again
        if (kDebugMode) {
          print('✅ Rust Transactions loaded: ${_transactions.length}');
        }
      } else {
        // CLI might not have transactions command or no transactions yet
        _transactions = [];
      }
    } catch (e) {
      if (kDebugMode) print('⚠️ Could not load CLI transactions: $e');
      _transactions = []; // Don't fail, just set empty
    }
  }

  Future<void> _loadCliAddresses() async {
    try {
      // Rust service updates addresses automatically via callbacks  
      await _rustService.fetchAddresses();
      // Addresses are already updated via callbacks
      if (kDebugMode) {
        final tCount = _addresses['transparent']?.length ?? 0;
        final sCount = _addresses['shielded']?.length ?? 0;
        print('✅ Rust Addresses loaded: $tCount transparent + $sCount shielded');
      }
    } catch (e) {
      if (kDebugMode) print('❌ Error loading CLI addresses: $e');
      rethrow;
    }
  }

  /// Parse CLI balance response (already parsed JSON from CLI service)
  BalanceModel _parseCliBalance(Map<String, dynamic> data) {
    try {
      // Extract balance values (in zatoshis)
      final transparentBalance = (data['tbalance'] as num?)?.toInt() ?? 0;
      final shieldedBalance = (data['zbalance'] as num?)?.toInt() ?? 0;
      final unconfirmedBalance = (data['unverified_zbalance'] as num?)?.toInt() ?? 0;
      
      if (kDebugMode) {
        print('💰 Parsing CLI balance:');
        print('   Transparent: $transparentBalance zatoshis');
        print('   Shielded: $shieldedBalance zatoshis');
        print('   Unconfirmed: $unconfirmedBalance zatoshis');
      }
      
      return BalanceModel(
        transparent: transparentBalance / 100000000, // Convert to BTCZ
        shielded: shieldedBalance / 100000000,
        total: (transparentBalance + shieldedBalance) / 100000000,
        unconfirmed: unconfirmedBalance / 100000000,
      );
    } catch (e) {
      if (kDebugMode) print('❌ Error parsing CLI balance: $e');
      return BalanceModel.empty();
    }
  }

  /// Parse CLI addresses response (already parsed JSON from CLI service)  
  Map<String, List<String>> _parseCliAddresses(Map<String, dynamic> data) {
    try {
      final transparent = <String>[];
      final shielded = <String>[];
      
      // Extract transparent addresses
      if (data['t_addresses'] is List) {
        for (final addr in data['t_addresses']) {
          if (addr is String) {
            transparent.add(addr);
          }
        }
      }
      
      // Extract shielded addresses (zs1 and zc addresses)
      if (data['z_addresses'] is List) {
        for (final addr in data['z_addresses']) {
          if (addr is String) {
            shielded.add(addr);
          }
        }
      }
      
      // Also check unified addresses
      if (data['ua_addresses'] is List) {
        for (final addr in data['ua_addresses']) {
          if (addr is String) {
            // Treat unified addresses as shielded for UI purposes
            shielded.add(addr);
          }
        }
      }
      
      if (kDebugMode) {
        print('📍 Parsing CLI addresses:');
        print('   Transparent: ${transparent.length} addresses');
        print('   Shielded: ${shielded.length} addresses (including UA)');
      }
      
      return {
        'transparent': transparent,
        'shielded': shielded,
      };
    } catch (e) {
      if (kDebugMode) print('❌ Error parsing CLI addresses: $e');
      return {'transparent': <String>[], 'shielded': <String>[]};
    }
  }

  /// Get current block height with caching
  Future<int?> _getCurrentBlockHeight() async {
    final now = DateTime.now();
    
    // Return cached value if still valid
    if (_cachedBlockHeight != null && 
        _blockHeightCacheTime != null && 
        now.difference(_blockHeightCacheTime!).compareTo(_blockHeightCacheDuration) < 0) {
      return _cachedBlockHeight;
    }
    
    // Fetch new block height
    try {
      // TODO: Get block height from Rust service
      final blockHeight = null as int?;
      if (blockHeight != null) {
        _cachedBlockHeight = blockHeight;
        _blockHeightCacheTime = now;
      }
      return blockHeight;
    } catch (e) {
      if (kDebugMode) print('⚠️  Failed to fetch current block height: $e');
      return _cachedBlockHeight; // Return cached value if available
    }
  }

  /// Calculate real confirmations based on block heights
  int _calculateRealConfirmations(int? txBlockHeight, int? currentBlockHeight, bool isUnconfirmed) {
    // For unconfirmed transactions, always return 0 regardless of block height
    if (isUnconfirmed) {
      return 0;
    }
    
    if (txBlockHeight == null || currentBlockHeight == null || txBlockHeight == 0) {
      return 0; // No block height data = 0 confirmations (Confirming)
    }
    final confirmations = currentBlockHeight - txBlockHeight + 1;
    return confirmations > 0 ? confirmations : 0;
  }

  /// Parse CLI transactions from pre-parsed List
  Future<List<TransactionModel>> _parseCliTransactionsList(List<dynamic> transactions) async {
    final List<TransactionModel> parsedTransactions = [];
    
    // Get current block height for confirmation calculation
    final currentBlockHeight = await _getCurrentBlockHeight();
    
    for (final txJson in transactions) {
      if (txJson is Map<String, dynamic>) {
        try {
          // Extract transaction data
          final String txid = txJson['txid'] ?? '';
          final int blockHeight = txJson['block_height'] ?? 0;
          final bool unconfirmed = txJson['unconfirmed'] ?? true;
          final int timestamp = txJson['datetime'] ?? 0;
          final double amount = (txJson['amount'] as num?)?.toDouble() ?? 0.0;
          
          // Convert zatoshis to BTCZ
          final double amountBtcz = amount / 100000000.0;
          
          // Debug logging for unconfirmed transactions
          if (unconfirmed && kDebugMode) {
            print('🔍 Processing unconfirmed transaction:');
            print('   txid: ${txid.substring(0, 8)}...');
            print('   block_height: $blockHeight');
            print('   unconfirmed: $unconfirmed');
            print('   amount: $amount zatoshis');
            print('   amountBtcz: $amountBtcz BTCZ');
            print('   type will be: ${amountBtcz > 0 ? 'received' : 'sent'}');
          }
          
          // Debug logging for received transactions (both confirmed and unconfirmed)
          if (amountBtcz > 0 && kDebugMode) {
            print('📥 Processing INCOMING transaction:');
            print('   txid: ${txid.substring(0, 8)}...');
            print('   amount: +${amountBtcz.toStringAsFixed(8)} BTCZ');
            print('   unconfirmed: $unconfirmed');
            print('   address: ${txJson['address']}');
            print('   confirmations will be: ${unconfirmed ? 0 : 'calculated'}');
          }
          
          // Determine transaction type
          final String type = amountBtcz > 0 ? 'received' : 'sent';
          
          // Extract memo and addresses
          String memo = '';
          String? fromAddress;
          String? toAddress;
          
          if (type == 'sent') {
            // For sent transactions, get recipient address and memo from outgoing_metadata
            if (txJson['outgoing_metadata'] is List && (txJson['outgoing_metadata'] as List).isNotEmpty) {
              final metadata = (txJson['outgoing_metadata'] as List).first;
              if (metadata is Map<String, dynamic>) {
                toAddress = metadata['address'] as String?;
                if (metadata['memo'] is String) {
                  memo = metadata['memo'];
                }
              }
            }
          } else if (type == 'received') {
            // For received transactions, the 'address' field is usually our receiving address
            // We don't have sender info in this CLI format, so we'll leave fromAddress as null
            toAddress = txJson['address'] as String?; // Our address that received the funds
          }
          
          // Calculate confirmations
          final int calculatedConfirmations = _calculateRealConfirmations(blockHeight, currentBlockHeight, unconfirmed);
          
          // Debug logging for confirmation calculation
          if (kDebugMode && (unconfirmed || calculatedConfirmations <= 5)) {
            print('🔍 Confirmation calculation:');
            print('   txid: ${txid.substring(0, 8)}...');
            print('   unconfirmed: $unconfirmed');
            print('   blockHeight: $blockHeight');
            print('   currentBlockHeight: $currentBlockHeight');
            print('   calculatedConfirmations: $calculatedConfirmations');
          }
          
          // Check if this is an auto-shielding operation (internal wallet transfer)
          final isAutoShielding = await _isAutoShieldingTransaction(txJson, type, fromAddress, toAddress);
          
          if (isAutoShielding && kDebugMode) {
            print('🔧 Detected auto-shielding operation: ${txid.substring(0, 8)}... (filtering out)');
          }
          
          // Create transaction model
          final transaction = TransactionModel(
            txid: txid,
            type: type,
            amount: amountBtcz.abs(),
            blockHeight: blockHeight > 0 ? blockHeight : null,
            timestamp: DateTime.fromMillisecondsSinceEpoch(timestamp * 1000),
            confirmations: calculatedConfirmations,
            fromAddress: fromAddress,
            toAddress: toAddress,
            memo: memo.isNotEmpty ? memo : null,
            fee: type == 'sent' ? 0.0001 : 0.0, // Small default fee for sent transactions
          );
          
          // Only add non-auto-shielding transactions
          if (!isAutoShielding) {
            parsedTransactions.add(transaction);
          }
          
          // Debug logging for created transaction
          if (unconfirmed && kDebugMode) {
            print('✅ Created unconfirmed transaction:');
            print('   txid: ${transaction.txid.substring(0, 8)}...');
            print('   confirmations: ${transaction.confirmations}');
            print('   isPending: ${transaction.isPending}');
            print('   type: ${transaction.type}');
            print('   amount: ${transaction.amount}');
          }
          
          // Debug logging for incoming transactions specifically
          if (transaction.type == 'received' && kDebugMode) {
            print('📥 Created RECEIVED transaction:');
            print('   txid: ${transaction.txid.substring(0, 8)}...');
            print('   amount: +${transaction.amount}');
            print('   confirmations: ${transaction.confirmations}');
            print('   isPending: ${transaction.isPending}');
            print('   fromAddress: ${transaction.fromAddress}');
            print('   toAddress: ${transaction.toAddress}');
          }
        } catch (e) {
          if (kDebugMode) print('⚠️ Skipping malformed transaction: $e');
          continue;
        }
      }
    }
    
    if (kDebugMode) {
      final sentCount = parsedTransactions.where((tx) => tx.type == 'sent').length;
      final receivedCount = parsedTransactions.where((tx) => tx.type == 'received').length;
      final pendingCount = parsedTransactions.where((tx) => tx.isPending).length;
      print('✅ Parsed ${parsedTransactions.length} CLI transactions from List:');
      print('   📤 Sent: $sentCount');
      print('   📥 Received: $receivedCount');
      print('   ⏳ Pending (0 confirmations): $pendingCount');
    }
    
    return parsedTransactions;
  }

  /// Detect if a transaction is an auto-shielding operation (internal wallet transfer)
  Future<bool> _isAutoShieldingTransaction(
    Map<String, dynamic> txJson, 
    String type, 
    String? fromAddress, 
    String? toAddress
  ) async {
    try {
      // Get our wallet addresses
      final ourAddresses = await _getOurAddresses();
      
      // Auto-shielding detection criteria:
      // 1. Both sender and recipient are our addresses (internal transfer)
      // 2. Small amounts (typically consolidation/maintenance)
      // 3. No memo (internal operations usually don't have memos)
      // 4. Regular pattern (multiple similar transactions)
      
      bool isBothOurAddresses = false;
      
      if (type == 'sent') {
        // For sent transactions, check if recipient is our address
        if (toAddress != null && ourAddresses.contains(toAddress)) {
          isBothOurAddresses = true;
        }
      } else if (type == 'received') {
        // For received transactions, check if we also have the sender
        // (This is harder to detect as we don't always have sender info)
        final address = txJson['address'] as String?;
        if (address != null && ourAddresses.contains(address)) {
          // This is to one of our addresses, which is expected for received txs
          // We'd need to check if the sender is also ours, but CLI doesn't always provide this
          // For now, we'll be conservative and not filter received transactions
          isBothOurAddresses = false;
        }
      }
      
      // Additional criteria for auto-shielding
      final hasNoMemo = (txJson['memo'] == null || (txJson['memo'] as String?)?.isEmpty == true);
      final amount = (txJson['amount'] as num?)?.toDouble() ?? 0.0;
      final isSmallAmount = amount.abs() < 100000000; // Less than 1 BTCZ
      
      // Only consider sent transactions as potential auto-shielding for now
      // (to avoid filtering legitimate received payments)
      if (type == 'sent' && isBothOurAddresses && hasNoMemo && isSmallAmount) {
        return true;
      }
      
      return false;
    } catch (e) {
      if (kDebugMode) print('⚠️ Error detecting auto-shielding: $e');
      return false; // Default to including the transaction if we can't determine
    }
  }

  /// Get all our wallet addresses (both transparent and shielded)
  Future<Set<String>> _getOurAddresses() async {
    final addresses = <String>{};
    
    // Add transparent addresses
    if (_addresses['transparent'] != null) {
      addresses.addAll(_addresses['transparent']!);
    }
    
    // Add shielded addresses  
    if (_addresses['shielded'] != null) {
      addresses.addAll(_addresses['shielded']!);
    }
    
    return addresses;
  }

  /// Parse CLI transactions response 
  Future<List<TransactionModel>> _parseCliTransactions(String output) async {
    try {
      // Parse the JSON response
      final List<dynamic> transactions = jsonDecode(output);
      final List<TransactionModel> parsedTransactions = [];
      
      // Get current block height for confirmation calculation
      final currentBlockHeight = await _getCurrentBlockHeight();
      
      for (final txJson in transactions) {
        if (txJson is Map<String, dynamic>) {
          try {
            // Extract transaction data
            final String txid = txJson['txid'] ?? '';
            final int blockHeight = txJson['block_height'] ?? 0;
            final bool unconfirmed = txJson['unconfirmed'] ?? true;
            final int timestamp = txJson['datetime'] ?? 0;
            final double amount = (txJson['amount'] as num?)?.toDouble() ?? 0.0;
            
            // Convert zatoshis to BTCZ
            final double amountBtcz = amount / 100000000.0;
            
            // Determine transaction type
            final String type = amountBtcz > 0 ? 'received' : 'sent';
            
            // Extract memo and addresses
            String memo = '';
            String? fromAddress;
            String? toAddress;
            
            if (type == 'sent') {
              // For sent transactions, get recipient address and memo from outgoing_metadata
              if (txJson['outgoing_metadata'] is List && (txJson['outgoing_metadata'] as List).isNotEmpty) {
                final metadata = (txJson['outgoing_metadata'] as List).first;
                if (metadata is Map<String, dynamic>) {
                  toAddress = metadata['address'] as String?;
                  if (metadata['memo'] is String) {
                    memo = metadata['memo'];
                  }
                }
              }
            } else if (type == 'received') {
              // For received transactions, the 'address' field is usually our receiving address
              // We don't have sender info in this CLI format, so we'll leave fromAddress as null
              toAddress = txJson['address'] as String?; // Our address that received the funds
            }
            
            // Create transaction model
            final transaction = TransactionModel(
              txid: txid,
              type: type,
              amount: amountBtcz.abs(),
              blockHeight: blockHeight > 0 ? blockHeight : null,
              timestamp: DateTime.fromMillisecondsSinceEpoch(timestamp * 1000),
              confirmations: _calculateRealConfirmations(blockHeight, currentBlockHeight, unconfirmed),
              fromAddress: fromAddress,
              toAddress: toAddress,
              memo: memo.isNotEmpty ? memo : null,
              fee: type == 'sent' ? 0.0001 : 0.0, // Small default fee for sent transactions
            );
            
            parsedTransactions.add(transaction);
          } catch (e) {
            if (kDebugMode) print('⚠️ Skipping malformed transaction: $e');
            continue;
          }
        }
      }
      
      if (kDebugMode) {
        print('✅ Parsed ${parsedTransactions.length} CLI transactions');
      }
      
      return parsedTransactions;
    } catch (e) {
      if (kDebugMode) print('❌ Error parsing CLI transactions JSON: $e');
      return [];
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setSyncing(bool syncing) {
    _isSyncing = syncing;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    notifyListeners();
  }

  // Pagination and Database Methods
  
  /// Load transactions with pagination support
  Future<void> loadTransactionsPage({
    int page = 0,
    String? searchQuery,
    String? filterType,
    bool resetList = false,
  }) async {
    if (resetList) {
      _currentPage = 0;
      // Don't clear transactions if Rust Bridge is providing live data
      // Only clear if we need to load from database (when no live RPC data available)
      if (_transactions.isEmpty || (searchQuery != null || filterType != null)) {
        if (kDebugMode) print('📄 Clearing transactions for database pagination (search/filter)');
        _transactions.clear();
      } else {
        if (kDebugMode) print('📄 Keeping Rust Bridge transactions, skipping database load');
        return; // Skip database loading when we have live RPC data
      }
      _hasMoreTransactions = true;
    }
    
    if (_isLoadingMore || (!_hasMoreTransactions && !resetList)) return;
    
    _isLoadingMore = true;
    _searchQuery = searchQuery;
    _filterType = filterType;
    notifyListeners();

    try {
      final transactions = await _databaseService.getTransactions(
        limit: _pageSize,
        offset: page * _pageSize,
        type: filterType,
        searchQuery: searchQuery,
      );

      if (resetList) {
        _transactions = transactions;
      } else {
        _transactions.addAll(transactions);
      }

      _hasMoreTransactions = transactions.length == _pageSize;
      _currentPage = page;
      
      if (kDebugMode) {
        print('📄 Loaded page $page with ${transactions.length} transactions');
      }
    } catch (e) {
      if (kDebugMode) print('❌ Error loading transactions page: $e');
      _setError('Failed to load transactions: $e');
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  /// Load next page of transactions
  Future<void> loadMoreTransactions() async {
    if (!_hasMoreTransactions || _isLoadingMore) return;
    await loadTransactionsPage(
      page: _currentPage + 1,
      searchQuery: _searchQuery,
      filterType: _filterType,
    );
  }

  /// Search transactions with database query
  Future<void> searchTransactions(String query) async {
    await loadTransactionsPage(
      searchQuery: query.isEmpty ? null : query,
      filterType: _filterType,
      resetList: true,
    );
  }

  /// Filter transactions by type
  Future<void> filterTransactions(String? type) async {
    await loadTransactionsPage(
      searchQuery: _searchQuery,
      filterType: type,
      resetList: true,
    );
  }

  /// Refresh transactions from database (reload first page)
  Future<void> refreshTransactionsFromDatabase() async {
    await loadTransactionsPage(resetList: true);
  }

  /// Sync transactions from CLI to database
  Future<void> syncTransactionsToDatabase() async {
    if (_isSyncing) return;
    
    _isSyncing = true;
    notifyListeners();

    try {
      // Load transactions from CLI
      await _loadCliTransactions();
      
      // Save to database
      if (_transactions.isNotEmpty) {
        await _databaseService.insertTransactions(_transactions);
        if (kDebugMode) {
          print('💾 Synced ${_transactions.length} transactions to database');
        }
      }
      
      // Load addresses from CLI
      await _loadCliAddresses();
      
      // Convert and save addresses to database
      if (_addressModels.isNotEmpty) {
        await _databaseService.insertAddresses(_addressModels);
        if (kDebugMode) {
          print('💾 Synced ${_addressModels.length} addresses to database');
        }
      }

      // Reload from database with pagination
      await loadTransactionsPage(resetList: true);
      
    } catch (e) {
      if (kDebugMode) print('❌ Error syncing to database: $e');
      _setError('Failed to sync to database: $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Get transaction statistics
  Future<Map<String, int>> getTransactionStats() async {
    try {
      final totalCount = await _databaseService.getTransactionCount();
      final sentCount = await _databaseService.getTransactionCount(type: 'sent');
      final receivedCount = await _databaseService.getTransactionCount(type: 'received');
      final pendingCount = await _databaseService.getTransactionCount(isPending: true);
      
      return {
        'total': totalCount,
        'sent': sentCount,
        'received': receivedCount,
        'pending': pendingCount,
      };
    } catch (e) {
      if (kDebugMode) print('❌ Error getting transaction stats: $e');
      return {
        'total': _transactions.length,
        'sent': _transactions.where((tx) => tx.isSent).length,
        'received': _transactions.where((tx) => tx.isReceived).length,
        'pending': _transactions.where((tx) => tx.isPending).length,
      };
    }
  }

  /// Clear all wallet data (for logout)
  void clearWallet() {
    stopAutoSync();
    _wallet = null;
    _balance = BalanceModel.empty();
    _transactions = [];
    _addresses = {'transparent': [], 'shielded': []};
    _addressModels = [];
    _lastSyncTime = null;
    _isConnected = false;
    _connectionStatus = 'Disconnected';
    _lastConnectionCheck = null;
    
    // Reset pagination state
    _currentPage = 0;
    _hasMoreTransactions = true;
    _isLoadingMore = false;
    _searchQuery = null;
    _filterType = null;
    
    _clearError();
    notifyListeners();
  }
  
  @override
  void dispose() {
    _rustService.dispose(); // Clean up the Rust service (async but we can't await here)
    stopAutoSync();
    super.dispose();
  }

  /// Get recent transactions (mobile-optimized count)
  List<TransactionModel> get recentTransactions {
    return _transactions.take(5).toList(); // Show fewer on mobile
  }

  /// Get transactions by type
  List<TransactionModel> getTransactionsByType(String type) {
    return _transactions.where((tx) => tx.type == type).toList();
  }

  /// Check if address belongs to this wallet
  bool isMyAddress(String address) {
    return _addresses['transparent']!.contains(address) ||
           _addresses['shielded']!.contains(address);
  }

  /// Get balance summary for mobile dashboard
  Map<String, dynamic> get balanceSummary {
    return {
      'total': _balance.formattedTotal,
      'hasBalance': _balance.hasBalance,
      'needsSync': needsSync,
      'lastSync': _lastSyncTime,
    };
  }

  /// Get transaction summary for mobile
  Map<String, dynamic> get transactionSummary {
    final sent = _transactions.where((tx) => tx.isSent).length;
    final received = _transactions.where((tx) => tx.isReceived).length;
    final pending = _transactions.where((tx) => tx.isPending).length;
    
    return {
      'total': _transactions.length,
      'sent': sent,
      'received': received,
      'pending': pending,
      'recent': recentTransactions,
    };
  }
}