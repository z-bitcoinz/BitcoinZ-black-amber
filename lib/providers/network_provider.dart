import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:async';
import '../services/storage_service.dart';
import '../utils/constants.dart';
import '../src/rust/api.dart' as rust_api;

/// Provider for managing network settings and server configuration
class NetworkProvider with ChangeNotifier {
  String _currentServerUrl = AppConstants.defaultLightwalletdServer;
  List<ServerInfo> _predefinedServers = [];
  List<ServerInfo> _customServers = [];
  bool _isTestingConnection = false;
  String? _connectionError;
  ServerInfo? _currentServerInfo;
  Timer? _refreshTimer;
  
  // Connection logging cache
  DateTime? _lastConnectionLog;
  String? _lastConnectionResult;
  static const Duration _connectionLogCacheTimeout = Duration(minutes: 1);

  // Getters
  String get currentServerUrl => _currentServerUrl;
  List<ServerInfo> get predefinedServers => _predefinedServers;
  List<ServerInfo> get customServers => _customServers;
  List<ServerInfo> get allServers => [..._predefinedServers, ..._customServers];
  bool get isTestingConnection => _isTestingConnection;
  String? get connectionError => _connectionError;
  ServerInfo? get currentServerInfo => _currentServerInfo;
  
  NetworkProvider() {
    _initializePredefinedServers();
    _loadSettings();
  }

  /// Initialize predefined BitcoinZ servers
  void _initializePredefinedServers() {
    _predefinedServers = [
      ServerInfo(
        name: 'BitcoinZ Official',
        url: 'https://lightd.btcz.rocks:9067',
        description: 'Official BitcoinZ lightwalletd server',
        isOfficial: true,
      ),
      ServerInfo(
        name: 'BitcoinZ Backup',
        url: 'https://lightd2.btcz.rocks:9067',
        description: 'Official backup BitcoinZ server',
        isOfficial: true,
      ),
    ];
  }

  /// Load network settings from storage
  Future<void> _loadSettings() async {
    try {
      // Load current server
      final savedServer = await StorageService.read(key: AppConstants.currentServerKey);
      if (savedServer != null && savedServer.isNotEmpty) {
        _currentServerUrl = savedServer;
      }

      // Load custom servers
      final customServersJson = await StorageService.read(key: AppConstants.customServersKey);
      if (customServersJson != null && customServersJson.isNotEmpty) {
        final List<dynamic> serverList = jsonDecode(customServersJson);
        _customServers = serverList.map((json) => ServerInfo.fromJson(json)).toList();
      }

      // Test current server connection
      await _testServerConnection(_currentServerUrl, false);
      
      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('❌ NetworkProvider: Failed to load settings: $e');
    }
  }

  /// Save network settings to storage
  Future<void> _saveSettings() async {
    try {
      await StorageService.write(key: AppConstants.currentServerKey, value: _currentServerUrl);
      
      if (_customServers.isNotEmpty) {
        final customServersJson = jsonEncode(_customServers.map((s) => s.toJson()).toList());
        await StorageService.write(key: AppConstants.customServersKey, value: customServersJson);
      }
    } catch (e) {
      if (kDebugMode) print('❌ NetworkProvider: Failed to save settings: $e');
    }
  }

  /// Test connection to a server
  Future<bool> testConnection(String serverUrl) async {
    return await _testServerConnection(serverUrl, true);
  }

