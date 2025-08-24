import 'dart:io';
import 'dart:ffi';
import 'dart:convert';
import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as path;

// Import the existing FFI types and wallet state from cli_test.dart
// We'll reuse the same BitcoinZ CLI functionality but in a persistent session

/// Represents the current wallet session state
class WalletSession {
  // Wallet state management
  WalletState? _currentWalletState;
  static const String _walletStateFile = '.bitcoinz_cli_wallet.json';
  
  // Session information
  DateTime? _sessionStart;
  int _commandCount = 0;
  bool _isInitialized = false;
  
  // FFI components (will be initialized once and reused)
  late DynamicLibrary _lib;
  
  /// Initialize the session
  Future<void> initialize() async {
    _sessionStart = DateTime.now();
    
    try {
      await _loadLibrary();
      await _loadWalletState();
      _isInitialized = true;
    } catch (e) {
      throw Exception('Failed to initialize wallet session: $e');
    }
  }
  
  /// Load the native library
  Future<void> _loadLibrary() async {
    // Load the same library as cli_test.dart
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
  
  /// Load existing wallet state if available
  Future<void> _loadWalletState() async {
    try {
      final stateFile = File(_walletStateFilePath);
      if (stateFile.existsSync()) {
        final content = stateFile.readAsStringSync();
        final json = jsonDecode(content);
        _currentWalletState = WalletState.fromJson(json);
      }
    } catch (e) {
      // If loading fails, we'll start without a wallet
      _currentWalletState = null;
    }
  }
  
  /// Save current wallet state
  void _saveWalletState() {
    if (_currentWalletState == null) return;
    
    try {
      final stateFile = File(_walletStateFilePath);
      final json = jsonEncode(_currentWalletState!.toJson());
      stateFile.writeAsStringSync(json);
    } catch (e) {
      // Silently handle save errors for now
    }
  }
  
  /// Public method to save wallet state
  void save() => _saveWalletState();
  
  /// Get the path to the wallet state file
  String get _walletStateFilePath {
    final homeDir = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '.';
    return path.join(homeDir, _walletStateFile);
  }
  
  /// Get session information
  Map<String, dynamic> get sessionInfo => {
    'initialized': _isInitialized,
    'started': _sessionStart?.toIso8601String(),
    'commands_executed': _commandCount,
    'has_wallet': _currentWalletState != null,
    'wallet_id': _currentWalletState?.walletId,
  };
  
  /// Check if wallet is loaded
  bool get hasWallet => _currentWalletState != null;
  
  /// Get current wallet state (read-only)
  WalletState? get walletState => _currentWalletState;
  
  /// Increment command counter
  void incrementCommandCount() {
    _commandCount++;
  }
  
  /// Clear wallet state
  void clearWallet() {
    _currentWalletState = null;
    try {
      final stateFile = File(_walletStateFilePath);
      if (stateFile.existsSync()) {
        stateFile.deleteSync();
      }
    } catch (e) {
      // Silently handle file deletion errors
    }
  }
  
  /// Create or restore wallet state
  void setWalletState(WalletState state) {
    _currentWalletState = state;
    _saveWalletState();
  }
  
  /// Get formatted session duration
  String get sessionDuration {
    if (_sessionStart == null) return 'Unknown';
    
    final duration = DateTime.now().difference(_sessionStart!);
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${duration.inSeconds.remainder(60)}s';
    } else {
      return '${duration.inSeconds}s';
    }
  }
}

/// Persistent wallet state structure (copied from cli_test.dart)
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