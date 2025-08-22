import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:bip39/bip39.dart' as bip39;
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../models/wallet_model.dart';
import '../models/balance_model.dart';
import '../models/transaction_model.dart';
import '../models/address_model.dart';
// import '../services/bitcoinz_service.dart'; // Not used - using Rust service instead
import '../services/database_service.dart';
import '../services/bitcoinz_rust_service.dart';
import '../providers/auth_provider.dart';
import '../screens/wallet/paginated_transaction_history_screen.dart';

class WalletProvider with ChangeNotifier {
  WalletModel? _wallet;
  BalanceModel _balance = BalanceModel.empty();
  List<TransactionModel> _transactions = [];
  bool _isLoading = false;
  bool _isSyncing = false;
  String? _error;
  Map<String, List<String>> _addresses = {'transparent': [], 'shielded': []};
  List<AddressModel> _addressModels = [];
  bool _isConnected = false;
  String _connectionStatus = 'Disconnected';
  DateTime? _lastConnectionCheck;
  Timer? _syncTimer;
  
  // Sync progress tracking (like BitcoinZ Blue)
  int _syncedBlocks = 0;
  int _totalBlocks = 0;
  int _batchNum = 0;
  int _batchTotal = 0;
  double _syncProgress = 0.0;
  String _syncMessage = '';
  Timer? _syncStatusTimer;
  bool _autoSyncEnabled = true;
  
  // Enhanced sync tracking
  DateTime? _syncStartTime;
  DateTime? _lastSyncTime;
  int _lastSyncedBlocks = 0;
  double _syncSpeed = 0.0; // blocks per second
  Duration? _estimatedTimeRemaining;
  
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
  
  // Memo notification state
  int _unreadMemoCount = 0;
  BuildContext? _notificationContext;
  Map<String, bool> _memoReadStatusCache = {}; // In-memory cache for memo read status
  SharedPreferences? _prefs; // For fallback storage when database fails
  bool _prefsInitialized = false; // Track if SharedPreferences is ready
  
  // Temporary storage for generated wallet data
  
  // Defensive state protection
  bool _walletLocked = false; // Prevents wallet state resets during background operations
  String? _temporaryGeneratedSeed;
  int? _temporaryGeneratedBirthday;
  
  final DatabaseService _databaseService = DatabaseService.instance;
  late final BitcoinzRustService _rustService; // Native Rust service with mempool monitoring
  