  /// Internal method to test server connection using Rust gRPC
  Future<bool> _testServerConnection(String serverUrl, bool showProgress) async {
    if (showProgress) {
      _isTestingConnection = true;
      _connectionError = null;
      notifyListeners();
    }

    try {
      // Check if we should log this connection test
      final now = DateTime.now();
      final connectionKey = '${serverUrl}_test';
      final shouldLog = _lastConnectionLog == null ||
                       now.difference(_lastConnectionLog!).compareTo(_connectionLogCacheTimeout) > 0 ||
                       _lastConnectionResult != connectionKey;
      
      if (kDebugMode && shouldLog) {
        print('🌐 Testing gRPC connection to: $serverUrl');
        _lastConnectionLog = now;
        _lastConnectionResult = connectionKey;
      }
      
      // Use Rust FFI to get server info via gRPC
      final result = await rust_api.getServerInfo(serverUri: serverUrl);
      final responseData = jsonDecode(result) as Map<String, dynamic>;
      
      if (responseData.containsKey('success') && responseData['success'] == true) {
        // Create ServerInfo from the detailed response
        final serverInfo = ServerInfo.fromRustResponse(serverUrl, responseData);
        
        if (serverUrl == _currentServerUrl) {
          _currentServerInfo = serverInfo;
          // Clear any stale errors when current server succeeds
          _connectionError = null;
        }
        
        // Only log success if we haven't logged recently or if server info changed
        final serverInfoHash = '${serverInfo.name}_${serverInfo.latestBlockHeight}';
        final infoChanged = _lastConnectionResult != serverInfoHash;
        
        if (kDebugMode && (shouldLog || infoChanged)) {
          print('✅ Server connection successful: ${serverInfo.name}');
          print('   Version: ${serverInfo.version}');
          print('   Vendor: ${serverInfo.vendor}');
          print('   Chain: ${serverInfo.chainName}');
          print('   Latest Block: ${serverInfo.latestBlockHeight}');
          _lastConnectionResult = serverInfoHash;
          print('   Build: ${serverInfo.zcashdBuild}');
        }
        
        // Always clear connection error on successful connection
        if (serverUrl == _currentServerUrl) {
          _connectionError = null;
        }
        
        if (showProgress) {
          _isTestingConnection = false;
        }
        notifyListeners(); // Always notify listeners when connection test completes
        return true;
      } else {
        // Handle error response
        final errorMsg = responseData['error'] ?? 'Unknown server error';
        final details = responseData['details'] ?? '';
        throw Exception('$errorMsg${details.isNotEmpty ? ' - $details' : ''}');
      }
    } catch (e) {
      final errorMsg = 'Failed to connect to server: $e';
      if (kDebugMode) print('❌ $errorMsg');
      
      _connectionError = errorMsg;
      if (showProgress) {
        _isTestingConnection = false;
      }
      notifyListeners(); // Always notify listeners when connection test completes
      return false;
    }
  }

  /// Switch to a different server
  Future<bool> switchServer(String serverUrl) async {
    if (serverUrl == _currentServerUrl) return true;
    
    // Clear any existing connection errors before attempting switch
    _connectionError = null;
    notifyListeners();
    
    if (kDebugMode) print('🔄 Attempting to switch to server: $serverUrl');
    
    // Test connection first
    final canConnect = await testConnection(serverUrl);
    if (!canConnect) {
      // Switch failed - restore current server status and clear the error from failed attempt
      if (kDebugMode) print('❌ Failed to switch to $serverUrl, staying on current server');
      
      // Clear the error from the failed switch attempt since we're staying on working server
      _connectionError = null;
      
      // Test current server to restore its status
      if (_currentServerUrl.isNotEmpty) {
        await _testServerConnection(_currentServerUrl, false);
      }
      
      return false;
    }

    _currentServerUrl = serverUrl;
    await _saveSettings();
    
    // Test the new server to get its info
    await _testServerConnection(serverUrl, false);
    
    notifyListeners();
    
    if (kDebugMode) print('✅ Successfully switched to server: $serverUrl');
    return true;
  }

  /// Add a custom server
  Future<bool> addCustomServer(String name, String url, String? description) async {
    // Validate URL format
    if (!_isValidServerUrl(url)) {
      _connectionError = 'Invalid server URL format';
      notifyListeners();
      return false;
    }

    // Check if server already exists
    if (_customServers.any((s) => s.url == url) || _predefinedServers.any((s) => s.url == url)) {
      _connectionError = 'Server already exists';
      notifyListeners();
      return false;
    }

    // Test connection
    final canConnect = await testConnection(url);
    if (!canConnect) {
      return false;
    }

    // Add to custom servers
    final serverInfo = ServerInfo(
      name: name,
      url: url,
      description: description ?? 'Custom server',
      isOfficial: false,
    );

    _customServers.add(serverInfo);
    await _saveSettings();
    
    notifyListeners();
    
    if (kDebugMode) print('➕ Added custom server: $name ($url)');
    return true;
  }

  /// Remove a custom server
  Future<void> removeCustomServer(String url) async {
    _customServers.removeWhere((s) => s.url == url);
    
    // If we're currently using this server, switch to default
    if (_currentServerUrl == url) {
      await switchServer(AppConstants.defaultLightwalletdServer);
    }
    
    await _saveSettings();
    notifyListeners();
    
    if (kDebugMode) print('➖ Removed custom server: $url');
  }

  /// Validate server URL format
  bool _isValidServerUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && 
             (uri.scheme == 'https' || uri.scheme == 'http') &&
             uri.hasPort &&
             uri.host.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Get server info by URL
  ServerInfo? getServerInfo(String url) {
    return allServers.firstWhere((s) => s.url == url, orElse: () => ServerInfo.unknown(url));
  }

