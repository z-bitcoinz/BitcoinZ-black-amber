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
import '../models/message_label.dart';
import '../models/transaction_category.dart';
import '../models/analytics_data.dart';
import '../models/address_label.dart';
// import '../services/bitcoinz_service.dart'; // Not used - using Rust service instead
import '../services/database_service.dart';
import '../services/bitcoinz_rust_service.dart';
import '../providers/auth_provider.dart';
import '../src/rust/api.dart' as rust_api;
import '../providers/network_provider.dart';
import '../screens/wallet/paginated_transaction_history_screen.dart';
import '../utils/constants.dart';

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
  DateTime? _lastSuccessfulRustOperation;
  int? _lastKnownBlockHeight;
  Timer? _syncTimer;

  // Network provider reference
  NetworkProvider? _networkProvider;

  // Simple connection monitoring (single Rust anchor)
  Timer? _simpleConnectionTimer;

  // Simple sync tracking (like BitcoinZ Blue)
  Timer? _syncStatusTimer;
  bool _autoSyncEnabled = true;

  // Comprehensive sync tracking with batch info and ETA
  DateTime? _lastSyncTime;
  String _syncMessage = '';
  double _syncProgress = 0.0;
  DateTime? _syncStartTime;
  bool _isUpdatingSyncStatus = false; // Prevent race conditions
  DateTime? _lastActiveSyncDetected; // Track when we last saw active sync
  int _consecutiveInactivePolls = 0; // Count consecutive inactive polls
  DateTime? _lastSyncUIHideTime; // Track when we should hide sync UI (with grace period)

  // Detailed batch and ETA tracking
  int _currentBatch = 0;
  int _totalBatches = 0;
  int _syncedBlocks = 0;
  int _totalBlocks = 0;
  String _syncETA = '';
  double _batchProgress = 0.0;

  // Simple blockchain tip tracking
  int? _blockchainTip;
  DateTime? _blockchainTipCacheTime;
  static const Duration _blockchainTipCacheDuration = Duration(minutes: 5);


  // Pagination state - optimized for performance
  int _currentPage = 0;
  static const int _pageSize = 40; // Reduced from 50 for better performance
  bool _hasMoreTransactions = true;
  bool _isLoadingMore = false;
  String? _searchQuery;
  String? _filterType;

  // Intelligent caching for large datasets
  final Map<int, List<TransactionModel>> _pageCache = {};
  static const int _maxCachedPages = 5; // Cache up to 5 pages (200 transactions)
  final List<int> _cachedPageOrder = []; // Track page access order for LRU eviction

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

  // Message labels cache for fast access
  final Map<String, List<MessageLabel>> _messageLabelsCache = {};

  // Transaction categories cache for fast access
  final Map<String, TransactionCategory> _transactionCategoriesCache = {};

  // Address labels cache for fast access
  final Map<String, List<AddressLabel>> _addressLabelsCache = {};

  // Analytics cache for performance optimization
  final Map<String, FinancialAnalytics> _analyticsCache = {};
  final Map<String, DateTime> _analyticsCacheTimestamps = {};

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

    // Start simple connection monitoring
    _startSimpleConnectionMonitoring();

    // Initialize Native Rust service with mempool monitoring
    _rustService = BitcoinzRustService.instance;
    _rustService.fnSetTotalBalance = (balance) async {
      if (kDebugMode) print('🦀 Rust Bridge updated balance: ${balance.formattedTotal} BTCZ (unconfirmed: ${balance.unconfirmed})');
      _balance = balance;

      // NOTE: Balance updates can come from cached data, so we don't override connection status here

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

      // NOTE: Transaction updates can come from cached data, so we don't override connection status here

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

      // Cache transactions for faster startup (limit to recent 20 transactions)
      if (_wallet != null) {
        try {
          final authProvider = AuthProvider();
          await authProvider.initialize();
          final walletData = await authProvider.getStoredWalletData();
          if (walletData != null) {
            // Cache only recent transactions (last 20) to keep storage size reasonable
            final recentTransactions = _transactions.take(20).toList();
            walletData['cachedTransactions'] = recentTransactions.map((tx) => tx.toJson()).toList();
            walletData['cacheTimestamp'] = DateTime.now().millisecondsSinceEpoch;
            await authProvider.updateWalletData(walletData);
            if (kDebugMode) print('💾 Cached ${recentTransactions.length} recent transactions');
          }
        } catch (e) {
          if (kDebugMode) print('⚠️ Failed to cache transactions: $e');
        }
      }

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

  /// Start simple connection monitoring using only Rust
  void _startSimpleConnectionMonitoring() {
    if (kDebugMode) print('🔗 Starting simple Rust-only connection monitoring');

    // Single timer that checks connection every 3 seconds - ONLY source of connection status
    _simpleConnectionTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (_rustService.initialized) {
        await _simpleRustConnectionCheck();
      }
    });
  }

  /// Real gRPC connection test - tests actual server connectivity
  /// This is the ONLY method that should set Connected status
  Future<bool> _testRealServerConnection({String? context}) async {
    try {
      final contextMsg = context != null ? ' ($context)' : '';
      if (kDebugMode) print('🔍 REAL gRPC test$contextMsg...');

      // Use rust_api.getServerInfo() to make actual gRPC call to server
      final result = await rust_api.getServerInfo(serverUri: currentServerUrl)
          .timeout(const Duration(seconds: 3));
      final responseData = jsonDecode(result) as Map<String, dynamic>;

      if (responseData.containsKey('success') && responseData['success'] == true) {
        if (kDebugMode) print('✅ REAL server connection SUCCESS$contextMsg');
        _setConnectionStatus(true, 'Connected');
        return true;
      } else {
        final errorMsg = responseData['error'] ?? 'Unknown server error';
        if (kDebugMode) print('❌ REAL server connection FAILED$contextMsg: $errorMsg');
        _setConnectionStatus(false, 'Server error');
        return false;
      }
    } catch (e) {
      final contextMsg = context != null ? ' ($context)' : '';
      if (kDebugMode) print('❌ REAL server connection FAILED$contextMsg: $e');
      _setConnectionStatus(false, 'Connection failed');
      return false;
    }
  }

  /// Legacy method - now uses real connection test
  Future<void> _simpleRustConnectionCheck() async {
    await _testRealServerConnection(context: 'periodic_check');
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

  // Simple sync getters (like BitcoinZ Blue)

  // Enhanced sync tracking getters
  DateTime? get lastSyncTime => _lastSyncTime;
  // Comprehensive sync getters with batch info and ETA
  String get syncMessage => _syncMessage;
  double get syncProgress => _syncProgress;
  int get syncedBlocks => _syncedBlocks;
  int get totalBlocks => _totalBlocks;
  int get currentBatch => _currentBatch;
  int get totalBatches => _totalBatches;
  String get syncETA => _syncETA;
  double get batchProgress => _batchProgress;


  

  


  // Network provider methods
  void setNetworkProvider(NetworkProvider networkProvider) {
    _networkProvider = networkProvider;
  }

  String get currentServerUrl {
    return _networkProvider?.currentServerUrl ?? AppConstants.defaultLightwalletdServer;
  }

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
            serverUri: currentServerUrl,
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
            serverUri: currentServerUrl,
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
          serverUri: currentServerUrl,
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
    print('📱 WALLET_PROVIDER DEBUG: restoreWallet called');
    print('📱 WALLET_PROVIDER DEBUG: seedPhrase length: ${seedPhrase.length}');
    print('📱 WALLET_PROVIDER DEBUG: birthdayHeight: $birthdayHeight');
    print('📱 WALLET_PROVIDER DEBUG: currentServerUrl: $currentServerUrl');
    
    _setLoading(true);
    _clearError();

    try {
      // Restore wallet directly via Rust Bridge with timeout
      if (kDebugMode) print('🦀 Restoring wallet via Rust Bridge...');
      print('📱 WALLET_PROVIDER DEBUG: About to call _rustService.initialize...');
      
      final rustInitialized = await _rustService.initialize(
        serverUri: currentServerUrl,
        seedPhrase: seedPhrase,
        createNew: false,
        birthdayHeight: birthdayHeight,
      ).timeout(
        const Duration(seconds: 45),
        onTimeout: () {
          if (kDebugMode) print('⏱️ Wallet restore initialization timed out');
          print('📱 WALLET_PROVIDER DEBUG: TIMEOUT after 45 seconds');
          return false;
        },
      );
      
      print('📱 WALLET_PROVIDER DEBUG: _rustService.initialize returned: $rustInitialized');

      if (!rustInitialized) {
        throw Exception('Failed to restore wallet via Rust Bridge');
      }

      // Skip data refresh for new wallet restore to prevent hanging
      // The wallet was just initialized, so we'll get minimal data without sync calls
      print('📱 WALLET_PROVIDER DEBUG: Skipping _refreshWalletData() for restore to prevent hanging');
      print('📱 WALLET_PROVIDER DEBUG: Getting basic addresses from Rust service...');
      
      try {
        // Just get addresses without full data refresh to prevent hanging
        await _rustService.fetchAddresses();
        print('📱 WALLET_PROVIDER DEBUG: Basic address fetch completed');
      } catch (e) {
        print('📱 WALLET_PROVIDER DEBUG: Address fetch failed: $e');
        // Continue anyway - we can still create the wallet
      }
      
      // Skip connection check too - it's not critical for wallet creation
      print('📱 WALLET_PROVIDER DEBUG: Skipping _checkConnection() for restore');

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

      // Immediately start sync progress polling and kick off a sync so UI shows progress
      _setSyncing(true);
      _startSyncStatusPolling();

      // Immediately show sync progress indication
      _setSyncing(true);
      _syncMessage = 'Initializing sync...';
      _syncProgress = 0.1; // Show small initial progress
      if (kDebugMode) print('🔔 IMMEDIATE: Setting initial sync progress display');
      notifyListeners(); // Immediate UI update
      
      // Trigger an immediate sync/update cycle
      Future(() async {
        try {
          // First attempt to read current status (in case initialize already started sync)
          await _updateSyncStatus();
          // Then trigger a sync to ensure progress advances during restoration
          await _rustService.sync();
          
          // Force sync progress display immediately after sync trigger
          if (!_isSyncing) {
            _setSyncing(true);
            _syncMessage = 'Starting blockchain sync...';
            _syncProgress = 0.2;
            if (kDebugMode) print('🔔 FORCED: Setting sync progress after sync trigger');
            notifyListeners();
          }
          
          // Update status again and refresh data
          await _updateSyncStatus();
          await _refreshWalletData();
        } catch (e) {
          if (kDebugMode) print('Initial restore sync error: $e');
        }
      });

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

  /// Start background wallet initialization (without authentication)
  /// This allows wallet to sync while PIN screen is shown
  Future<void> startBackgroundInitialization(AuthProvider authProvider) async {
    if (!authProvider.hasWallet) return;

    if (kDebugMode) {
      print('🔄 WalletProvider.startBackgroundInitialization() starting...');
      print('   This allows sync during PIN entry for better UX');
    }

    try {
      // Ensure SharedPreferences is loaded
      await ensurePreferencesInitialized();

      // Start server connection check
      await startEarlyConnection();

      // Start background Rust service initialization (without seed phrase)
      // This prepares the service and starts network sync
      final result = await _rustService.initialize(
        serverUri: currentServerUrl,
        createNew: false,
        seedPhrase: null, // Don't provide seed until authenticated
        birthdayHeight: null, // Will be set later during full restoration
      );

      if (result) {
        // Ensure the UI starts polling and shows progress while Rust is syncing
        _setSyncing(true);
        _syncMessage = 'Initializing sync...';
        _syncProgress = 0.1; // small visible progress to indicate activity
        _startSyncStatusPolling();
        notifyListeners();

        if (kDebugMode) {
          print('✅ Background initialization started successfully');
          print('   Wallet will continue syncing while PIN is entered');
          print('🔄 Started sync status polling from background init path');
        }
      }

    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Background initialization failed (will retry after PIN): $e');
      }
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

          // Load cached transactions if available (for instant display)
          if (walletData['cachedTransactions'] != null) {
            try {
              final cachedTxList = walletData['cachedTransactions'] as List;
              _transactions = cachedTxList.map((tx) => TransactionModel.fromJson(tx as Map<String, dynamic>)).toList();
              if (kDebugMode) print('📋 Loaded ${_transactions.length} cached transactions');
            } catch (e) {
              if (kDebugMode) print('⚠️ Failed to load cached transactions: $e');
              _transactions = [];
            }
          }

          // Set optimistic connection status (assume connected initially for better UX)
          _isConnected = true;
          _connectionStatus = 'Connected';
          if (kDebugMode) print('🔗 Set optimistic connection status: Connected');

          // Notify UI immediately with cached data
          notifyListeners();

          // IMMEDIATE SYNC PROGRESS: Add same immediate display as restoreWallet
          // This fixes the 10-15 second delay when reopening the app during sync
          _setSyncing(true);
          _syncMessage = 'Initializing sync...';
          _syncProgress = 0.1; // Show small initial progress
          _syncStartTime = DateTime.now(); // Track app reopen time for sync progress persistence
          if (kDebugMode) print('🔔 APP REOPEN: Setting immediate sync progress display');
          notifyListeners(); // Immediate UI update

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

          // Pass stored canonical birthday for existing wallet to avoid genesis resync
          final int birthdayToUse = storedBirthdayLocal is int ? storedBirthdayLocal : (storedBirthdayLocal != null ? int.tryParse(storedBirthdayLocal.toString()) ?? 0 : 0);
          if (kDebugMode) {
            print('     Canonical birthdayHeight (stored): $birthdayToUse');
            print('     Will pass to Rust: ${birthdayToUse > 0 ? birthdayToUse : null}');
          }

          rustInitialized = await _rustService.initialize(
            serverUri: currentServerUrl,
            createNew: false,  // Don't create new
            seedPhrase: null,  // Don't provide seed, load existing
            birthdayHeight: birthdayToUse > 0 ? birthdayToUse : null,  // Pass valid birthday or null
          );

          if (rustInitialized) {
            if (kDebugMode) print('✅ Loaded existing Rust wallet successfully (existing wallet, trusting Rust DB)');
            // Align canonical birthday with Rust (lower-only)
            try {
              final rustBday = _rustService.getBirthday();
              final stored = await authProvider.getStoredWalletData() ?? {};
              final existingBday = stored['birthdayHeight'] is int
                ? stored['birthdayHeight'] as int
                : int.tryParse(stored['birthdayHeight']?.toString() ?? '0') ?? 0;
              if ((rustBday ?? 0) > 0 && (existingBday == 0 || rustBday! < existingBday)) {
                stored['birthdayHeight'] = rustBday;
                await authProvider.updateWalletData(stored);
                if (kDebugMode) print('💾 Canonical birthday updated from Rust after init: $rustBday');
              }
            } catch (e) {
              if (kDebugMode) print('⚠️ Failed to align canonical birthday from Rust: $e');
            }
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
              serverUri: currentServerUrl,
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

        // Test real connection status after Rust initialization
        if (_rustService.initialized) {
          if (kDebugMode) print('🔧 Rust service initialized, testing real server connection...');
          await _testRealServerConnection(context: 'after_rust_init');
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

        // FORCED SYNC PROGRESS: Add same immediate display as restoreWallet after sync trigger
        // This ensures consistent behavior between wallet restoration and app reopen
        Future(() async {
          try {
            // Force sync progress display immediately after sync trigger
            if (!_isSyncing) {
              _setSyncing(true);
              _syncMessage = 'Starting blockchain sync...';
              _syncProgress = 0.2;
              if (kDebugMode) print('🔔 APP REOPEN FORCED: Setting sync progress after sync trigger');
              notifyListeners();
            }
          } catch (e) {
            if (kDebugMode) print('App reopen sync progress error: $e');
          }
        });

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
          serverUri: currentServerUrl,
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

        // Test real connection status after Rust initialization
        if (_rustService.initialized) {
          if (kDebugMode) print('🔧 Rust service initialized, testing real server connection...');
          await _testRealServerConnection(context: 'after_rust_init');
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

    // Don't sync if we're disconnected - prevents background operations when offline
    if (!_isConnected) {
      if (kDebugMode) print('📵 Skipping background sync - currently disconnected');
      return;
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
    // Don't restart if already polling
    if (_syncStatusTimer?.isActive == true) {
      if (kDebugMode) print('🔄 Sync status polling already active, not restarting');
      return;
    }

    _stopSyncStatusPolling();

    if (kDebugMode) print('🔄 Starting sync status polling...');
    if (kDebugMode) print('   Rust service initialized: ${_rustService.initialized}');

    // Track when polling started to prevent infinite loops
    final pollingStartTime = DateTime.now();
    // For genesis sync (birthday 0), allow much longer polling time
    final isGenesisSync = _wallet?.birthdayHeight == 0;
    final maxPollingDuration = isGenesisSync
        ? const Duration(hours: 2)  // 2 hours for genesis sync
        : const Duration(minutes: 5); // 5 minutes for regular sync

    // Poll every 3 seconds for sync status (like BitcoinZ Blue - less frequent to avoid race conditions)
    _syncStatusTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      // Check if we've been polling too long
      if (DateTime.now().difference(pollingStartTime) > maxPollingDuration) {
        if (kDebugMode) print('⏰ Sync polling timeout - stopping after ${isGenesisSync ? "2 hours" : "5 minutes"}');
        _stopSyncStatusPolling();
        _setSyncing(false);
        // Test real connection instead of assuming connected on timeout
        await _testRealServerConnection(context: 'sync_timeout');
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
              serverUri: currentServerUrl,
              seedPhrase: seedPhrase,
              createNew: false,
            );

            if (connected) {
              if (kDebugMode) print('🔧 Rust reconnected, testing real server connection...');
              final reallyConnected = await _testRealServerConnection(context: 'reconnect');

              if (reallyConnected) {
                // Now sync the wallet
                syncWalletInBackground();
              }
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
        if (kDebugMode) print('🔧 Rust initialized, testing real server connection...');
        await _testRealServerConnection(context: 'early_connection_check');
        return;
      }

      // Try a quick server connectivity check
      // We're not initializing the wallet yet, just checking if server is reachable
      try {
        // For now, we'll assume server is online unless we have evidence otherwise
        // Real server check would happen during wallet initialization

        // Quick check with timeout
        await Future.delayed(const Duration(milliseconds: 200));

        // Test real server connection instead of assuming reachable
        if (kDebugMode) print('🔧 Server check passed, testing real connection...');
        await _testRealServerConnection(context: 'early_server_check');

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

    // FALLBACK: If we have very recent successful operations, trust them over slow checks
    if (_lastSuccessfulRustOperation != null) {
      final timeSinceSuccess = DateTime.now().difference(_lastSuccessfulRustOperation!);
      if (timeSinceSuccess.inSeconds < 30) {
        if (!_isConnected) {
          if (kDebugMode) print('🔧 Recent Rust success (${timeSinceSuccess.inSeconds}s ago), testing real connection...');
          await _testRealServerConnection(context: 'recent_success_fallback');
        }
        return; // Skip slow checks if we have recent success
      }
    }

    // NOTE: No internet checking - we rely solely on Rust service communication

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
      // Check if Rust service is initialized and can get sync status
      // No server HTTP pinging - trust Rust service communication only
      if (_rustService.initialized) {
        // Try to get sync status as a connection check with timeout
        final status = await _rustService.getSyncStatus()
            .timeout(const Duration(seconds: 10));

        if (status != null) {
          // getSyncStatus can return cached data - don't set connection status here
          if (kDebugMode) print('📊 getSyncStatus returned data (may be cached)');
          _lastConnectionCheck = DateTime.now();
        } else {
          // Internet available but Rust can't get status
          _setConnectionStatus(false, 'Connection error');
        }
      } else {
        _setConnectionStatus(false, 'Not initialized');
        // Try to reconnect
        _scheduleReconnectionAttempt();
      }
    } catch (e) {
      // Don't flip to disconnected while an active sync may be running
      if (_isSyncing) {
        if (kDebugMode) print('⚠️ Connection check failed during sync, ignoring: $e');
      } else {
        if (e is TimeoutException) {
          _setConnectionStatus(false, 'Connection timeout');
        } else {
          _setConnectionStatus(false, 'Connection error');
        }
      }
      if (kDebugMode) print('❌ Connection check failed: $e');
    }
  }

  /// Simple sync status update (like BitcoinZ Blue) - using ACTUAL Rust service state
  Future<void> _updateSyncStatus() async {
    if (!_rustService.initialized) {
      if (kDebugMode) print('⚠️ Rust service not initialized, skipping sync status update');
      return;
    }

    // Prevent race conditions from multiple simultaneous calls
    if (_isUpdatingSyncStatus) {
      if (kDebugMode) print('⚠️ Sync status update already in progress, skipping');
      return;
    }
    _isUpdatingSyncStatus = true;

    try {
      // Use the ACTUAL sync state from Rust service instead of unreliable syncstatus command
      final bool actuallyInProgress = _rustService.isActuallySyncing;

      if (kDebugMode) {
        print('🔍 ACTUAL Sync State: Rust service _isSyncing = $actuallyInProgress');
      }

      // If Rust service says it's syncing, try to get detailed progress
      int syncedBlocks = 0;
      int totalBlocks = 0;

      // Always try to get progress details when sync is active
      int currentBatch = 0;
      int totalBatches = 0;

      if (actuallyInProgress) {
        try {
          final status = await _rustService.getSyncStatus();
          if (status != null) {
            syncedBlocks = status['synced_blocks'] ?? 0;
            totalBlocks = status['total_blocks'] ?? 0;
            currentBatch = status['batch_num'] ?? 0;
            totalBatches = status['batch_total'] ?? 0;

            if (kDebugMode) {
              print('🔍 Progress Details: $syncedBlocks/$totalBlocks blocks');
              print('🔍 Batch Details: $currentBatch/$totalBatches batches');
            }

            // WORKAROUND: If we get stale data (all zeros) but sync is actually active,
            // try to get the raw status string and parse it manually
            if (syncedBlocks == 0 && totalBlocks == 0 && currentBatch == 0 && totalBatches == 0) {
              if (kDebugMode) print('🔧 WORKAROUND: Got stale sync data, attempting manual parsing...');

              try {
                // Try to get the raw status string that might contain the text format
                final rawStatus = await _rustService.getRawSyncStatus();
                if (rawStatus != null && rawStatus.contains('batch:') && rawStatus.contains('blocks:')) {
                  final parsed = _parseTextSyncStatus(rawStatus);
                  if (parsed != null) {
                    syncedBlocks = parsed['synced_blocks'] ?? 0;
                    totalBlocks = parsed['total_blocks'] ?? 0;
                    currentBatch = parsed['batch_num'] ?? 0;
                    totalBatches = parsed['batch_total'] ?? 0;

                    if (kDebugMode) {
                      print('🔧 WORKAROUND SUCCESS: Parsed text format');
                      print('   Progress: $syncedBlocks/$totalBlocks blocks');
                      print('   Batch: $currentBatch/$totalBatches');
                    }
                  }
                }
              } catch (e) {
                if (kDebugMode) print('🔧 WORKAROUND FAILED: $e');
              }
            }
          }
        } catch (e) {
          if (kDebugMode) print('⚠️ Could not get progress details: $e');
        }
      }

      if (actuallyInProgress) {
        // ACTUAL sync in progress - trust the Rust service!
        _lastActiveSyncDetected = DateTime.now();
        _consecutiveInactivePolls = 0;
        _lastSyncUIHideTime = null; // Reset grace period when sync is active

        _setSyncing(true);
        _syncMessage = 'Syncing...';

        if (_syncStartTime == null) {
          _syncStartTime = DateTime.now();
        }

        // Calculate sync progress based on available data
        if (totalBlocks > 0 && syncedBlocks > 0) {
          // We have detailed block progress - use it for accurate calculation
          _syncedBlocks = syncedBlocks;
          _totalBlocks = totalBlocks;
          _currentBatch = currentBatch + 1; // Display as 1-based
          _totalBatches = totalBatches;

          // Calculate batch progress (within current batch)
          _batchProgress = (syncedBlocks * 100.0) / totalBlocks;

          // Calculate overall progress across all batches
          if (totalBatches > 1) {
            final double batchProgressDecimal = syncedBlocks.toDouble() / totalBlocks.toDouble();
            final double overallProgress = ((currentBatch.toDouble() + batchProgressDecimal) / totalBatches.toDouble()) * 100.0;
            _syncProgress = overallProgress.clamp(0.0, 99.0);
          } else {
            _syncProgress = _batchProgress.clamp(0.0, 99.0);
          }

          // Calculate ETA for complete sync
          _calculateSyncETA();

          if (kDebugMode) {
            print('📊 COMPREHENSIVE sync progress: ${_syncProgress.toStringAsFixed(1)}% overall');
            print('   📦 Batch $_currentBatch/$_totalBatches (${_batchProgress.toStringAsFixed(1)}% within batch)');
            print('   🧮 Blocks: $syncedBlocks/$totalBlocks in current batch');
            print('   ⏱️ ETA: $_syncETA');
          }
        } else if (totalBatches > 0) {
          // We have batch info but no detailed block progress - use batch-based progress
          _currentBatch = currentBatch + 1; // Display as 1-based
          _totalBatches = totalBatches;

          final double batchBasedProgress = (currentBatch.toDouble() / totalBatches.toDouble()) * 100.0;
          _syncProgress = batchBasedProgress.clamp(0.0, 99.0);
          _syncETA = 'Calculating...';

          if (kDebugMode) {
            print('📊 Batch-based sync progress: ${_syncProgress.toStringAsFixed(1)}% (Batch $_currentBatch/$_totalBatches)');
          }
        } else {
          // No detailed progress available - use time-based estimation starting from 0%
          final elapsed = DateTime.now().difference(_syncStartTime!).inMinutes;
          _syncProgress = (elapsed * 1.0).clamp(0.0, 99.0); // Start at 0%, increase 1% per minute
          _syncETA = 'Calculating...';

          if (kDebugMode) {
            print('📊 Time-based sync progress: ${_syncProgress.toStringAsFixed(1)}% (${elapsed} min elapsed)');
          }
        }

        // FORCE UI UPDATE: Even if we get inconsistent data, ensure UI updates
        if (kDebugMode) print('🔔 FORCING UI update after sync status processing');
        notifyListeners();
      } else {
        // Rust service says NOT syncing - but use grace period to prevent UI flicker
        _consecutiveInactivePolls++;

        // If we were previously syncing, start grace period before hiding UI
        if (_isSyncing && _lastSyncUIHideTime == null) {
          _lastSyncUIHideTime = DateTime.now().add(const Duration(seconds: 10));
          if (kDebugMode) print('🕐 Sync UI grace period started - will hide in 10 seconds if still inactive');
        }

        // Check if grace period has expired
        final now = DateTime.now();
        final shouldHideUI = _lastSyncUIHideTime != null && now.isAfter(_lastSyncUIHideTime!);

        if (shouldHideUI || _consecutiveInactivePolls >= 5) {
          // Grace period expired or multiple consecutive inactive polls - sync is truly complete
          if (kDebugMode) print('📊 ACTUAL sync completed - Rust service _isSyncing = false (after grace period)');
          _setSyncing(false);
          _syncProgress = 100.0;
          _syncMessage = '';
          _lastSyncTime = DateTime.now();
          _syncStartTime = null; // Reset sync timer for next sync
          _consecutiveInactivePolls = 0;
          _lastSyncUIHideTime = null; // Reset grace period

          // Reset detailed sync info
          _currentBatch = 0;
          _totalBatches = 0;
          _syncedBlocks = 0;
          _totalBlocks = 0;
          _syncETA = '';
          _batchProgress = 0.0;

          // Refresh wallet data after sync completion
          if (hasWallet) {
            _refreshWalletData().catchError((e) {
              if (kDebugMode) print('⚠️ Failed to refresh wallet data after sync: $e');
            });
          }
        } else {
          // Still in grace period - keep showing sync UI
          if (kDebugMode) print('🕐 Sync UI grace period active - keeping sync UI visible (${_consecutiveInactivePolls} inactive polls)');

          // FORCE UI UPDATE during grace period to ensure UI stays responsive
          if (kDebugMode) print('🔔 FORCING UI update during grace period');
          notifyListeners();
        }
      }

      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('❌ Failed to update sync status: $e');
    } finally {
      _isUpdatingSyncStatus = false;
    }
  }

  /// Calculate ETA for complete sync based on current progress
  void _calculateSyncETA() {
    if (_syncStartTime == null || _syncProgress <= 0) {
      _syncETA = 'Calculating...';
      return;
    }

    try {
      final elapsed = DateTime.now().difference(_syncStartTime!);
      final elapsedMinutes = elapsed.inMinutes;

      if (elapsedMinutes < 1) {
        _syncETA = 'Calculating...';
        return;
      }

      // Calculate rate of progress per minute
      final progressRate = _syncProgress / elapsedMinutes;

      if (progressRate <= 0) {
        _syncETA = 'Calculating...';
        return;
      }

      // Calculate remaining progress and time
      final remainingProgress = 100.0 - _syncProgress;
      final remainingMinutes = (remainingProgress / progressRate).round();

      // Format ETA
      if (remainingMinutes < 1) {
        _syncETA = 'Almost done';
      } else if (remainingMinutes < 60) {
        _syncETA = '${remainingMinutes}m remaining';
      } else {
        final hours = remainingMinutes ~/ 60;
        final minutes = remainingMinutes % 60;
        if (minutes == 0) {
          _syncETA = '${hours}h remaining';
        } else {
          _syncETA = '${hours}h ${minutes}m remaining';
        }
      }
    } catch (e) {
      _syncETA = 'Calculating...';
      if (kDebugMode) print('⚠️ Error calculating ETA: $e');
    }
  }

  /// Parse detailed sync status from Rust execute('syncstatus') command
  /// Handles both JSON format: {"sync_id": 1, "in_progress": true, ...}
  /// And text format: "id: 1, batch: 0/28, blocks: 8499/30000, decryptions: 8650, tx_scan: 0"
  Map<String, dynamic> _parseDetailedSyncStatus(String rawStatus) {
    try {
      if (kDebugMode) print('🔍 Parsing detailed sync status: $rawStatus');
      
      // Try JSON format first (current format)
      if (rawStatus.trim().startsWith('{')) {
        final Map<String, dynamic> jsonData = jsonDecode(rawStatus);
        
        if (kDebugMode) {
          print('🔍 Parsed JSON sync data: '
               'batch=${jsonData['batch_num']}/${jsonData['batch_total']}, '
               'blocks=${jsonData['synced_blocks']}/${jsonData['total_blocks']}, '
               'in_progress=${jsonData['in_progress']}');
        }
        
        // JSON already contains all the data we need
        return jsonData;
      }
      
      // Fallback: Parse text format (legacy format)
      final Map<String, dynamic> parsed = {};
      
      // Parse batch information: "batch: 0/28"
      final batchMatch = RegExp(r'batch:\s*(\d+)/(\d+)').firstMatch(rawStatus);
      if (batchMatch != null) {
        parsed['batch_num'] = int.parse(batchMatch.group(1)!);
        parsed['batch_total'] = int.parse(batchMatch.group(2)!);
      }
      
      // Parse blocks information: "blocks: 8499/30000"
      final blocksMatch = RegExp(r'blocks:\s*(\d+)/(\d+)').firstMatch(rawStatus);
      if (blocksMatch != null) {
        parsed['synced_blocks'] = int.parse(blocksMatch.group(1)!);
        parsed['total_blocks'] = int.parse(blocksMatch.group(2)!);
      }
      
      // Parse decryptions: "decryptions: 8650"
      final decryptionsMatch = RegExp(r'decryptions:\s*(\d+)').firstMatch(rawStatus);
      if (decryptionsMatch != null) {
        parsed['trial_decryptions_blocks'] = int.parse(decryptionsMatch.group(1)!);
      }
      
      // Parse tx_scan: "tx_scan: 0"
      final txScanMatch = RegExp(r'tx_scan:\s*(\d+)').firstMatch(rawStatus);
      if (txScanMatch != null) {
        parsed['txn_scan_blocks'] = int.parse(txScanMatch.group(1)!);
      }
      
      // Parse sync ID: "id: 1"
      final idMatch = RegExp(r'id:\s*(\d+)').firstMatch(rawStatus);
      if (idMatch != null) {
        parsed['sync_id'] = int.parse(idMatch.group(1)!);
      }
      
      // Determine if sync is actually in progress based on real data
      final int batchNum = parsed['batch_num'] ?? 0;
      final int batchTotal = parsed['batch_total'] ?? 0;
      final int syncedBlocks = parsed['synced_blocks'] ?? 0;
      final int totalBlocks = parsed['total_blocks'] ?? 0;
      
      // Sync is in progress if:
      // 1. We have valid batch/block data AND
      // 2. Either batches are incomplete OR blocks are incomplete
      final bool hasValidData = (batchTotal > 0 || totalBlocks > 0);
      final bool batchesIncomplete = (batchTotal > 0 && batchNum < batchTotal);
      final bool blocksIncomplete = (totalBlocks > 0 && syncedBlocks < totalBlocks);
      
      parsed['in_progress'] = hasValidData && (batchesIncomplete || blocksIncomplete);
      
      if (kDebugMode) {
        print('🔍 Parsed text sync data: batch=$batchNum/$batchTotal, blocks=$syncedBlocks/$totalBlocks, in_progress=${parsed['in_progress']}');
      }
      
      return parsed;
      
    } catch (e) {
      if (kDebugMode) print('❌ Failed to parse detailed sync status: $e');
      // Return empty map to trigger fallback to basic status
      return {};
    }
  }

  /// Parse text format sync status: "id: 1, batch: 0/28, blocks: 8499/30000, decryptions: 9000, tx_scan: 0"
  Map<String, dynamic>? _parseTextSyncStatus(String rawStatus) {
    try {
      if (kDebugMode) print('🔧 Parsing text sync status: "$rawStatus"');

      final Map<String, dynamic> parsed = {};

      // Parse batch information: "batch: 0/28"
      final batchMatch = RegExp(r'batch:\s*(\d+)/(\d+)').firstMatch(rawStatus);
      if (batchMatch != null) {
        parsed['batch_num'] = int.parse(batchMatch.group(1)!);
        parsed['batch_total'] = int.parse(batchMatch.group(2)!);
      }

      // Parse blocks information: "blocks: 8499/30000"
      final blocksMatch = RegExp(r'blocks:\s*(\d+)/(\d+)').firstMatch(rawStatus);
      if (blocksMatch != null) {
        parsed['synced_blocks'] = int.parse(blocksMatch.group(1)!);
        parsed['total_blocks'] = int.parse(blocksMatch.group(2)!);
      }

      // Parse sync_id: "id: 1"
      final idMatch = RegExp(r'id:\s*(\d+)').firstMatch(rawStatus);
      if (idMatch != null) {
        parsed['sync_id'] = int.parse(idMatch.group(1)!);
      }

      // Determine if in progress based on parsed data
      final batchTotal = parsed['batch_total'] as int?;
      final totalBlocks = parsed['total_blocks'] as int?;

      final inProgress = (batchTotal != null && batchTotal > 0) ||
                        (totalBlocks != null && totalBlocks > 0);

      parsed['in_progress'] = inProgress;

      if (kDebugMode) {
        print('🔧 Parsed result: $parsed');
      }

      return parsed.isNotEmpty ? parsed : null;
    } catch (e) {
      if (kDebugMode) print('🔧 Failed to parse text sync status: $e');
      return null;
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

      // If Rust service is initialized, test real connection
      if (_rustService.initialized) {
        if (kDebugMode) print('🔧 Rust service initialized, testing real server connection...');
        await _testRealServerConnection(context: 'connection_check');

        // Try to get block height for additional verification (non-blocking)
        try {
          final blockHeight = await _rustService.getCurrentBlockHeight();
          if (blockHeight != null && blockHeight > 0) {
            if (kDebugMode) print('✅ Connected: Block height $blockHeight');
            // Smart block height detection - only override if it's NEW data
            _handleNewBlockHeight(blockHeight);
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

  /// Update last successful operation timestamp only
  void _updateLastSuccessfulOperation() {
    _lastSuccessfulRustOperation = DateTime.now();
  }


  /// Handle new block height - test real connection when we get NEW data
  void _handleNewBlockHeight(int blockHeight) {
    if (_lastKnownBlockHeight == null || _lastKnownBlockHeight != blockHeight) {
      if (kDebugMode) print('🔗 NEW BLOCK HEIGHT: $blockHeight (was: $_lastKnownBlockHeight) - testing connection');
      _lastKnownBlockHeight = blockHeight;
      // This suggests real server data - test connection to confirm
      _testRealServerConnection(context: 'new_block_height');
    } else {
      if (kDebugMode) print('📊 Same block height: $blockHeight (cached data, no connection test)');
    }
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
      if (hasWallet && _autoSyncEnabled && _isConnected) {
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
    print('📱 WALLET_PROVIDER DEBUG: _refreshWalletData() entered');
    print('📱 WALLET_PROVIDER DEBUG: _rustService.initialized = ${_rustService.initialized}');

    // Ensure Rust is initialized on app restart so balance/tx load correctly
    if (!_rustService.initialized) {
      try {
        if (kDebugMode) print('   Rust not initialized; attempting background load of existing wallet...');
        print('📱 WALLET_PROVIDER DEBUG: Rust not initialized, calling initialize...');
        final ok = await _rustService.initialize(
          serverUri: currentServerUrl,
          createNew: false,
          seedPhrase: null, // load existing wallet.dat without seed
          birthdayHeight: null,
        );
        if (kDebugMode) print('   Background initialize existing wallet result: $ok');
        print('📱 WALLET_PROVIDER DEBUG: Background initialize result: $ok');
      } catch (e) {
        if (kDebugMode) print('   ⚠️ Background initialize failed: $e');
        print('📱 WALLET_PROVIDER DEBUG: Background initialize failed: $e');
      }
    } else {
      print('📱 WALLET_PROVIDER DEBUG: Rust already initialized, skipping');
    }

    // Always use Rust Bridge for all wallets (provides mempool monitoring)
    if (_rustService.initialized) {
      if (kDebugMode) print('   Using Rust Bridge for wallet refresh');

      // Don't trigger sync UI for routine refreshes
      // The Rust service refresh is lightweight and doesn't need UI
      try {
        // Skip the full refresh which includes sync - just fetch the data directly
        // The sync is hanging on Android, so we'll fetch data without syncing

        if (kDebugMode) print('   Fetching balance...');
        print('📱 WALLET_PROVIDER DEBUG: About to call _rustService.fetchBalance()...');
        await _rustService.fetchBalance();
        print('📱 WALLET_PROVIDER DEBUG: fetchBalance() completed');

        if (kDebugMode) print('   Fetching transactions...');
        print('📱 WALLET_PROVIDER DEBUG: About to call _rustService.fetchTransactions()...');
        await _rustService.fetchTransactions();
        print('📱 WALLET_PROVIDER DEBUG: fetchTransactions() completed');

        if (kDebugMode) print('   Fetching addresses...');
        print('📱 WALLET_PROVIDER DEBUG: About to fetch addresses...');
        await _rustService.fetchAddresses();

        if (kDebugMode) print('✅ Wallet data refresh complete');

        // Save wallet state to disk for persistence
        try {
          await _rustService.save();
          if (kDebugMode) print('💾 Wallet saved to disk');
        } catch (saveError) {
          if (kDebugMode) print('⚠️ Failed to save wallet: $saveError');
        }

        // Rust operations succeeded - let the periodic connection check handle status
        if (kDebugMode) print('✅ Wallet data refresh successful');
        _updateLastSuccessfulOperation();
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

  /// Get blockchain tip with caching for real progress calculation
  Future<int?> _getBlockchainTip() async {
    final now = DateTime.now();

    // Return cached value if still valid
    if (_blockchainTip != null &&
        _blockchainTipCacheTime != null &&
        now.difference(_blockchainTipCacheTime!).compareTo(_blockchainTipCacheDuration) < 0) {
      return _blockchainTip;
    }

    // Fetch new blockchain tip from server
    try {
      final tip = await _rustService.getCurrentBlockHeight();
      if (tip > 0) {
        _blockchainTip = tip;
        _blockchainTipCacheTime = now;
        
        if (kDebugMode) print('📡 Updated blockchain tip: $_blockchainTip');
        return _blockchainTip;
      }
    } catch (e) {
      if (kDebugMode) print('⚠️ Failed to fetch blockchain tip: $e');
      return _blockchainTip; // Return cached value if available
    }

    return _blockchainTip;
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
      _pageCache.clear();
      _cachedPageOrder.clear();

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
      List<TransactionModel> transactions;

      // Check cache first for better performance
      if (_pageCache.containsKey(page) && searchQuery == null && filterType == null) {
        transactions = _pageCache[page]!;
        _updatePageCacheAccess(page);
        if (kDebugMode) print('📄 Loaded page $page from cache (${transactions.length} transactions)');
      } else {
        // Load from database
        transactions = await _databaseService.getTransactions(
          limit: _pageSize,
          offset: page * _pageSize,
          type: filterType,
          searchQuery: searchQuery,
        );

        // Cache the page if no search/filter (only cache clean data)
        if (searchQuery == null && filterType == null) {
          _cacheTransactionPage(page, transactions);
        }

        if (kDebugMode) print('📄 Loaded page $page from database (${transactions.length} transactions)');
      }

      if (resetList) {
        _transactions = transactions;
      } else {
        _transactions.addAll(transactions);
      }

      _hasMoreTransactions = transactions.length == _pageSize;
      _currentPage = page;

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

  /// Cache a page of transactions with LRU eviction
  void _cacheTransactionPage(int page, List<TransactionModel> transactions) {
    // Remove page if already cached to update access order
    if (_pageCache.containsKey(page)) {
      _cachedPageOrder.remove(page);
    }

    // Add to cache
    _pageCache[page] = List.from(transactions); // Create copy to avoid reference issues
    _cachedPageOrder.add(page);

    // Evict oldest pages if cache is full
    while (_cachedPageOrder.length > _maxCachedPages) {
      final oldestPage = _cachedPageOrder.removeAt(0);
      _pageCache.remove(oldestPage);
      if (kDebugMode) print('📄 Evicted page $oldestPage from cache');
    }
  }

  /// Update page access order for LRU cache
  void _updatePageCacheAccess(int page) {
    _cachedPageOrder.remove(page);
    _cachedPageOrder.add(page);
  }

  /// Clear transaction cache (useful for memory management)
  void clearTransactionCache() {
    _pageCache.clear();
    _cachedPageOrder.clear();
    if (kDebugMode) print('📄 Cleared transaction cache');
  }

  // Message Label Management

  /// Get message labels for a transaction (simple like BitcoinZ Blue)
  Future<List<MessageLabel>> getMessageLabels(String txid) async {
    return []; // Simple - no message labels like BitcoinZ Blue
  }

  /// Add a message label to a transaction (simple like BitcoinZ Blue)
  Future<void> addMessageLabel(MessageLabel label) async {
    // Simple - no-op like BitcoinZ Blue
  }

  /// Remove a message label from a transaction (simple like BitcoinZ Blue)
  Future<void> removeMessageLabel(MessageLabel label) async {
    // Simple - no-op like BitcoinZ Blue
  }

  /// Get all unique message labels (for suggestions)
  Future<List<String>> getAllMessageLabelNames() async {
    try {
      final allLabels = await _databaseService.getAllMessageLabels();
      final uniqueNames = allLabels.map((l) => l.labelName).toSet().toList();
      uniqueNames.sort();
      return uniqueNames;
    } catch (e) {
      if (kDebugMode) print('⚠️ Failed to load all message labels: $e');
      return [];
    }
  }

  /// Clear message labels cache
  void clearMessageLabelsCache() {
    _messageLabelsCache.clear();
    if (kDebugMode) print('🏷️ Cleared message labels cache');
  }

  // Transaction Category Management

  /// Get or auto-generate category for a transaction
  Future<TransactionCategory> getTransactionCategory(String txid) async {
    // Check cache first
    if (_transactionCategoriesCache.containsKey(txid)) {
      return _transactionCategoriesCache[txid]!;
    }

    try {
      // Check database
      final categoryData = await _databaseService.getTransactionCategory(txid);

      if (categoryData != null) {
        // Found in database, create category object
        final category = TransactionCategorizer.getCategoryByName(categoryData['category_name'] as String);
        if (category != null) {
          final categoryWithScore = TransactionCategory(
            type: category.type,
            name: category.name,
            description: category.description,
            icon: category.icon,
            color: category.color,
            keywords: category.keywords,
            confidenceScore: categoryData['confidence_score'] as double,
          );
          _transactionCategoriesCache[txid] = categoryWithScore;
          return categoryWithScore;
        }
      }

      // Not found in database, auto-categorize
      final transaction = _transactions.firstWhere(
        (tx) => tx.txid == txid,
        orElse: () => throw StateError('Transaction not found'),
      );

      final autoCategory = TransactionCategorizer.categorizeTransaction(transaction);

      // Save to database
      await _databaseService.insertTransactionCategory(
        txid: txid,
        categoryType: autoCategory.type.toString().split('.').last,
        categoryName: autoCategory.name,
        confidenceScore: autoCategory.confidenceScore,
        isManual: false,
      );

      // Cache it
      _transactionCategoriesCache[txid] = autoCategory;

      if (kDebugMode) {
        print('🏷️ Auto-categorized transaction $txid as ${autoCategory.name} (confidence: ${autoCategory.confidenceScore.toStringAsFixed(2)})');
      }

      return autoCategory;
    } catch (e) {
      if (kDebugMode) print('⚠️ Failed to get category for transaction $txid: $e');

      // Return default category
      final defaultCategory = TransactionCategorizer.getCategoryByName('Miscellaneous')!;
      _transactionCategoriesCache[txid] = defaultCategory;
      return defaultCategory;
    }
  }

  /// Manually set category for a transaction
  Future<void> setTransactionCategory(String txid, TransactionCategory category) async {
    try {
      // Check if category already exists in database
      final existingCategory = await _databaseService.getTransactionCategory(txid);

      if (existingCategory != null) {
        // Update existing
        await _databaseService.updateTransactionCategory(
          txid: txid,
          categoryType: category.type.toString().split('.').last,
          categoryName: category.name,
          confidenceScore: 1.0, // Manual categorization has full confidence
          isManual: true,
        );
      } else {
        // Insert new
        await _databaseService.insertTransactionCategory(
          txid: txid,
          categoryType: category.type.toString().split('.').last,
          categoryName: category.name,
          confidenceScore: 1.0, // Manual categorization has full confidence
          isManual: true,
        );
      }

      // Update cache
      _transactionCategoriesCache[txid] = category;

      notifyListeners();
      if (kDebugMode) print('🏷️ Manually set category for transaction $txid to ${category.name}');
    } catch (e) {
      if (kDebugMode) print('❌ Failed to set category for transaction $txid: $e');
      throw Exception('Failed to set category: $e');
    }
  }

  /// Get category counts for statistics
  Future<Map<String, int>> getCategoryTypeCounts() async {
    try {
      return await _databaseService.getCategoryTypeCounts();
    } catch (e) {
      if (kDebugMode) print('⚠️ Failed to get category counts: $e');
      return {};
    }
  }

  /// Auto-categorize all transactions (useful for initial setup)
  Future<void> autoCategorizeAllTransactions() async {
    try {
      if (kDebugMode) print('🏷️ Starting auto-categorization of all transactions...');

      int categorized = 0;
      for (final transaction in _transactions) {
        final existingCategory = await _databaseService.getTransactionCategory(transaction.txid);

        // Only auto-categorize if not already categorized
        if (existingCategory == null) {
          final category = TransactionCategorizer.categorizeTransaction(transaction);

          await _databaseService.insertTransactionCategory(
            txid: transaction.txid,
            categoryType: category.type.toString().split('.').last,
            categoryName: category.name,
            confidenceScore: category.confidenceScore,
            isManual: false,
          );

          _transactionCategoriesCache[transaction.txid] = category;
          categorized++;
        }
      }

      if (kDebugMode) print('🏷️ Auto-categorized $categorized transactions');
      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('❌ Failed to auto-categorize transactions: $e');
    }
  }

  /// Clear transaction categories cache
  void clearTransactionCategoriesCache() {
    _transactionCategoriesCache.clear();
    if (kDebugMode) print('🏷️ Cleared transaction categories cache');
  }

  // Enhanced Unread Messages Management

  /// Get count of unread messages
  int get unreadMessageCount {
    return _transactions.where((tx) =>
      tx.hasMemo && !getTransactionMemoReadStatus(tx.txid, tx.memoRead)
    ).length;
  }

  /// Get all transactions with unread messages
  List<TransactionModel> get unreadMessageTransactions {
    return _transactions.where((tx) =>
      tx.hasMemo && !getTransactionMemoReadStatus(tx.txid, tx.memoRead)
    ).toList()..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  /// Get all transactions with messages (read and unread)
  List<TransactionModel> get allMessageTransactions {
    return _transactions.where((tx) => tx.hasMemo).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  /// Mark multiple memos as read
  Future<void> markMultipleMemosAsRead(List<String> txids) async {
    try {
      for (final txid in txids) {
        await markMemoAsRead(txid);
      }
      if (kDebugMode) print('📱 Marked ${txids.length} memos as read');
    } catch (e) {
      if (kDebugMode) print('❌ Failed to mark multiple memos as read: $e');
      throw Exception('Failed to mark memos as read: $e');
    }
  }

  /// Mark multiple memos as unread
  Future<void> markMultipleMemosAsUnread(List<String> txids) async {
    try {
      for (final txid in txids) {
        await markMemoAsUnread(txid);
      }
      if (kDebugMode) print('📱 Marked ${txids.length} memos as unread');
    } catch (e) {
      if (kDebugMode) print('❌ Failed to mark multiple memos as unread: $e');
      throw Exception('Failed to mark memos as unread: $e');
    }
  }

  /// Mark all messages as read
  Future<void> markAllMessagesAsRead() async {
    final unreadTxids = unreadMessageTransactions.map((tx) => tx.txid).toList();
    if (unreadTxids.isNotEmpty) {
      await markMultipleMemosAsRead(unreadTxids);
    }
  }

  /// Mark all messages as unread
  Future<void> markAllMessagesAsUnread() async {
    final allMessageTxids = allMessageTransactions.map((tx) => tx.txid).toList();
    if (allMessageTxids.isNotEmpty) {
      await markMultipleMemosAsUnread(allMessageTxids);
    }
  }

  /// Check if there are new unread messages (for notifications)
  bool get hasNewUnreadMessages {
    // This could be enhanced to track "new" vs "existing" unread messages
    return unreadMessageCount > 0;
  }

  // Financial Analytics Methods

  /// Generate comprehensive financial analytics for a given period
  Future<FinancialAnalytics> getFinancialAnalytics({
    AnalyticsPeriod period = AnalyticsPeriod.threeMonths,
    DateTime? customStartDate,
    DateTime? customEndDate,
    bool useCache = true,
  }) async {
    try {
      // Generate cache key
      final cacheKey = '${period.toString()}_${customStartDate?.millisecondsSinceEpoch ?? 'null'}_${customEndDate?.millisecondsSinceEpoch ?? 'null'}';

      // Check cache if enabled
      if (useCache && _analyticsCache.containsKey(cacheKey)) {
        final cacheTimestamp = _analyticsCacheTimestamps[cacheKey];
        if (cacheTimestamp != null &&
            DateTime.now().difference(cacheTimestamp).inMinutes < 5) { // Cache for 5 minutes
          if (kDebugMode) print('📊 Using cached analytics for $cacheKey');
          return _analyticsCache[cacheKey]!;
        }
      }

      // Generate new analytics
      if (kDebugMode) print('📊 Generating new analytics for $cacheKey');
      final analytics = FinancialAnalytics.fromTransactions(
        transactions: _transactions,
        period: period,
        customStartDate: customStartDate,
        customEndDate: customEndDate,
      );

      // Cache the result
      if (useCache) {
        _analyticsCache[cacheKey] = analytics;
        _analyticsCacheTimestamps[cacheKey] = DateTime.now();

        // Clean old cache entries (keep only last 10)
        if (_analyticsCache.length > 10) {
          final oldestKey = _analyticsCacheTimestamps.entries
              .reduce((a, b) => a.value.isBefore(b.value) ? a : b)
              .key;
          _analyticsCache.remove(oldestKey);
          _analyticsCacheTimestamps.remove(oldestKey);
        }
      }

      return analytics;
    } catch (e) {
      if (kDebugMode) print('❌ Failed to generate financial analytics: $e');
      rethrow;
    }
  }

  /// Get spending breakdown by category for a specific period
  Future<Map<TransactionCategoryType, double>> getSpendingByCategory({
    AnalyticsPeriod period = AnalyticsPeriod.threeMonths,
  }) async {
    try {
      final analytics = await getFinancialAnalytics(period: period);
      return analytics.categoryTotals;
    } catch (e) {
      if (kDebugMode) print('❌ Failed to get spending by category: $e');
      return {};
    }
  }

  /// Get income vs expenses comparison for a period
  Future<Map<String, double>> getIncomeVsExpenses({
    AnalyticsPeriod period = AnalyticsPeriod.threeMonths,
  }) async {
    try {
      final analytics = await getFinancialAnalytics(period: period);
      return {
        'income': analytics.totalIncome,
        'expenses': analytics.totalExpenses,
        'netFlow': analytics.netFlow,
        'savingsRate': analytics.savingsRate,
      };
    } catch (e) {
      if (kDebugMode) print('❌ Failed to get income vs expenses: $e');
      return {};
    }
  }

  /// Get monthly trends data
  Future<List<AnalyticsDataPoint>> getMonthlyTrends({
    AnalyticsPeriod period = AnalyticsPeriod.oneYear,
  }) async {
    try {
      final analytics = await getFinancialAnalytics(period: period);
      return analytics.monthlyData;
    } catch (e) {
      if (kDebugMode) print('❌ Failed to get monthly trends: $e');
      return [];
    }
  }

  /// Get top spending categories
  Future<List<CategoryAnalytics>> getTopSpendingCategories({
    AnalyticsPeriod period = AnalyticsPeriod.threeMonths,
    int limit = 5,
  }) async {
    try {
      final analytics = await getFinancialAnalytics(period: period);
      final expenseCategories = analytics.categoryBreakdown
          .where((cat) => cat.transactions.any((tx) => !tx.isReceived))
          .toList()
        ..sort((a, b) => b.totalAmount.compareTo(a.totalAmount));

      return expenseCategories.take(limit).toList();
    } catch (e) {
      if (kDebugMode) print('❌ Failed to get top spending categories: $e');
      return [];
    }
  }

  /// Get financial insights and recommendations
  Future<List<String>> getFinancialInsights({
    AnalyticsPeriod period = AnalyticsPeriod.threeMonths,
  }) async {
    try {
      final analytics = await getFinancialAnalytics(period: period);
      final insights = <String>[];

      // Savings rate insights
      if (analytics.savingsRate > 20) {
        insights.add('Great job! You\'re saving ${analytics.savingsRate.toStringAsFixed(1)}% of your income.');
      } else if (analytics.savingsRate > 0) {
        insights.add('You\'re saving ${analytics.savingsRate.toStringAsFixed(1)}% of your income. Consider increasing to 20%.');
      } else {
        insights.add('Your expenses exceed your income. Consider reviewing your spending habits.');
      }

      // Growth rate insights
      if (analytics.incomeGrowthRate > 0) {
        insights.add('Your income has grown by ${analytics.incomeGrowthRate.toStringAsFixed(1)}% this period.');
      } else if (analytics.incomeGrowthRate < -10) {
        insights.add('Your income has decreased by ${analytics.incomeGrowthRate.abs().toStringAsFixed(1)}%. Consider diversifying income sources.');
      }

      // Top category insights
      final topExpenseCategory = analytics.categoryBreakdown
          .where((cat) => cat.transactions.any((tx) => !tx.isReceived))
          .firstOrNull;

      if (topExpenseCategory != null) {
        insights.add('Your largest expense category is ${topExpenseCategory.categoryName} (${topExpenseCategory.percentage.toStringAsFixed(1)}%).');
      }

      // Transaction frequency insights
      if (analytics.totalTransactions > 0) {
        final avgPerDay = analytics.totalTransactions /
            analytics.endDate.difference(analytics.startDate).inDays;
        if (avgPerDay > 5) {
          insights.add('You make ${avgPerDay.toStringAsFixed(1)} transactions per day on average. Consider consolidating purchases.');
        }
      }

      return insights;
    } catch (e) {
      if (kDebugMode) print('❌ Failed to get financial insights: $e');
      return ['Unable to generate insights at this time.'];
    }
  }

  // Address Label Management

  /// Get all address labels
  Future<List<AddressLabel>> getAllAddressLabels({
    AddressLabelCategory? category,
    bool? isOwned,
    bool activeOnly = true,
  }) async {
    try {
      return await _databaseService.getAllAddressLabels(
        category: category,
        isOwned: isOwned,
        activeOnly: activeOnly,
      );
    } catch (e) {
      if (kDebugMode) print('❌ Failed to get address labels: $e');
      return [];
    }
  }

  /// Get labels for a specific address
  Future<List<AddressLabel>> getAddressLabels(String address) async {
    // Check cache first
    if (_addressLabelsCache.containsKey(address)) {
      return _addressLabelsCache[address]!;
    }

    try {
      final labels = await _databaseService.getAddressLabels(address);
      _addressLabelsCache[address] = labels;
      return labels;
    } catch (e) {
      if (kDebugMode) print('❌ Failed to get labels for address $address: $e');
      return [];
    }
  }

  /// Add a new address label
  Future<void> addAddressLabel(AddressLabel label) async {
    try {
      await _databaseService.insertAddressLabel(label);

      // Update cache
      final existingLabels = _addressLabelsCache[label.address] ?? [];
      _addressLabelsCache[label.address] = [...existingLabels, label];

      notifyListeners();
      if (kDebugMode) print('✅ Added address label: ${label.labelName} for ${label.address}');
    } catch (e) {
      if (kDebugMode) print('❌ Failed to add address label: $e');
      throw Exception('Failed to add address label: $e');
    }
  }

  /// Update an existing address label
  Future<void> updateAddressLabel(AddressLabel label) async {
    try {
      await _databaseService.updateAddressLabel(label);

      // Update cache
      final existingLabels = _addressLabelsCache[label.address] ?? [];
      final updatedLabels = existingLabels.map((l) => l.id == label.id ? label : l).toList();
      _addressLabelsCache[label.address] = updatedLabels;

      notifyListeners();
      if (kDebugMode) print('✅ Updated address label: ${label.labelName}');
    } catch (e) {
      if (kDebugMode) print('❌ Failed to update address label: $e');
      throw Exception('Failed to update address label: $e');
    }
  }

  /// Delete an address label
  Future<void> deleteAddressLabel(AddressLabel label) async {
    try {
      await _databaseService.deleteAddressLabel(label.id!);

      // Update cache
      final existingLabels = _addressLabelsCache[label.address] ?? [];
      _addressLabelsCache[label.address] = existingLabels.where((l) => l.id != label.id).toList();

      notifyListeners();
      if (kDebugMode) print('✅ Deleted address label: ${label.labelName}');
    } catch (e) {
      if (kDebugMode) print('❌ Failed to delete address label: $e');
      throw Exception('Failed to delete address label: $e');
    }
  }

  /// Get address labels grouped by category
  Future<Map<AddressLabelCategory, List<AddressLabel>>> getAddressLabelsByCategory({
    bool? isOwned,
    bool activeOnly = true,
  }) async {
    try {
      return await _databaseService.getAddressLabelsByCategory(
        isOwned: isOwned,
        activeOnly: activeOnly,
      );
    } catch (e) {
      if (kDebugMode) print('❌ Failed to get address labels by category: $e');
      return {};
    }
  }

  /// Get address label statistics
  Future<Map<String, int>> getAddressLabelStats() async {
    try {
      return await _databaseService.getAddressLabelStats();
    } catch (e) {
      if (kDebugMode) print('❌ Failed to get address label stats: $e');
      return {};
    }
  }

  /// Check if an address has any labels
  Future<bool> hasAddressLabels(String address) async {
    final labels = await getAddressLabels(address);
    return labels.isNotEmpty;
  }

  /// Get the primary label for an address (first active label)
  Future<AddressLabel?> getPrimaryAddressLabel(String address) async {
    final labels = await getAddressLabels(address);
    return labels.isNotEmpty ? labels.first : null;
  }

  /// Clear address labels cache
  void clearAddressLabelsCache() {
    _addressLabelsCache.clear();
    if (kDebugMode) print('🏷️ Cleared address labels cache');
  }

  // External Address Tracking and Analysis

  /// Get frequently transacted external addresses
  Future<List<Map<String, dynamic>>> getFrequentExternalAddresses({
    int minTransactions = 3,
    int limit = 10,
  }) async {
    try {
      final Map<String, Map<String, dynamic>> addressStats = {};

      // Get all own addresses to exclude them
      final ownAddresses = <String>{};
      for (final address in _addresses['transparent'] ?? []) {
        ownAddresses.add(address);
      }
      for (final address in _addresses['shielded'] ?? []) {
        ownAddresses.add(address);
      }

      // Analyze transactions to find external addresses
      for (final transaction in _transactions) {
        String? externalAddress;

        if (transaction.isReceived) {
          // For received transactions, the external address is the sender
          // This would be in the transaction details if available
          if (transaction.fromAddress?.isNotEmpty == true && !ownAddresses.contains(transaction.fromAddress!)) {
            externalAddress = transaction.fromAddress!;
          }
        } else {
          // For sent transactions, the external address is the recipient
          if (transaction.toAddress?.isNotEmpty == true && !ownAddresses.contains(transaction.toAddress!)) {
            externalAddress = transaction.toAddress!;
          }
        }

        if (externalAddress != null) {
          if (!addressStats.containsKey(externalAddress)) {
            addressStats[externalAddress] = {
              'address': externalAddress,
              'transactionCount': 0,
              'totalAmount': 0.0,
              'lastTransaction': transaction.timestamp,
              'firstTransaction': transaction.timestamp,
              'isReceived': transaction.isReceived,
              'transactions': <TransactionModel>[],
            };
          }

          final stats = addressStats[externalAddress]!;
          stats['transactionCount'] = (stats['transactionCount'] as int) + 1;
          stats['totalAmount'] = (stats['totalAmount'] as double) + transaction.amount.abs();

          // Update first/last transaction dates
          if (transaction.timestamp.isAfter(stats['lastTransaction'] as DateTime)) {
            stats['lastTransaction'] = transaction.timestamp;
          }
          if (transaction.timestamp.isBefore(stats['firstTransaction'] as DateTime)) {
            stats['firstTransaction'] = transaction.timestamp;
          }

          (stats['transactions'] as List<TransactionModel>).add(transaction);
        }
      }

      // Filter by minimum transactions and sort by frequency
      final frequentAddresses = addressStats.values
          .where((stats) => (stats['transactionCount'] as int) >= minTransactions)
          .toList()
        ..sort((a, b) => (b['transactionCount'] as int).compareTo(a['transactionCount'] as int));

      return frequentAddresses.take(limit).toList();
    } catch (e) {
      if (kDebugMode) print('❌ Failed to get frequent external addresses: $e');
      return [];
    }
  }

  /// Suggest labels for external addresses based on transaction patterns
  Future<Map<String, AddressLabelType>> suggestLabelsForExternalAddresses(
    List<Map<String, dynamic>> externalAddresses,
  ) async {
    final Map<String, AddressLabelType> suggestions = {};

    for (final addressData in externalAddresses) {
      final address = addressData['address'] as String;
      final transactionCount = addressData['transactionCount'] as int;
      final totalAmount = addressData['totalAmount'] as double;
      final transactions = addressData['transactions'] as List<TransactionModel>;

      // Check if already labeled
      final existingLabels = await getAddressLabels(address);
      if (existingLabels.isNotEmpty) continue;

      // Analyze transaction patterns to suggest label type
      AddressLabelType suggestedType = AddressLabelType.unknown;

      // High frequency, high volume -> likely exchange
      if (transactionCount >= 10 && totalAmount >= 100) {
        suggestedType = AddressLabelType.exchange;
      }
      // Regular small amounts -> might be a service or merchant
      else if (transactionCount >= 5 && totalAmount < 50) {
        suggestedType = AddressLabelType.service;
      }
      // Few large transactions -> might be a friend or personal transfer
      else if (transactionCount <= 5 && totalAmount >= 50) {
        suggestedType = AddressLabelType.friend;
      }
      // Check memo patterns for additional hints
      else {
        final memos = transactions.map((t) => t.memo?.toLowerCase() ?? '').where((m) => m.isNotEmpty).toList();

        if (memos.any((memo) => memo.contains('exchange') || memo.contains('trade'))) {
          suggestedType = AddressLabelType.exchange;
        } else if (memos.any((memo) => memo.contains('payment') || memo.contains('purchase'))) {
          suggestedType = AddressLabelType.merchant;
        } else if (memos.any((memo) => memo.contains('donation') || memo.contains('tip'))) {
          suggestedType = AddressLabelType.donation;
        } else {
          suggestedType = AddressLabelType.unknown;
        }
      }

      suggestions[address] = suggestedType;
    }

    return suggestions;
  }

  /// Get unlabeled external addresses that should be suggested for labeling
  Future<List<Map<String, dynamic>>> getUnlabeledExternalAddresses() async {
    try {
      final frequentAddresses = await getFrequentExternalAddresses();
      final unlabeled = <Map<String, dynamic>>[];

      for (final addressData in frequentAddresses) {
        final address = addressData['address'] as String;
        final existingLabels = await getAddressLabels(address);

        if (existingLabels.isEmpty) {
          unlabeled.add(addressData);
        }
      }

      return unlabeled;
    } catch (e) {
      if (kDebugMode) print('❌ Failed to get unlabeled external addresses: $e');
      return [];
    }
  }

  /// Auto-suggest and create labels for external addresses
  Future<List<AddressLabel>> autoSuggestExternalAddressLabels() async {
    try {
      final unlabeledAddresses = await getUnlabeledExternalAddresses();
      final suggestions = await suggestLabelsForExternalAddresses(unlabeledAddresses);
      final suggestedLabels = <AddressLabel>[];

      for (final addressData in unlabeledAddresses) {
        final address = addressData['address'] as String;
        final suggestedType = suggestions[address];

        if (suggestedType != null) {
          final transactionCount = addressData['transactionCount'] as int;
          final totalAmount = addressData['totalAmount'] as double;

          // Generate a descriptive name
          String labelName;
          switch (suggestedType) {
            case AddressLabelType.exchange:
              labelName = 'Exchange ($transactionCount txs)';
              break;
            case AddressLabelType.merchant:
              labelName = 'Merchant ($transactionCount txs)';
              break;
            case AddressLabelType.service:
              labelName = 'Service ($transactionCount txs)';
              break;
            case AddressLabelType.friend:
              labelName = 'Contact ($transactionCount txs)';
              break;
            case AddressLabelType.donation:
              labelName = 'Donation Address';
              break;
            default:
              labelName = 'External (${totalAmount.toStringAsFixed(1)} BTCZ)';
          }

          final label = AddressLabelManager.createLabel(
            address: address,
            labelName: labelName,
            type: suggestedType,
            isOwned: false,
            description: 'Auto-suggested based on transaction patterns',
          );

          suggestedLabels.add(label);
        }
      }

      return suggestedLabels;
    } catch (e) {
      if (kDebugMode) print('❌ Failed to auto-suggest external address labels: $e');
      return [];
    }
  }

  /// Get transaction patterns for an external address
  Future<Map<String, dynamic>> getExternalAddressPatterns(String address) async {
    try {
      final transactions = _transactions
          .where((tx) => tx.fromAddress == address || tx.toAddress == address)
          .toList();

      if (transactions.isEmpty) {
        return {};
      }

      // Calculate patterns
      final receivedTransactions = transactions.where((tx) => tx.isReceived).toList();
      final sentTransactions = transactions.where((tx) => !tx.isReceived).toList();

      final totalReceived = receivedTransactions.fold(0.0, (sum, tx) => sum + tx.amount.abs());
      final totalSent = sentTransactions.fold(0.0, (sum, tx) => sum + tx.amount.abs());

      // Time patterns
      final firstTransaction = transactions.map((t) => t.timestamp).reduce((a, b) => a.isBefore(b) ? a : b);
      final lastTransaction = transactions.map((t) => t.timestamp).reduce((a, b) => a.isAfter(b) ? a : b);
      final daysBetween = lastTransaction.difference(firstTransaction).inDays;

      // Frequency patterns
      final averageAmount = transactions.fold(0.0, (sum, tx) => sum + tx.amount.abs()) / transactions.length;
      final frequencyPerMonth = daysBetween > 0 ? (transactions.length / (daysBetween / 30.0)) : 0.0;

      // Memo analysis
      final memos = transactions.map((t) => t.memo ?? '').where((m) => m.isNotEmpty).toList();
      final uniqueMemos = memos.toSet().toList();

      return {
        'address': address,
        'totalTransactions': transactions.length,
        'receivedTransactions': receivedTransactions.length,
        'sentTransactions': sentTransactions.length,
        'totalReceived': totalReceived,
        'totalSent': totalSent,
        'netFlow': totalReceived - totalSent,
        'averageAmount': averageAmount,
        'firstTransaction': firstTransaction,
        'lastTransaction': lastTransaction,
        'daysBetween': daysBetween,
        'frequencyPerMonth': frequencyPerMonth,
        'memos': memos,
        'uniqueMemos': uniqueMemos,
        'transactions': transactions,
      };
    } catch (e) {
      if (kDebugMode) print('❌ Failed to get external address patterns: $e');
      return {};
    }
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

      // Clear analytics cache since transactions were updated
      clearAnalyticsCache();

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

  /// Mark a transaction memo as unread
  Future<void> markMemoAsUnread(String txid) async {
    try {
      // Update in-memory cache first
      _memoReadStatusCache[txid] = false;

      // Always save to SharedPreferences for persistence
      await _saveMemoStatusToPrefs(txid, false);

      // Also try to update in database (but don't fail if it doesn't work)
      try {
        await _databaseService.markTransactionMemoAsUnread(txid);
      } catch (dbError) {
        if (kDebugMode) print('⚠️ Database update failed (using SharedPreferences): $dbError');
      }

      // Update in memory
      final index = _transactions.indexWhere((tx) => tx.txid == txid);
      if (index != -1) {
        _transactions[index] = _transactions[index].copyWith(memoRead: false);
      }

      // Update unread count
      await updateUnreadMemoCount();

      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('❌ Error marking memo as unread: $e');
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

    // Clean up simple connection monitoring
    _simpleConnectionTimer?.cancel();

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

  /// Get seed phrase for backup purposes (requires prior authentication)
  Future<String?> getSeedPhrase() async {
    try {
      // First try to get stored seed phrase
      final storedSeed = _rustService.getSeedPhrase();
      if (storedSeed != null && storedSeed.isNotEmpty) {
        return storedSeed;
      }

      // If not available, use the 'seed' command to get it from the wallet
      final seedResult = await _rustService.getSeedPhraseFromWallet();
      return seedResult;
    } catch (e) {
      if (kDebugMode) print('❌ Failed to get seed phrase: $e');
      return null;
    }
  }

  /// Get wallet birthday block for backup purposes
  int? getBirthdayBlock() {
    return _rustService.getBirthday();
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

  /// Clear analytics cache (call when transactions are updated)
  void clearAnalyticsCache() {
    _analyticsCache.clear();
    _analyticsCacheTimestamps.clear();
    if (kDebugMode) print('📊 Cleared analytics cache');
  }

  /// Get analytics cache statistics
  Map<String, dynamic> getAnalyticsCacheStats() {
    return {
      'cacheSize': _analyticsCache.length,
      'oldestEntry': _analyticsCacheTimestamps.values.isNotEmpty
          ? _analyticsCacheTimestamps.values.reduce((a, b) => a.isBefore(b) ? a : b)
          : null,
      'newestEntry': _analyticsCacheTimestamps.values.isNotEmpty
          ? _analyticsCacheTimestamps.values.reduce((a, b) => a.isAfter(b) ? a : b)
          : null,
    };
  }
}