  // Constructor
  WalletProvider() {
    // Initialize SharedPreferences early
    _initializePreferences();
    
    // Initialize Native Rust service with mempool monitoring
    _rustService = BitcoinzRustService.instance;
    _rustService.fnSetTotalBalance = (balance) async {
      if (kDebugMode) print('🦀 Rust Bridge updated balance: ${balance.formattedTotal} BTCZ (unconfirmed: ${balance.unconfirmed})');
      _balance = balance;
      
      // Save balance to cache for faster startup
      if (_wallet != null) {
        try {
          final authProvider = AuthProvider();
          await authProvider.initialize();
          final walletData = await authProvider.getStoredWalletData();
          if (walletData != null) {
            walletData['cachedBalance'] = {
              'transparent': _balance.transparent,
              'shielded': _balance.shielded,
              'unconfirmed': _balance.unconfirmed,
              'total': _balance.total,
            };
            await authProvider.updateWalletData(walletData);
          }
        } catch (e) {
          if (kDebugMode) print('⚠️ Failed to cache balance: $e');
        }
      }
      
      notifyListeners();
    };
    _rustService.fnSetTransactionsList = (transactions) async {
      final unconfirmedCount = transactions.where((tx) => tx.confirmations == 0).length;
      if (kDebugMode) print('🦀 Rust Bridge updated transactions: ${transactions.length} txs ($unconfirmedCount unconfirmed)');
      
      // Preserve memo read status from existing transactions and cache
      final Map<String, bool> memoReadStatus = {};
      for (final existingTx in _transactions) {
        if (existingTx.hasMemo) {
          memoReadStatus[existingTx.txid] = existingTx.memoRead;
        }
      }
      
      // Merge with in-memory cache and SharedPreferences
      for (final tx in transactions) {
        if (tx.hasMemo && !memoReadStatus.containsKey(tx.txid)) {
          // Check cache and SharedPreferences for memo read status
          memoReadStatus[tx.txid] = getMemoReadStatus(tx.txid);
        }
      }
      
      // Check for new transactions with memos
      final Set<String> existingTxIds = _transactions.map((tx) => tx.txid).toSet();
      final List<TransactionModel> newMemoTransactions = [];
      
      // Update transactions with preserved read status
      final updatedTransactions = transactions.map((tx) {
        // Use memo read status from our merged sources
        if (tx.hasMemo && memoReadStatus.containsKey(tx.txid)) {
          tx = tx.copyWith(memoRead: memoReadStatus[tx.txid]);
        } else if (tx.hasMemo && !existingTxIds.contains(tx.txid)) {
          // This is a new transaction with a memo
          newMemoTransactions.add(tx);
        }
        return tx;
      }).toList();
      
      _transactions = updatedTransactions;
      
      // Show notification for new memo transactions
      if (newMemoTransactions.isNotEmpty) {
        _notifyNewMemoTransactions(newMemoTransactions);
      }
      
      // Update unread memo count when transactions are updated
      await updateUnreadMemoCount();
      
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
  bool get isConnected => _isConnected;
  String get connectionStatus => _connectionStatus;
  DateTime? get lastConnectionCheck => _lastConnectionCheck;
  bool get autoSyncEnabled => _autoSyncEnabled;
  
  // Sync progress getters (like BitcoinZ Blue)
  int get syncedBlocks => _syncedBlocks;
  int get totalBlocks => _totalBlocks;
  int get batchNum => _batchNum;
  int get batchTotal => _batchTotal;
  double get syncProgress => _syncProgress;
  String get syncMessage => _syncMessage;
  
  // Enhanced sync tracking getters
  DateTime? get lastSyncTime => _lastSyncTime;
  DateTime? get syncStartTime => _syncStartTime;
  double get syncSpeed => _syncSpeed;
  Duration? get estimatedTimeRemaining => _estimatedTimeRemaining;
  
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
  
  // Memo notification getters
  int get unreadMemoCount => _unreadMemoCount;
  bool get needsSync => _lastSyncTime == null || DateTime.now().difference(_lastSyncTime!).inMinutes > 5;

  /// Generate a new wallet seed and get real birthday from blockchain
  Future<Map<String, dynamic>> generateNewWallet() async {
    if (kDebugMode) {
      print('🎲 Generating new wallet with real blockchain birthday...');
    }
    
    // Generate seed phrase locally first
    final mnemonic = bip39.generateMnemonic(strength: 256); // 24 words
    int? birthday;
    
    try {
      // First, try to get blockchain height by initializing Rust service
      // We'll create a temporary wallet just to connect to the server
      int? currentHeight;
      
      if (!_rustService.initialized) {
        try {
          if (kDebugMode) print('📡 Initializing Rust service to get blockchain height...');
          
          // Create a temporary wallet to establish server connection
          final tempInitialized = await _rustService.initialize(
            serverUri: 'https://lightd.btcz.rocks:9067',
            createNew: true, // Create a temporary new wallet
          );
          
          if (tempInitialized) {
            if (kDebugMode) print('✅ Rust service initialized, getting blockchain height...');
            
            // Now we can get the real blockchain height
            try {
              currentHeight = await _rustService.getCurrentBlockHeight();
              if (currentHeight != null && currentHeight > 0) {
                if (kDebugMode) print('📊 Got real blockchain height: $currentHeight');
              }
            } catch (e) {
              if (kDebugMode) print('⚠️ Failed to get block height: $e');
            }
            
            // Note: The temporary wallet will be overwritten when createWallet() is called
            // This is just to get the blockchain height
          } else {
            if (kDebugMode) print('⚠️ Failed to initialize Rust service for height check');
          }
        } catch (e) {
          if (kDebugMode) print('⚠️ Error initializing Rust service: $e');
        }
      } else {
        // Rust service already initialized, just get the height
        try {
          currentHeight = await _rustService.getCurrentBlockHeight();
          if (kDebugMode) print('📊 Got blockchain height from existing service: $currentHeight');
        } catch (e) {
          if (kDebugMode) print('⚠️ Failed to get height: $e');
        }
      }
      
      // If we still couldn't get the height, log it
      if (currentHeight == null || currentHeight == 0) {
        if (kDebugMode) {
          print('📊 Could not get real blockchain height');
          print('📊 Will use estimated height for birthday calculation');
        }
      }
      
      // Calculate birthday based on actual or estimated height
      // Use a more recent height as fallback (update this periodically)
      if (currentHeight == null || currentHeight == 0) {
        // Use a recent mainnet height as fallback
        currentHeight = 1625000; // Updated mainnet height as of Dec 2024
        if (kDebugMode) {
          print('⚠️ Using fallback height: $currentHeight');
        }
      }
      
      // Set birthday to current height minus 100 blocks for safety
      // This ensures new wallets don't scan the entire blockchain
      birthday = currentHeight - 100;
      
      if (kDebugMode) {
        print('✅ New wallet seed generated:');
        print('   Seed: ${mnemonic.split(' ').length} words (locally generated)');
        print('   Birthday block: $birthday');
        print('   Current height: $currentHeight (${currentHeight == 1620000 ? "FALLBACK/ESTIMATED" : "REAL from blockchain"})');
        print('   Rust initialized: ${_rustService.initialized}');
        if (currentHeight == 1620000) {
          print('⚠️ WARNING: Using fallback height - Rust service may not be connecting to server');
        }
      }
      
      return {
        'seed': mnemonic,
        'birthday': birthday,
      };
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Error during wallet generation: $e');
        print('⚠️ Using fallback values');
      }
      
      // Ultimate fallback - use a recent block height
      birthday ??= 1615900; // Recent mainnet height - 100
      
      return {
        'seed': mnemonic,
        'birthday': birthday,
      };
    }
  }

  /// Initialize or create wallet (mobile-first)
  Future<void> createWallet(String seedPhrase, {AuthProvider? authProvider, bool isNewWallet = true}) async {
    _setLoading(true);
    _clearError();

    try {
      if (kDebugMode) {
        print('🏗️ WalletProvider.createWallet() starting...');
        print('  seedPhrase provided: ${seedPhrase.isNotEmpty}');
        print('  isNewWallet: $isNewWallet');
        print('  authProvider provided: ${authProvider != null}');
      }
      
      // Create wallet directly via Rust Bridge if no seed provided
      String finalSeedPhrase = seedPhrase;
      
      if (isNewWallet && seedPhrase.isNotEmpty) {
        // Always create a new wallet for new wallets
        // Don't try to reuse from generateNewWallet() as it causes issues
        {
          // This is a different flow or wallet not initialized, create new wallet
          if (kDebugMode) {
            print('🦀 Creating new wallet via Rust Bridge...');
            print('   Note: This is a fresh wallet creation');
          }
          final rustInitialized = await _rustService.initialize(
            serverUri: 'https://lightd.btcz.rocks:9067',
            createNew: true,  // Create new wallet
          );
          
          if (!rustInitialized) {
            throw Exception('Failed to create wallet via Rust Bridge');
          }
          
          // Get the generated seed phrase from Rust
          finalSeedPhrase = _rustService.getSeedPhrase() ?? '';
          if (finalSeedPhrase.isEmpty) {
            throw Exception('Failed to get seed phrase from Rust Bridge');
          }
          
          if (kDebugMode) {
            print('✅ New wallet created with seed phrase from Rust');
            print('   Birthday: ${_rustService.getBirthday()}');
          }
        }
      } else {
        // Restore wallet from provided seed phrase
        if (kDebugMode) print('🦀 Restoring wallet via Rust Bridge...');
        
        // When restoring, use current block height as birthday for fast sync
        // This is appropriate for new wallets being restored
        final currentBlockHeight = await _rustService.getCurrentBlockHeight();
        final int birthdayToUse = currentBlockHeight > 100 ? currentBlockHeight - 100 : 0;
        
        if (kDebugMode) {
          print('   Using birthday height for restore: $birthdayToUse');
        }
        
        final rustInitialized = await _rustService.initialize(
          serverUri: 'https://lightd.btcz.rocks:9067',
          seedPhrase: seedPhrase,
          createNew: false,
          birthdayHeight: birthdayToUse,
        );
        
        if (!rustInitialized) {
          throw Exception('Failed to restore wallet via Rust Bridge');
        }
        
        if (kDebugMode) print('✅ Wallet restored from seed phrase with birthday: $birthdayToUse');
      }
      
      // Refresh wallet data from Rust to get real addresses
      await _refreshWalletData();
      await _checkConnection();
      
      // Create wallet model with real data from Rust
      final walletId = const Uuid().v4();
      final walletInfo = WalletModel(
        walletId: walletId,
        transparentAddresses: _addresses['transparent'] ?? [],
        shieldedAddresses: _addresses['shielded'] ?? [],
        createdAt: DateTime.now(),
        birthdayHeight: _rustService.getBirthday() ?? 0,
      );
      
      _wallet = walletInfo;
      
      if (kDebugMode) {
        print('📱 Wallet initialized successfully:');
        print('  walletId: $walletId');
        print('  birthday block: ${walletInfo.birthdayHeight}');
        print('  transparent addresses: ${_addresses['transparent']?.length ?? 0}');
        print('  shielded addresses: ${_addresses['shielded']?.length ?? 0}');
        if (_addresses['transparent']?.isNotEmpty ?? false) {
          print('  first t-address: ${_addresses['transparent']!.first}');
        }
        if (_addresses['shielded']?.isNotEmpty ?? false) {
          print('  first z-address: ${_addresses['shielded']!.first}');
        }
      }
      
      // Store wallet data persistently
      if (authProvider != null) {
        if (kDebugMode) print('💾 Calling authProvider.registerWallet()...');
        await authProvider.registerWallet(
          walletId,
          seedPhrase: finalSeedPhrase,
          walletData: {
            'walletId': walletId,
            'transparentAddresses': _addresses['transparent'] ?? [],
            'shieldedAddresses': _addresses['shielded'] ?? [],
            'birthdayHeight': walletInfo.birthdayHeight,
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
      // Restore wallet directly via Rust Bridge
      if (kDebugMode) print('🦀 Restoring wallet via Rust Bridge...');
      final rustInitialized = await _rustService.initialize(
        serverUri: 'https://lightd.btcz.rocks:9067',
        seedPhrase: seedPhrase,
        createNew: false,
      );
      
      if (!rustInitialized) {
        throw Exception('Failed to restore wallet via Rust Bridge');
      }
      
      // Refresh wallet data from Rust to get real addresses
      await _refreshWalletData();
      await _checkConnection();
      
      // Create wallet model with real data from Rust
      final walletId = const Uuid().v4();
      final walletInfo = WalletModel(
        walletId: walletId,
        transparentAddresses: _addresses['transparent'] ?? [],
        shieldedAddresses: _addresses['shielded'] ?? [],
        createdAt: DateTime.now(),
        birthdayHeight: birthdayHeight,
      );
      
      _wallet = walletInfo;
      
      if (kDebugMode) {
        print('📱 Wallet restored successfully:');
        print('  walletId: $walletId');
        print('  transparent addresses: ${_addresses['transparent']?.length ?? 0}');
        print('  shielded addresses: ${_addresses['shielded']?.length ?? 0}');
      }
      
      // Store wallet data persistently
      if (authProvider != null) {
        await authProvider.registerWallet(
          walletId,
          seedPhrase: seedPhrase,
          walletData: {
            'walletId': walletId,
            'transparentAddresses': _addresses['transparent'] ?? [],
            'shieldedAddresses': _addresses['shielded'] ?? [],
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
    
    // Ensure SharedPreferences is loaded before wallet operations
    await ensurePreferencesInitialized();
    
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
    
    // Ensure SharedPreferences is loaded before wallet operations
    await ensurePreferencesInitialized();
    
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
        final platform = Platform.isAndroid ? "Android" : Platform.isIOS ? "iOS" : Platform.isMacOS ? "macOS" : "Other";
        print('   📱 Platform: $platform');
        print('   AuthProvider hasWallet: ${authProvider.hasWallet}');
        print('   AuthProvider isAuthenticated: ${authProvider.isAuthenticated}');
        print('   🔍 Platform Analysis:');
        print('     - Android: ${Platform.isAndroid}');
        print('     - iOS: ${Platform.isIOS}');  
        print('     - macOS: ${Platform.isMacOS}');
        print('     - Linux: ${Platform.isLinux}');
        print('     - Windows: ${Platform.isWindows}');
      }
      
      final seedPhrase = await authProvider.getStoredSeedPhrase();
      final walletData = await authProvider.getStoredWalletData();
      
      // Enhanced platform storage analysis
      if (kDebugMode && walletData != null) {
        print('  💾 Storage Analysis (Android vs macOS):');
        try {
          // Try to get storage paths for debugging
          final prefs = await SharedPreferences.getInstance();
          final keys = prefs.getKeys();
          final walletKeys = keys.where((k) => k.toLowerCase().contains('wallet') || k.toLowerCase().contains('birthday')).toList();
          print('    SharedPreferences wallet keys: $walletKeys');
          
          // Check for any birthday-related keys in SharedPreferences
          for (final key in walletKeys) {
            if (key.toLowerCase().contains('birthday')) {
              final value = prefs.get(key);
              print('    SharedPrefs $key: $value (${value.runtimeType})');
            }
          }
        } catch (e) {
          print('    ⚠️ Could not analyze SharedPreferences: $e');
        }
      }
      
      if (kDebugMode) {
        print('  seedPhrase found: ${seedPhrase != null}');
        print('  walletData found: ${walletData != null}');
        if (walletData != null) {
          print('  📊 Wallet Data Analysis:');
          print('    walletId: ${walletData['walletId']}');
          print('    transparent addresses: ${walletData['transparentAddresses']?.length ?? 0}');
          print('    shielded addresses: ${walletData['shieldedAddresses']?.length ?? 0}');
          print('  🎂 Birthday Height Analysis (Critical for Android Fix):');
          print('    All keys: ${walletData.keys.toList()}');
          print('    Birthday-related keys: ${walletData.keys.where((k) => k.toLowerCase().contains('birthday') || k.toLowerCase().contains('height')).toList()}');
          print('    birthdayHeight: ${walletData['birthdayHeight']} (${walletData['birthdayHeight'].runtimeType})');
          print('    birthday: ${walletData['birthday']} (${walletData['birthday'].runtimeType})');
          print('    created_at: ${walletData['created_at']}');
          final rawBirthday = walletData['birthdayHeight'] ?? walletData['birthday'] ?? 0;
          print('    Raw birthday value: $rawBirthday (${rawBirthday.runtimeType})');
          print('    Is birthday > 0?: ${(rawBirthday is int ? rawBirthday : int.tryParse(rawBirthday.toString()) ?? 0) > 0}');
        }
      }
      
      // CRITICAL FIX: Create wallet model IMMEDIATELY if we have wallet data
      // Don't wait for seedPhrase or Rust initialization
      if (walletData != null) {
        // Load cached addresses first
        if (walletData['transparentAddresses'] != null) {
          _addresses['transparent'] = List<String>.from(walletData['transparentAddresses']);
          if (kDebugMode) print('📋 Loaded ${_addresses['transparent']!.length} cached transparent addresses');
        }
        if (walletData['shieldedAddresses'] != null) {
          _addresses['shielded'] = List<String>.from(walletData['shieldedAddresses']);
          if (kDebugMode) print('📋 Loaded ${_addresses['shielded']!.length} cached shielded addresses');
        }
        
        // Create wallet model immediately with cached data
        final walletId = walletData['walletId'] ?? 
                        authProvider.walletId ?? 
                        'wallet_${DateTime.now().millisecondsSinceEpoch}';
        
        // Extract and store birthday height for later use
        final storedBirthday = walletData['birthdayHeight'] ?? walletData['birthday'] ?? 0;
        
        if (kDebugMode) {
          print('🚨 ANDROID FIX: Creating wallet model IMMEDIATELY!');
          print('   walletId: $walletId');
          print('   transparent: ${_addresses['transparent']?.length ?? 0}');
          print('   shielded: ${_addresses['shielded']?.length ?? 0}');
          print('   storedBirthday: $storedBirthday');
        }
        
        try {
          _wallet = WalletModel(
            walletId: walletId,
            transparentAddresses: _addresses['transparent'] ?? [],
            shieldedAddresses: _addresses['shielded'] ?? [],
            createdAt: DateTime.now(),
            birthdayHeight: storedBirthday,
          );
          
          if (kDebugMode) {
            print('✅ Wallet model created successfully!');
            print('   hasWallet: $hasWallet');
            print('   birthdayHeight: ${_wallet!.birthdayHeight}');
          }
          
          // Load cached balance if available
          if (walletData['cachedBalance'] != null) {
            try {
              final cachedBalance = walletData['cachedBalance'];
              _balance = BalanceModel(
                transparent: cachedBalance['transparent']?.toDouble() ?? 0.0,
                shielded: cachedBalance['shielded']?.toDouble() ?? 0.0,
                unconfirmed: cachedBalance['unconfirmed']?.toDouble() ?? 0.0,
                total: cachedBalance['total']?.toDouble() ?? 0.0,
              );
              if (kDebugMode) print('💰 Loaded cached balance: ${_balance.total} BTCZ');
            } catch (e) {
              if (kDebugMode) print('⚠️ Failed to load cached balance: $e');
            }
          }
          
          // Notify UI immediately with cached data
          notifyListeners();
          
          // DEFENSIVE: Mark this wallet as "locked in" to prevent resets during Rust init
          _walletLocked = true;
          if (kDebugMode) print('🔒 Wallet model locked to prevent resets during background initialization');
          
        } catch (e) {
          if (kDebugMode) print('❌ Failed to create wallet model: $e');
          // Create minimal wallet as fallback
          _wallet = WalletModel(
            walletId: walletId,
            transparentAddresses: [],
            shieldedAddresses: [],
            createdAt: DateTime.now(),
            birthdayHeight: 0,
          );
          notifyListeners();
        }
      }
      
      // Now proceed with Rust initialization if we have seed phrase
      if (seedPhrase != null && walletData != null) {
        // Initialize Rust Bridge service first to get the correct addresses
        if (kDebugMode) {
          print('🦀 Initializing Rust Bridge for restored wallet...');
          print('📱 ANDROID FIX: About to create wallet model with cached data');
        }
        
        // First check if the Rust wallet file already exists
        // If it does, load it; otherwise restore from seed
        bool rustInitialized = false;
        
        try {
          // Try to load existing wallet first, passing the birthday height
          final storedBirthdayLocal = walletData['birthdayHeight'] ?? walletData['birthday'] ?? 0;
          if (kDebugMode) {
            print('   🔄 Attempting to LOAD existing Rust wallet...');
            print('   📊 Birthday Height Processing:');
            print('     Raw storage value: $storedBirthdayLocal (${storedBirthdayLocal.runtimeType})');
            print('     Source: ${walletData.containsKey('birthdayHeight') ? 'birthdayHeight key' : walletData.containsKey('birthday') ? 'birthday key' : 'default 0'}');
          }
          
          // Pass birthday height as int, ensuring it's not null
          final birthdayToUse = storedBirthdayLocal is int ? storedBirthdayLocal : 
                               (storedBirthdayLocal != null ? int.tryParse(storedBirthdayLocal.toString()) ?? 0 : 0);
          
          if (kDebugMode) {
            print('     Processed value: $birthdayToUse (${birthdayToUse.runtimeType})');
            print('     Will pass to Rust: ${birthdayToUse > 0 ? birthdayToUse : null}');
            print('     🚨 CRITICAL: This should NOT be 0 on Android if wallet exists!');
          }
          
          rustInitialized = await _rustService.initialize(
            serverUri: 'https://lightd.btcz.rocks:9067',
            createNew: false,  // Don't create new
            seedPhrase: null,  // Don't provide seed, load existing
            birthdayHeight: birthdayToUse > 0 ? birthdayToUse : null,  // Pass valid birthday or null
          );
          
          if (rustInitialized) {
            if (kDebugMode) print('✅ Loaded existing Rust wallet successfully with birthday: $birthdayToUse');
          }
        } catch (e) {
          if (kDebugMode) print('❌ Failed to load existing wallet: $e');
          // Don't fail here, try to restore from seed
        }
        
        // If loading existing wallet failed, restore from seed
        if (!rustInitialized) {
          try {
            // CRITICAL FIX: Pass the stored birthday height to prevent syncing from zero!
            final storedBirthdayLocal = walletData['birthdayHeight'] ?? walletData['birthday'] ?? 0;
            final birthdayToUse = storedBirthdayLocal is int ? storedBirthdayLocal : 
                                 (storedBirthdayLocal != null ? int.tryParse(storedBirthdayLocal.toString()) ?? 0 : 0);
            
            if (kDebugMode) {
              print('🚨 ANDROID FIX: SEED PHRASE RESTORATION (Critical Path)');
              print('   📊 Birthday Height Processing:');
              print('     Raw storage value: $storedBirthdayLocal (${storedBirthdayLocal.runtimeType})');
              print('     Source: ${walletData.containsKey('birthdayHeight') ? 'birthdayHeight key' : walletData.containsKey('birthday') ? 'birthday key' : 'default 0'}');
              print('     Processed value: $birthdayToUse (${birthdayToUse.runtimeType})');
              print('     Will pass to Rust: ${birthdayToUse > 0 ? birthdayToUse : null}');
              print('   🎯 THIS IS THE CRITICAL FIX: If birthday > 0, Android should NOT sync from zero!');
              print('   🔍 Root cause was: this fallback path was passing null birthday, causing zero sync');
            }
            
            rustInitialized = await _rustService.initialize(
              serverUri: 'https://lightd.btcz.rocks:9067',
              seedPhrase: seedPhrase,
              createNew: false, // Restore from seed
              birthdayHeight: birthdayToUse > 0 ? birthdayToUse : null, // CRITICAL: Pass birthday height!
            );
            
            if (rustInitialized) {
              if (kDebugMode) print('✅ Rust Bridge restored from seed successfully with birthday: $birthdayToUse');
            }
          } catch (e) {
            if (kDebugMode) print('⚠️ Rust Bridge initialization failed: $e');
            // Don't throw - continue with cached data
            _setConnectionStatus(false, 'Server unreachable - using cached data');
          }
        }
        
        // Addresses already loaded and wallet already created above
        // Just update if we get fresh addresses from Rust
        
        // Then update with fresh addresses from Rust if available (non-blocking)
        if (rustInitialized) {
          if (kDebugMode) print('🔄 Fetching fresh addresses from Rust Bridge in background...');
          // Fetch addresses but don't wait - they'll update via callback
          _rustService.fetchAddresses().then((_) {
            if (kDebugMode) print('✅ Fresh addresses fetched from Rust');
            // Update wallet model if addresses changed
            if (_wallet != null && 
                (_addresses['transparent']?.length != _wallet!.transparentAddresses.length ||
                 _addresses['shielded']?.length != _wallet!.shieldedAddresses.length)) {
              _wallet = WalletModel(
                walletId: _wallet!.walletId,
                transparentAddresses: _addresses['transparent'] ?? [],
                shieldedAddresses: _addresses['shielded'] ?? [],
                createdAt: _wallet!.createdAt,
                birthdayHeight: _wallet!.birthdayHeight,
              );
              notifyListeners();
            }
          }).catchError((e) {
            if (kDebugMode) print('⚠️ Failed to fetch fresh addresses: $e');
          });
        }
        
        // Update stored wallet data with correct Rust Bridge addresses and cached balance
        await authProvider.updateWalletData({
          'walletId': _wallet?.walletId ?? walletData['walletId'],
          'transparentAddresses': _addresses['transparent'] ?? [],
          'shieldedAddresses': _addresses['shielded'] ?? [],
          'birthdayHeight': _wallet?.birthdayHeight ?? walletData['birthdayHeight'] ?? 0,  // Use wallet's birthday
          'createdAt': walletData['createdAt'] ?? DateTime.now().toIso8601String(),
          'updatedAt': DateTime.now().toIso8601String(),
          'cachedBalance': {
            'transparent': _balance.transparent,
            'shielded': _balance.shielded,
            'unconfirmed': _balance.unconfirmed,
            'total': _balance.total,
          },
        });
        
        if (kDebugMode) {
          print('✅ Wallet restored with Rust Bridge addresses:');
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
        
        // Set connection status immediately after Rust initialization
        if (_rustService.initialized) {
          _setConnectionStatus(true, 'Connected to server');
          if (kDebugMode) print('✅ Rust service initialized, marking as connected');
        } else {
          _setConnectionStatus(false, 'Initializing...');
          if (kDebugMode) print('⏳ Rust service not yet initialized');
        }
        
        // Initialize connection and sync
        await _checkConnection();
        
        // Always try to sync immediately like BitcoinZ Blue (same as other branch)
        // Always check if the Rust service is actually initialized
        if (kDebugMode) print('🤔 Checking if should start sync: rustInitialized=$rustInitialized, _rustService.initialized=${_rustService.initialized}');
        if (_rustService.initialized) {
          // Start sync immediately, not in background
          if (kDebugMode) print('🚀 Starting initial sync like BitcoinZ Blue...');
          _setSyncing(true);
          _startSyncStatusPolling();
          
          // Trigger sync right away
          Future(() async {
            try {
              if (kDebugMode) print('🔄 Triggering wallet sync...');
              // Use Rust service sync directly
              await _rustService.sync();
              
              // Also try to get initial sync status
              await _updateSyncStatus();
              
              // Explicitly refresh all wallet data to ensure transactions are loaded
              if (kDebugMode) print('📊 Loading wallet data after sync...');
              await _refreshWalletData();
              
              // Force a second refresh after a short delay to catch any delayed data
              await Future.delayed(const Duration(seconds: 2));
              if (kDebugMode) print('📊 Second refresh to ensure all data is loaded...');
              await _refreshWalletData();
            } catch (e) {
              if (kDebugMode) print('Initial sync error: $e');
            }
          });
        } else {
          // Load cached data when offline
          if (kDebugMode) print('📱 Loading cached data (offline mode)...');
          await _refreshWalletData();
        }
        
        // Start auto-sync after restoration
        startAutoSync();
        
        // Don't call notifyListeners() here since we already called it after creating wallet model
        
        // DEFENSIVE: Unlock wallet after successful initialization
        _unlockWallet();
        
        return true;
      } else if (seedPhrase != null) {
        // Have seed phrase but no wallet data - create basic wallet first
        if (kDebugMode) print('⚠️ Have seed phrase but no wallet data, creating basic wallet...');
        
        // Create a basic wallet model immediately
        final walletId = authProvider.walletId ?? 'wallet_${DateTime.now().millisecondsSinceEpoch}';
        
        _wallet = WalletModel(
          walletId: walletId,
          transparentAddresses: [],
          shieldedAddresses: [],
          createdAt: DateTime.now(),
          birthdayHeight: 0,
        );
        
        if (kDebugMode) {
          print('📱 Created basic wallet model');
          print('   walletId: $walletId');
          print('   hasWallet: $hasWallet');
        }
        
        notifyListeners();
        
        // Initialize Rust Bridge with seed phrase
        final rustInitialized = await _rustService.initialize(
          serverUri: 'https://lightd.btcz.rocks:9067',
          seedPhrase: seedPhrase,
          createNew: false, // Restore from seed
        );
        
        if (!rustInitialized) {
          throw Exception('Failed to initialize Rust Bridge');
        }
        
        // Get addresses from Rust Bridge
        await _rustService.fetchAddresses();
        await Future.delayed(const Duration(milliseconds: 500));
        
        // Update the existing wallet model with fresh addresses
        if (_wallet != null && (_addresses['transparent']?.isNotEmpty == true || _addresses['shielded']?.isNotEmpty == true)) {
          _wallet = WalletModel(
            walletId: _wallet!.walletId,
            transparentAddresses: _addresses['transparent'] ?? [],
            shieldedAddresses: _addresses['shielded'] ?? [],
            createdAt: _wallet!.createdAt,
            birthdayHeight: 0,
          );
          
          if (kDebugMode) {
            print('📱 Updated wallet with Rust addresses');
            print('   transparent: ${_addresses['transparent']?.length ?? 0}');
            print('   shielded: ${_addresses['shielded']?.length ?? 0}');
          }
          
          notifyListeners();
        }
        
        // Update stored wallet data with Rust Bridge addresses
        await authProvider.updateWalletData({
          'walletId': _wallet!.walletId,
          'transparentAddresses': _addresses['transparent'] ?? [],
          'shieldedAddresses': _addresses['shielded'] ?? [],
          'createdAt': DateTime.now().toIso8601String(),
        });
        
        // Set connection status immediately after Rust initialization
        if (_rustService.initialized) {
          _setConnectionStatus(true, 'Connected to server');
          if (kDebugMode) print('✅ Rust service initialized, marking as connected');
        } else {
          _setConnectionStatus(false, 'Initializing...');
          if (kDebugMode) print('⏳ Rust service not yet initialized');
        }
        
        await _checkConnection();
        
        // Always try to sync immediately like BitcoinZ Blue
        // Always check if the Rust service is actually initialized
        if (kDebugMode) print('🤔 Checking if should start sync (branch 2): rustInitialized=$rustInitialized, _rustService.initialized=${_rustService.initialized}');
        if (_rustService.initialized) {
          // Start sync immediately, not in background
          if (kDebugMode) print('🚀 Starting initial sync like BitcoinZ Blue (branch 2)...');
          _setSyncing(true);
          _startSyncStatusPolling();
          
          // Trigger sync right away
          Future(() async {
            try {
              if (kDebugMode) print('🔄 Triggering wallet sync (second branch)...');
              // Use Rust service sync directly
              await _rustService.sync();
              // Also try to get initial sync status
              await _updateSyncStatus();
              await _refreshWalletData();
            } catch (e) {
              if (kDebugMode) print('Initial sync error: $e');
            }
          });
        } else {
          // Load cached data when offline
          await _refreshWalletData();
          // Try to reconnect in background
          _scheduleReconnectionAttempt();
        }
        
        startAutoSync();
        
        // DEFENSIVE: Unlock wallet after successful initialization
        _unlockWallet();
        
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
    
    // Check if Rust Bridge is initialized
    if (!_rustService.initialized && _wallet?.walletId?.startsWith('cli_imported_') != true) {
      if (kDebugMode) print('⚠️ Cannot sync - Rust Bridge not initialized');
      _scheduleReconnectionAttempt();
      return;
    }

    // Don't show sync UI for background refreshes
    // This is called every 60 seconds so we don't want the UI popping up
    // Only set syncing flag for initial sync or manual sync
    final isInitialSync = _transactions.isEmpty || _balance == null;
    
    if (isInitialSync) {
      _setSyncing(true);
      
      // Start polling for sync status (for Rust Bridge)
      if (_wallet?.walletId?.startsWith('cli_imported_') != true) {
        _startSyncStatusPolling();
      }
    } else {
      // For routine refreshes, just do a silent update
      if (kDebugMode) print('🔄 Silent background refresh (no UI)...');
    }
    
    try {
      // Check if this is a CLI wallet
      if (_wallet?.walletId?.startsWith('cli_imported_') == true) {
        // For CLI wallets, just refresh the data from CLI
        await _loadCliBalance(); // Only load balance in background
      } else {
        // For Rust FFI wallets, sync directly with Rust service
        await _rustService.sync();
        // Don't call _loadBalance() as it uses BitcoinZService which isn't initialized
        // The Rust service will update balance via callbacks
        await _refreshWalletData(); // Refresh all data after sync
      }
      _lastSyncTime = DateTime.now();
    } catch (e) {
      // Don't show error for background sync failures
      debugPrint('Background sync failed: $e');
    } finally {
      // Only stop sync UI if we started it
      if (isInitialSync) {
        _setSyncing(false);
        _stopSyncStatusPolling();
      }
    }
  }

  /// Full sync wallet with blockchain
  /// Start sync status polling (like BitcoinZ Blue)
  void _startSyncStatusPolling() {
    _stopSyncStatusPolling();
    
    if (kDebugMode) print('🔄 Starting sync status polling...');
    if (kDebugMode) print('   Rust service initialized: ${_rustService.initialized}');
    
    // Track when polling started to prevent infinite loops
    final pollingStartTime = DateTime.now();
    const maxPollingDuration = Duration(minutes: 5); // Maximum 5 minutes of polling
    
    // Poll every second for sync status
    _syncStatusTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      // Check if we've been polling too long
      if (DateTime.now().difference(pollingStartTime) > maxPollingDuration) {
        if (kDebugMode) print('⏰ Sync polling timeout - stopping after 5 minutes');
        _stopSyncStatusPolling();
        _setSyncing(false);
        _setConnectionStatus(true, 'Connected');
        return;
      }
      
      await _updateSyncStatus();
    });
    
    // Initial status check
    if (kDebugMode) print('   Triggering initial sync status check...');
    Future.microtask(() => _updateSyncStatus());
  }
  
  /// Stop sync status polling
  void _stopSyncStatusPolling() {
    _syncStatusTimer?.cancel();
    _syncStatusTimer = null;
  }
  
  /// Schedule a reconnection attempt when offline
  void _scheduleReconnectionAttempt() {
    if (kDebugMode) print('📡 Scheduling reconnection attempt...');
    
    // Try to reconnect every 10 seconds
    Future.delayed(const Duration(seconds: 10), () async {
      if (!_rustService.initialized && hasWallet) {
        try {
          if (kDebugMode) print('🔄 Attempting to reconnect to server...');
          
          // Get the seed phrase from storage
          final authProvider = AuthProvider();
          final seedPhrase = await authProvider.getSeedPhrase();
          
          if (seedPhrase != null) {
            final connected = await _rustService.initialize(
              serverUri: 'https://lightd.btcz.rocks:9067',
              seedPhrase: seedPhrase,
              createNew: false,
            );
            
            if (connected) {
              if (kDebugMode) print('✅ Reconnected successfully!');
              _setConnectionStatus(true, 'Connected to server');
              
              // Now sync the wallet
              syncWalletInBackground();
            } else {
              // Schedule another attempt
              _scheduleReconnectionAttempt();
            }
          }
        } catch (e) {
          if (kDebugMode) print('❌ Reconnection failed: $e');
          // Schedule another attempt
          _scheduleReconnectionAttempt();
        }
      }
    });
  }
  
  /// Start early connection before PIN authentication
  /// This checks server connectivity while the user is entering their PIN
  /// Only sets status to offline if server is actually unreachable
  Future<void> startEarlyConnection() async {
    if (kDebugMode) print('🔌 Checking server connectivity...');
    
    try {
      // Check if we already have a connection
      if (_rustService.initialized) {
        if (kDebugMode) print('✅ Already connected to server');
        _setConnectionStatus(true, 'Connected');
        return;
      }
      
      // Try a quick server connectivity check
      // We're not initializing the wallet yet, just checking if server is reachable
      try {
        // For now, we'll assume server is online unless we have evidence otherwise
        // Real server check would happen during wallet initialization
        
        // Quick check with timeout
        await Future.delayed(const Duration(milliseconds: 200));
        
        // If we got here without error, server seems reachable
        if (kDebugMode) print('✅ Server appears to be reachable');
        // Don't set any status - follow Black Amber philosophy of minimal UI
        _setConnectionStatus(true, '');  // Empty status = no message shown
        
      } catch (e) {
        // Only show offline if we actually can't reach the server
        if (kDebugMode) print('❌ Server appears to be offline: $e');
        _setConnectionStatus(false, 'Server offline');
      }
      
      // The actual wallet initialization will happen after PIN authentication
      // in restoreFromStoredData() or loadCliWallet()
    } catch (e) {
      if (kDebugMode) print('⚠️ Server connectivity check failed: $e');
      // Only show offline status for real failures
      _setConnectionStatus(false, 'Server offline');
    }
  }
  
  /// Check connection status (called periodically)
  Future<void> checkConnectionStatus() async {
    if (kDebugMode) {
      print('🔍 checkConnectionStatus: hasWallet=$hasWallet, _wallet=$_wallet, rustInitialized=${_rustService.initialized}');
    }
    
    // Check if we actually have a wallet
    if (!hasWallet) {
      // Don't show "No wallet" if we're in the process of loading
      if (_isLoading) {
        _setConnectionStatus(false, 'Loading...');
      } else {
        _setConnectionStatus(false, 'No wallet');
      }
      return;
    }
    
    // If Rust service is initialized and we have a wallet, proceed
    if (_rustService.initialized) {
      if (kDebugMode) print('✅ Rust service initialized, proceeding with connection check');
    } else {
      _setConnectionStatus(false, 'Not initialized');
      return;
    }
    
    try {
      // Check if Rust service is initialized
      if (_rustService.initialized) {
        // Try to get sync status as a connection check
        final status = await _rustService.getSyncStatus();
        if (status != null) {
          _setConnectionStatus(true, 'Connected');
          _lastConnectionCheck = DateTime.now();
        } else {
          _setConnectionStatus(false, 'Disconnected');
        }
      } else {
        _setConnectionStatus(false, 'Not initialized');
        // Try to reconnect
        _scheduleReconnectionAttempt();
      }
    } catch (e) {
      _setConnectionStatus(false, 'Connection error');
      if (kDebugMode) print('❌ Connection check failed: $e');
    }
  }
  
  /// Update sync status from Rust Bridge
  Future<void> _updateSyncStatus() async {
    if (!_rustService.initialized) {
      if (kDebugMode) print('⚠️ Rust service not initialized, skipping sync status update');
      return;
    }
    
    try {
      final status = await _rustService.getSyncStatus();
      if (status == null) {
        if (kDebugMode) print('⚠️ No sync status available');
        return;
      }
      
      if (kDebugMode) {
        print('📊 Sync status update: $status');
      }
      
      final inProgress = status['in_progress'] ?? false;
      
      if (inProgress) {
        _setSyncing(true);  // Ensure syncing flag is set
        
        // Track sync start time
        if (_syncStartTime == null) {
          _syncStartTime = DateTime.now();
          _lastSyncedBlocks = 0;
        }
        
        _syncedBlocks = status['synced_blocks'] ?? 0;
        _totalBlocks = status['total_blocks'] ?? 0;
        _batchNum = status['batch_num'] ?? 0;
        _batchTotal = status['batch_total'] ?? 0;
        
        // Calculate sync speed and ETA
        if (_syncStartTime != null && _syncedBlocks > _lastSyncedBlocks) {
          final elapsed = DateTime.now().difference(_syncStartTime!);
          if (elapsed.inSeconds > 0) {
            final blocksProcessed = _syncedBlocks - _lastSyncedBlocks;
            _syncSpeed = blocksProcessed / elapsed.inSeconds;
            
            if (_syncSpeed > 0 && _totalBlocks > _syncedBlocks) {
              final blocksRemaining = _totalBlocks - _syncedBlocks;
              final secondsRemaining = blocksRemaining / _syncSpeed;
              _estimatedTimeRemaining = Duration(seconds: secondsRemaining.round());
            }
          }
        }
        
        // Calculate progress exactly like BitcoinZ Blue
        double batchProgress = 0.0;
        double totalProgress = 0.0;
        
        if (_totalBlocks > 0) {
          batchProgress = (_syncedBlocks * 100.0) / _totalBlocks;
          totalProgress = batchProgress;
        }
        
        if (_batchTotal > 0 && _batchNum > 0) {
          final base = ((_batchNum - 1) * 100.0) / _batchTotal;
          totalProgress = base + (batchProgress / _batchTotal);
        }
        
        _syncProgress = totalProgress.clamp(0.0, 100.0);
        
        // Create sync message (BitcoinZ Blue format)
        if (_batchTotal > 0) {
          _syncMessage = 'Syncing batch $_batchNum of $_batchTotal';
        } else {
          _syncMessage = 'Syncing...';
        }
        
        if (kDebugMode) {
          print('📊 $_syncMessage');
          print('   Batch Progress: ${batchProgress.toStringAsFixed(2)}%. Total progress: ${totalProgress.toStringAsFixed(2)}%.');
          if (_syncSpeed > 0) {
            print('   Sync speed: ${_syncSpeed.toStringAsFixed(1)} blocks/sec');
            if (_estimatedTimeRemaining != null) {
              print('   ETA: ${_estimatedTimeRemaining!.inSeconds} seconds');
            }
          }
        }
      } else {
        // Sync completed - IMMEDIATELY stop showing as syncing
        // Don't show 100% indefinitely
        
        // Stop polling immediately when sync is complete
        _stopSyncStatusPolling();
        
        // Clear sync progress to prevent stuck "100%" display
        if (_syncProgress >= 100.0 || !inProgress) {
          _syncProgress = 0.0; // Reset progress so it doesn't show 100%
          _syncMessage = ''; // Clear message to prevent stuck "Syncing... 100.0% complete"
        }
        
        _lastSyncTime = DateTime.now();
        
        if (kDebugMode) {
          print('✅ Sync complete');
          if (_syncStartTime != null) {
            final totalTime = DateTime.now().difference(_syncStartTime!);
            print('   Total sync time: ${totalTime.inSeconds} seconds');
          }
          print('   Clearing sync UI to prevent stuck 100% display');
        }
        
        // Reset all sync tracking immediately
        _syncStartTime = null;
        _syncSpeed = 0.0;
        _estimatedTimeRemaining = null;
        _syncedBlocks = 0;
        _totalBlocks = 0;
        _batchNum = 0;
        _batchTotal = 0;
        
        // Set connection status to green (ready) like macOS
        _setConnectionStatus(true, 'Connected');
        
        // Immediately clear syncing flag - don't delay
        _setSyncing(false);
        
        // Refresh wallet data after sync (unless it was a timeout)
        if (!(status['timeout'] ?? false)) {
          _refreshWalletData();
        }
      }
      
      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('❌ Failed to update sync status: $e');
    }
  }
  
  Future<void> syncWallet() async {
    if (!hasWallet) return;

    _setSyncing(true);  // Set syncing flag for manual sync
    _syncMessage = 'Starting sync...';  // Show initial message
    _syncProgress = 0.0;  // Reset progress
    _clearError();
    notifyListeners();  // Update UI immediately
    
    // Start polling for sync status
    _startSyncStatusPolling();

    try {
      // Check if this is a CLI wallet
      if (_wallet?.walletId?.startsWith('cli_imported_') == true) {
        // For CLI wallets, refresh all data from CLI
        await _refreshCliWalletData();
      } else {
        // For Rust FFI wallets, use the Rust service sync
        await _rustService.sync();
        await _refreshWalletData();
      }
      _lastSyncTime = DateTime.now();
      await _checkConnection(); // Update connection status after sync
    } catch (e) {
      _setError('Failed to sync wallet: $e');
      _setConnectionStatus(false, 'Sync failed');
    } finally {
      _setSyncing(false);
      _stopSyncStatusPolling();
    }
  }
  
  /// Check server connection status
  Future<void> _checkConnection() async {
    try {
      if (kDebugMode) {
        print('🔍 _checkConnection: walletId=${_wallet?.walletId}, isCliWallet=${_wallet?.walletId?.startsWith('cli_imported_')}');
      }
      
      // If Rust service is initialized, we consider it connected
      // The Rust service handles its own connection internally
      if (_rustService.initialized) {
        _setConnectionStatus(true, 'Connected to server');
        if (kDebugMode) print('✅ Rust service is initialized, marking as connected');
        
        // Try to get block height for additional verification (non-blocking)
        try {
          final blockHeight = await _rustService.getCurrentBlockHeight();
          if (blockHeight != null && blockHeight > 0) {
            if (kDebugMode) print('✅ Connected: Block height $blockHeight');
          }
        } catch (e) {
          // Don't change connection status if block height check fails
          // Rust service is still initialized and handling connection
          if (kDebugMode) print('⚠️ Block height check failed but Rust service is initialized: $e');
        }
      } else {
        _setConnectionStatus(false, 'Server unreachable');
        if (kDebugMode) print('❌ Disconnected: Rust service not initialized');
      }
    } catch (e) {
      _setConnectionStatus(false, 'Connection error');
    }
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
      
      // Always use Rust service for sending transactions
      // The BitcoinZService native library doesn't exist, so we use the working Rust bridge
      if (kDebugMode) {
        print('📤 Sending via Rust Bridge: $amount BTCZ to $toAddress');
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
      
      // Quick refresh wallet data
      await _refreshCliWalletData();
      
      // Force immediate Rust Bridge refresh to detect the newly sent transaction
      if (kDebugMode) print('🦀 Forcing immediate Rust Bridge refresh after send...');
      
      // Give the wallet a moment to register the transaction
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Rust service automatically triggers refresh after send
      // Mempool monitoring will pick up the transaction immediately
      
      // Also trigger a full refresh to ensure UI updates
      await _refreshWalletData();
      
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
        // For Rust FFI wallets, generate new address via Rust service
        final newAddress = await _rustService.getNewAddress(
          transparent: addressType == 'transparent'
        );
        if (newAddress != null) {
          // Refresh addresses to include the new one
          await _rustService.fetchAddresses();
          return newAddress;
        }
        return '';
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
      final status = await _rustService.getSyncStatus();
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
      // Encryption not yet implemented in Rust service
      // TODO: Implement encryption in Rust service
      throw UnimplementedError('Message encryption not yet implemented');
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
      // Decryption not yet implemented in Rust service
      // TODO: Implement decryption in Rust service
      throw UnimplementedError('Message decryption not yet implemented');
    } catch (e) {
      _setError('Failed to decrypt message: $e');
      return null;
    }
  }

  /// Private helper methods
  Future<void> _refreshWalletData() async {
    if (kDebugMode) print('🔄 _refreshWalletData called...');
    
    // Always use Rust Bridge for all wallets (provides mempool monitoring)
    if (_rustService.initialized) {
      if (kDebugMode) print('   Using Rust Bridge for wallet refresh');
      
      // Don't trigger sync UI for routine refreshes
      // The Rust service refresh is lightweight and doesn't need UI
      try {
        // Skip the full refresh which includes sync - just fetch the data directly
        // The sync is hanging on Android, so we'll fetch data without syncing
        
        if (kDebugMode) print('   Fetching balance...');
        await _rustService.fetchBalance();
        
        if (kDebugMode) print('   Fetching transactions...');
        await _rustService.fetchTransactions();
        
        if (kDebugMode) print('   Fetching addresses...');
        await _rustService.fetchAddresses();
        
        if (kDebugMode) print('✅ Wallet data refresh complete');
      } catch (e) {
        if (kDebugMode) print('⚠️ Error refreshing wallet data: $e');
      }
    } else {
      if (kDebugMode) print('   Rust Bridge not initialized, using fallback refresh');
      
      // Load data from Rust service callbacks
      // The Rust service automatically updates via callbacks
      // No need to manually load here as the callbacks handle it
      if (kDebugMode) print('⚠️ Relying on Rust service callbacks for data updates');
      notifyListeners();
    }
    
    // Note: Rust Bridge service is now the single source of truth for all data
  }

  Future<void> _loadBalance() async {
    try {
      // Trigger balance fetch from Rust service
      // The Rust service updates balance via callbacks automatically
      await _rustService.fetchBalance();
      // Balance will be updated via callback
      // For now, keep existing balance to avoid null
    } catch (e) {
      // Don't rethrow, just log the error
      if (kDebugMode) print('⚠️ Could not load balance from Rust service: $e');
      // Return empty balance to avoid crashes
      _balance ??= BalanceModel(
        transparent: 0,
        shielded: 0,
        total: 0,
        unconfirmed: 0,
        unconfirmedTransparent: 0,
        unconfirmedShielded: 0,
      );
    }
  }

  Future<void> _loadTransactions() async {
    try {
      // Trigger transactions fetch from Rust service
      // Transactions are updated via callback
      await _rustService.fetchTransactions();
      // Sort by timestamp, newest first
      _transactions.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _loadAddresses() async {
    try {
      // Trigger addresses fetch from Rust service
      // Addresses are updated via callback
      await _rustService.fetchAddresses();
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
        unconfirmedTransparent: 0, // CLI doesn't provide this breakdown
        unconfirmedShielded: unconfirmedBalance / 100000000, // Assume shielded for CLI
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

  /// Mark a transaction memo as read
  Future<void> markMemoAsRead(String txid) async {
    try {
      // Update in-memory cache first
      _memoReadStatusCache[txid] = true;
      
      // Always save to SharedPreferences for persistence
      await _saveMemoStatusToPrefs(txid, true);
      
      // Also try to update in database (but don't fail if it doesn't work)
      try {
        await _databaseService.markTransactionMemoAsRead(txid);
      } catch (dbError) {
        if (kDebugMode) print('⚠️ Database update failed (using SharedPreferences): $dbError');
      }
      
      // Update in memory
      final index = _transactions.indexWhere((tx) => tx.txid == txid);
      if (index != -1) {
        _transactions[index] = _transactions[index].copyWith(memoRead: true);
      }
      
      // Update unread count
      await updateUnreadMemoCount();
      
      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('❌ Error marking memo as read: $e');
    }
  }
  
  /// Update the count of unread memos
  Future<void> updateUnreadMemoCount() async {
    // Always use the same method as the transaction list for consistency
    // Don't use database since we're storing memo status in SharedPreferences
    _unreadMemoCount = _transactions.where((tx) {
      if (!tx.hasMemo) return false;
      // Use the exact same helper method as transaction list uses
      final isRead = getTransactionMemoReadStatus(tx.txid, tx.memoRead);
      return !isRead;
    }).length;
    
    if (kDebugMode) print('📊 Unread memo count: $_unreadMemoCount (from ${_transactions.where((tx) => tx.hasMemo).length} total memos)');
    notifyListeners();
  }
  
  /// Get transactions with unread memos
  List<TransactionModel> getUnreadMemoTransactions() {
    return _transactions.where((tx) {
      if (!tx.hasMemo) return false;
      // Use the same helper method for consistency
      final isRead = getTransactionMemoReadStatus(tx.txid, tx.memoRead);
      return !isRead;
    }).toList();
  }
  
  /// Set the context for showing notifications
  void setNotificationContext(BuildContext context) {
    _notificationContext = context;
  }
  
  /// Show notification for new memo transactions
  void _notifyNewMemoTransactions(List<TransactionModel> newMemoTransactions) {
    if (_notificationContext == null || !_notificationContext!.mounted) return;
    
    for (final tx in newMemoTransactions) {
      final String amount = tx.isReceived 
          ? '+${tx.amount.toStringAsFixed(8)} BTCZ'
          : '-${tx.amount.toStringAsFixed(8)} BTCZ';
      
      final String memoSnippet = tx.memo != null && tx.memo!.length > 30
          ? '${tx.memo!.substring(0, 30)}...'
          : tx.memo ?? '';
      
      // Show snackbar notification
      ScaffoldMessenger.of(_notificationContext!).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.message,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'New message received!',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$amount${memoSnippet.isNotEmpty ? ' • $memoSnippet' : ''}',
                      style: const TextStyle(fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          backgroundColor: Theme.of(_notificationContext!).colorScheme.primary,
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          action: SnackBarAction(
            label: 'VIEW',
            textColor: Colors.white,
            onPressed: () {
              // Navigate to transaction details
              _showTransactionDetails(tx);
            },
          ),
        ),
      );
      
      // Log for debugging
      if (kDebugMode) {
        print('📬 NEW MEMO TRANSACTION: ${tx.txid.substring(0, 8)}... - $amount');
        print('   Memo: $memoSnippet');
      }
    }
  }
  
  /// Show transaction details (for notification tap)
  void _showTransactionDetails(TransactionModel transaction) {
    if (_notificationContext == null || !_notificationContext!.mounted) return;
    
    // Mark as read
    markMemoAsRead(transaction.txid);
    
    // Navigate to transaction history with this transaction highlighted
    Navigator.of(_notificationContext!).push(
      MaterialPageRoute(
        builder: (context) => const PaginatedTransactionHistoryScreen(),
        settings: RouteSettings(
          arguments: {'highlightTxid': transaction.txid},
        ),
      ),
    );
  }
  
  /// Clear all wallet data (for logout)
  void clearWallet() {
    // DEFENSIVE: Check if wallet is locked to prevent accidental clears during initialization
    if (_walletLocked) {
      if (kDebugMode) print('🔒 Wallet is locked, ignoring clearWallet request to prevent data loss');
      return;
    }
    
    stopAutoSync();
    _wallet = null;
    _walletLocked = false; // Reset lock when explicitly clearing
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
  
  
  /// Initialize SharedPreferences and load memo status
  Future<void> _initializePreferences() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _prefsInitialized = true;
      await _loadMemoStatusFromPrefs();
      if (kDebugMode) print('📱 SharedPreferences initialized with ${_memoReadStatusCache.length} memo statuses');
    } catch (e) {
      if (kDebugMode) print('⚠️ Failed to initialize SharedPreferences: $e');
    }
  }
  
  /// Ensure SharedPreferences is initialized (call before wallet operations)
  Future<void> ensurePreferencesInitialized() async {
    if (!_prefsInitialized) {
      await _initializePreferences();
    }
  }
  
  /// Load memo read status from SharedPreferences
  Future<void> _loadMemoStatusFromPrefs() async {
    if (_prefs == null) return;
    
    try {
      final keys = _prefs!.getKeys();
      for (final key in keys) {
        if (key.startsWith('memo_read_')) {
          final txid = key.substring('memo_read_'.length);
          final isRead = _prefs!.getBool(key) ?? false;
          _memoReadStatusCache[txid] = isRead;
        }
      }
      
      if (kDebugMode && _memoReadStatusCache.isNotEmpty) {
        print('📱 Loaded ${_memoReadStatusCache.length} memo read statuses from SharedPreferences');
      }
      
      // Recalculate unread count after loading cache
      await updateUnreadMemoCount();
    } catch (e) {
      if (kDebugMode) print('⚠️ Error loading memo status from SharedPreferences: $e');
    }
  }
  
  /// Save memo read status to SharedPreferences
  Future<void> _saveMemoStatusToPrefs(String txid, bool isRead) async {
    // Wait for SharedPreferences if not ready yet
    if (_prefs == null && !_prefsInitialized) {
      try {
        _prefs = await SharedPreferences.getInstance();
        _prefsInitialized = true;
      } catch (e) {
        if (kDebugMode) print('⚠️ Error initializing SharedPreferences: $e');
        return;
      }
    }
    
    if (_prefs == null) return;
    
    try {
      await _prefs!.setBool('memo_read_$txid', isRead);
      if (kDebugMode) {
        print('💾 Saved memo read status to SharedPreferences: $txid = $isRead');
      }
    } catch (e) {
      if (kDebugMode) print('⚠️ Error saving memo status to SharedPreferences: $e');
    }
  }
  
  /// Get memo read status with fallback
  bool getMemoReadStatus(String txid) {
    // Check cache first (most reliable)
    if (_memoReadStatusCache.containsKey(txid)) {
      return _memoReadStatusCache[txid]!;
    }
    
    // Check SharedPreferences next
    if (_prefs != null) {
      final key = 'memo_read_$txid';
      if (_prefs!.containsKey(key)) {
        final isRead = _prefs!.getBool(key) ?? false;
        _memoReadStatusCache[txid] = isRead;
        return isRead;
      }
    }
    
    // Default to unread for new memos
    return false;
  }
  
  /// Get transaction memo read status for UI display
  /// This ensures consistency between notification count and transaction list
  bool getTransactionMemoReadStatus(String txid, bool defaultValue) {
    // Always check cache first for most up-to-date status
    if (_memoReadStatusCache.containsKey(txid)) {
      return _memoReadStatusCache[txid]!;
    }
    
    // Check SharedPreferences if cache doesn't have it
    if (_prefs != null) {
      final key = 'memo_read_$txid';
      if (_prefs!.containsKey(key)) {
        final isRead = _prefs!.getBool(key) ?? defaultValue;
        // Update cache for next time
        _memoReadStatusCache[txid] = isRead;
        return isRead;
      }
    }
    
    // Fall back to the transaction's own memoRead property
    return defaultValue;
  }
  
  /// Unlock wallet after safe initialization completion
  void _unlockWallet() {
    if (_walletLocked) {
      _walletLocked = false;
      if (kDebugMode) print('🔓 Wallet unlocked - initialization complete and safe');
    }
  }
}