  /// Clear connection error
  void clearError() {
    _connectionError = null;
    notifyListeners();
  }

  /// Clear stale errors if current server is working
  void clearStaleErrors() {
    // Only clear errors if we have a current server that's responsive
    if (_currentServerInfo != null && _currentServerInfo!.isResponsive && _connectionError != null) {
      if (kDebugMode) print('🧹 Clearing stale connection error - current server is responsive');
      _connectionError = null;
      notifyListeners();
    }
  }

  /// Start periodic server info refresh
  void startPeriodicRefresh() {
    _stopPeriodicRefresh(); // Stop any existing timer
    
    // Refresh server info every 30 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      if (_currentServerUrl.isNotEmpty) {
        await _testServerConnection(_currentServerUrl, false);
        // Clear any stale errors after successful refresh
        clearStaleErrors();
      }
    });
    
    if (kDebugMode) print('🔄 Started periodic server refresh (30s intervals)');
  }

  /// Stop periodic server info refresh
  void stopPeriodicRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    if (kDebugMode) print('⏹️ Stopped periodic server refresh');
  }
  
  /// Internal method to stop periodic refresh
  void _stopPeriodicRefresh() {
    stopPeriodicRefresh();
  }

  /// Clean up resources
  @override
  void dispose() {
    _stopPeriodicRefresh();
    super.dispose();
  }
}

/// Model for server information
class ServerInfo {
  final String name;
  final String url;
  final String description;
  final bool isOfficial;
  final String? version;
  final String? chainName;
  final int? latestBlockHeight;
  final String? vendor;
  final bool? taddrSupport;
  final int? saplingActivationHeight;
  final String? consensusBranchId;
  final String? gitCommit;
  final String? branch;
  final String? buildDate;
  final String? buildUser;
  final int? estimatedHeight;
  final String? zcashdBuild;
  final String? zcashdSubversion;
  final int? connectionTimestamp;
  final int? responseTimeMs;

  const ServerInfo({
    required this.name,
    required this.url,
    required this.description,
    required this.isOfficial,
    this.version,
    this.chainName,
    this.latestBlockHeight,
    this.vendor,
    this.taddrSupport,
    this.saplingActivationHeight,
    this.consensusBranchId,
    this.gitCommit,
    this.branch,
    this.buildDate,
    this.buildUser,
    this.estimatedHeight,
    this.zcashdBuild,
    this.zcashdSubversion,
    this.connectionTimestamp,
    this.responseTimeMs,
  });

  /// Create from JSON
  factory ServerInfo.fromJson(Map<String, dynamic> json) {
    return ServerInfo(
      name: json['name'] ?? '',
      url: json['url'] ?? '',
      description: json['description'] ?? '',
      isOfficial: json['isOfficial'] ?? false,
      version: json['version'],
      chainName: json['chainName'],
      latestBlockHeight: json['latestBlockHeight'],
      vendor: json['vendor'],
      taddrSupport: json['taddrSupport'],
      saplingActivationHeight: json['saplingActivationHeight'],
      consensusBranchId: json['consensusBranchId'],
      gitCommit: json['gitCommit'],
      branch: json['branch'],
      buildDate: json['buildDate'],
      buildUser: json['buildUser'],
      estimatedHeight: json['estimatedHeight'],
      zcashdBuild: json['zcashdBuild'],
      zcashdSubversion: json['zcashdSubversion'],
      connectionTimestamp: json['connectionTimestamp'],
      responseTimeMs: json['responseTimeMs'],
    );
  }

  /// Create from lightwalletd response
  factory ServerInfo.fromLightwalletdResponse(String url, String responseBody) {
    try {
      final json = jsonDecode(responseBody);
      final uri = Uri.parse(url);
      
      return ServerInfo(
        name: json['vendor'] ?? '${uri.host}:${uri.port}',
        url: url,
        description: 'BitcoinZ lightwalletd server',
        isOfficial: url.contains('btcz.rocks'),
        version: json['version'],
        chainName: json['chain_name'] ?? json['chainName'],
        latestBlockHeight: json['latest_block_height'] ?? json['latestBlockHeight'],
        vendor: json['vendor'],
      );
    } catch (e) {
      return ServerInfo.unknown(url);
    }
  }

  /// Create unknown server info
  factory ServerInfo.unknown(String url) {
    final uri = Uri.parse(url);
    return ServerInfo(
      name: '${uri.host}:${uri.port}',
      url: url,
      description: 'Unknown server',
      isOfficial: false,
    );
  }

