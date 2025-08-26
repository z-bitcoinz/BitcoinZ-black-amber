import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Service to monitor network connectivity and internet reachability
class NetworkService {
  static final NetworkService _instance = NetworkService._internal();
  factory NetworkService() => _instance;
  NetworkService._internal();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  
  bool _hasNetworkConnection = false;
  bool _hasInternetAccess = false;
  DateTime? _lastInternetCheck;
  
  final Duration _internetCheckCacheDuration = const Duration(seconds: 10);
  final List<String> _testUrls = [
    'https://www.google.com',
    'https://cloudflare.com',
    'https://1.1.1.1',
  ];

  // Stream controllers for broadcasting changes
  final _networkStatusController = StreamController<bool>.broadcast();
  final _internetStatusController = StreamController<bool>.broadcast();

  /// Stream of network connectivity changes (WiFi/Mobile/None)
  Stream<bool> get networkStatusStream => _networkStatusController.stream;
  
  /// Stream of internet reachability changes  
  Stream<bool> get internetStatusStream => _internetStatusController.stream;

  /// Current network connection status (WiFi/Mobile available)
  bool get hasNetworkConnection => _hasNetworkConnection;
  
  /// Current internet access status (can reach external servers)
  bool get hasInternetAccess => _hasInternetAccess;

  /// Initialize the network service
  Future<void> initialize() async {
    if (kDebugMode) print('🌐 NetworkService: Initializing...');
    
    // Check initial connectivity state
    await _updateNetworkStatus();
    await _checkInternetAccess();
    
    // Listen for connectivity changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _onConnectivityChanged,
    );
    
    if (kDebugMode) {
      print('🌐 NetworkService: Initialized - Network: $_hasNetworkConnection, Internet: $_hasInternetAccess');
    }
  }

  /// Handle connectivity state changes
  void _onConnectivityChanged(List<ConnectivityResult> results) async {
    if (kDebugMode) print('🌐 NetworkService: Connectivity changed - $results');
    
    await _updateNetworkStatus();
    
    // When network becomes available, check internet access
    if (_hasNetworkConnection) {
      await _checkInternetAccess();
    } else {
      // No network connection means no internet access
      _updateInternetStatus(false);
    }
  }

  /// Update network connection status based on connectivity result
  Future<void> _updateNetworkStatus() async {
    try {
      final results = await _connectivity.checkConnectivity();
      final hasConnection = results.any((result) => 
        result != ConnectivityResult.none
      );
      
      if (_hasNetworkConnection != hasConnection) {
        _hasNetworkConnection = hasConnection;
        _networkStatusController.add(_hasNetworkConnection);
        
        if (kDebugMode) {
          print('🌐 NetworkService: Network status changed - $_hasNetworkConnection');
        }
      }
    } catch (e) {
      if (kDebugMode) print('❌ NetworkService: Failed to check connectivity - $e');
      _hasNetworkConnection = false;
      _networkStatusController.add(_hasNetworkConnection);
    }
  }

  /// Check if internet access is available by testing external URLs
  Future<void> _checkInternetAccess() async {
    // Use cached result if recent
    final now = DateTime.now();
    if (_lastInternetCheck != null && 
        now.difference(_lastInternetCheck!).compareTo(_internetCheckCacheDuration) < 0) {
      return;
    }

    if (!_hasNetworkConnection) {
      _updateInternetStatus(false);
      return;
    }

    bool hasInternet = false;

    // Try multiple test URLs for reliability
    for (final url in _testUrls) {
      try {
        if (kDebugMode) print('🌐 NetworkService: Testing internet access via $url');
        
        final response = await http.head(
          Uri.parse(url),
          headers: {'User-Agent': 'BitcoinZ-Mobile-Wallet/1.0'},
        ).timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          hasInternet = true;
          if (kDebugMode) print('✅ NetworkService: Internet access confirmed via $url');
          break;
        }
      } catch (e) {
        if (kDebugMode) print('❌ NetworkService: Failed to reach $url - $e');
        continue;
      }
    }

    _lastInternetCheck = now;
    _updateInternetStatus(hasInternet);
  }

  /// Update internet access status and notify listeners
  void _updateInternetStatus(bool hasInternet) {
    if (_hasInternetAccess != hasInternet) {
      _hasInternetAccess = hasInternet;
      _internetStatusController.add(_hasInternetAccess);
      
      if (kDebugMode) {
        print('🌐 NetworkService: Internet status changed - $_hasInternetAccess');
      }
    }
  }

  // Server testing methods removed to prevent server load
  // Connection status is now based solely on Rust service operations

  /// Force refresh of internet connectivity status
  Future<void> refreshInternetStatus() async {
    _lastInternetCheck = null; // Clear cache
    await _checkInternetAccess();
  }

  /// Get detailed connectivity information for debugging
  Map<String, dynamic> getConnectionInfo() {
    return {
      'hasNetworkConnection': _hasNetworkConnection,
      'hasInternetAccess': _hasInternetAccess,
      'lastInternetCheck': _lastInternetCheck?.toIso8601String(),
    };
  }

  /// Clean up resources
  void dispose() {
    _connectivitySubscription?.cancel();
    _networkStatusController.close();
    _internetStatusController.close();
    
    if (kDebugMode) print('🌐 NetworkService: Disposed');
  }
}