  /// Create from Rust FFI response with complete server details
  factory ServerInfo.fromRustResponse(String url, Map<String, dynamic> json) {
    final uri = Uri.parse(url);
    final vendor = json['vendor'] ?? '';
    final version = json['version'] ?? '';
    
    return ServerInfo(
      name: vendor.isNotEmpty ? vendor : '${uri.host}:${uri.port}',
      url: url,
      description: 'BitcoinZ lightwalletd server',
      isOfficial: url.contains('btcz.rocks'),
      version: version,
      chainName: json['chain_name'],
      latestBlockHeight: json['block_height'] != null ? int.tryParse(json['block_height'].toString()) : null,
      vendor: vendor,
      taddrSupport: json['taddr_support'],
      saplingActivationHeight: json['sapling_activation_height'] != null ? int.tryParse(json['sapling_activation_height'].toString()) : null,
      consensusBranchId: json['consensus_branch_id'],
      gitCommit: json['git_commit'],
      branch: json['branch'],
      buildDate: json['build_date'],
      buildUser: json['build_user'],
      estimatedHeight: json['estimated_height'] != null ? int.tryParse(json['estimated_height'].toString()) : null,
      zcashdBuild: json['zcashd_build'],
      zcashdSubversion: json['zcashd_subversion'],
      connectionTimestamp: json['timestamp'] != null ? int.tryParse(json['timestamp'].toString()) : null,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'url': url,
      'description': description,
      'isOfficial': isOfficial,
      'version': version,
      'chainName': chainName,
      'latestBlockHeight': latestBlockHeight,
      'vendor': vendor,
      'taddrSupport': taddrSupport,
      'saplingActivationHeight': saplingActivationHeight,
      'consensusBranchId': consensusBranchId,
      'gitCommit': gitCommit,
      'branch': branch,
      'buildDate': buildDate,
      'buildUser': buildUser,
      'estimatedHeight': estimatedHeight,
      'zcashdBuild': zcashdBuild,
      'zcashdSubversion': zcashdSubversion,
      'connectionTimestamp': connectionTimestamp,
      'responseTimeMs': responseTimeMs,
    };
  }

  /// Get display name with status
  String get displayName {
    if (isOfficial) {
      return '$name (Official)';
    }
    return name;
  }

  /// Get connection status display
  String get statusDisplay {
    if (version != null && latestBlockHeight != null) {
      final chainDisplay = chainName != null ? ' • ${chainName!}' : '';
      final syncStatus = (estimatedHeight != null && latestBlockHeight != null && estimatedHeight! < latestBlockHeight!) 
          ? ' • Syncing' : '';
      return 'Connected • Block $latestBlockHeight$chainDisplay$syncStatus';
    }
    return 'Unknown';
  }
  
  /// Get detailed server information
  String get detailedInfo {
    final info = <String>[];
    
    if (version != null) info.add('Version: $version');
    if (vendor != null) info.add('Vendor: $vendor');
    if (chainName != null) info.add('Chain: $chainName');
    if (latestBlockHeight != null) info.add('Block Height: $latestBlockHeight');
    if (saplingActivationHeight != null) info.add('Sapling Height: $saplingActivationHeight');
    if (consensusBranchId != null) info.add('Branch ID: $consensusBranchId');
    if (zcashdBuild != null) info.add('Build: $zcashdBuild');
    if (buildDate != null) info.add('Build Date: $buildDate');
    if (taddrSupport != null) info.add('Transparent Support: ${taddrSupport! ? 'Yes' : 'No'}');
    
    return info.join('\n');
  }
  
  /// Get server capabilities as a list
  List<String> get capabilities {
    final caps = <String>[];
    
    // Network type
    if (chainName == 'main') {
      caps.add('Mainnet');
    } else if (chainName == 'test') {
      caps.add('Testnet');
    }
    
    // Server version
    if (version != null) {
      caps.add('v$version');
    }
    
    // Transparent address support
    if (taddrSupport == true) {
      caps.add('T-Addr Support');
    }
    
    // Server sync status
    if (estimatedHeight != null && latestBlockHeight != null) {
      if (estimatedHeight == latestBlockHeight) {
        caps.add('Live Sync');
      } else {
        caps.add('Syncing');
      }
    }
    
    // Official server indicator
    if (isOfficial) {
      caps.add('Official');
    }
    
    return caps;
  }
  
  /// Check if server is responsive (has recent connection timestamp)
  bool get isResponsive {
    if (connectionTimestamp == null) return false;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final connectionAge = now - connectionTimestamp!;
    return connectionAge < 300; // 5 minutes
  }
}