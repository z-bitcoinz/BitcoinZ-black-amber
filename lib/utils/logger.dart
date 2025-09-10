import 'package:flutter/foundation.dart';

/// Centralized logging utility for the BitcoinZ wallet app
/// Optimized for battery life by reducing excessive debug output
class Logger {
  // Production-safe log configuration
  static LogProfile _currentProfile = kDebugMode ? LogProfile.development : LogProfile.production;
  
  // Log categories for fine-grained control
  static bool enableWalletLogs = false;
  static bool enableNetworkLogs = false;
  static bool enableNotificationLogs = false;
  static bool enableDatabaseLogs = false;
  static bool enableAuthLogs = false;
  static bool enableSyncLogs = false;
  static bool enableTransactionLogs = false;
  static bool enableRustLogs = false;
  static bool enableStorageLogs = false;
  static bool enableContactLogs = false;
  
  // Global log level control
  static bool enableDebugLogs = false;
  static bool enableInfoLogs = false;
  static bool enableWarningLogs = true;
  static bool enableErrorLogs = true;
  
  // Initialize with appropriate profile
  static void initialize({LogProfile? profile}) {
    if (profile != null) {
      _currentProfile = profile;
    }
    _applyProfile(_currentProfile);
  }

  // Log level methods
  static void debug(String message, {String? category}) {
    if (!enableDebugLogs) return;
    if (category != null && !_isCategoryEnabled(category)) return;
    if (kDebugMode) print('DEBUG: $message');
  }

  static void info(String message, {String? category}) {
    if (!enableInfoLogs) return;
    if (category != null && !_isCategoryEnabled(category)) return;
    if (kDebugMode) print('INFO: $message');
  }

  static void warning(String message, {String? category}) {
    if (!enableWarningLogs) return;
    if (category != null && !_isCategoryEnabled(category)) return;
    print('WARNING: $message');
  }

  static void error(String message, {String? category, Object? exception}) {
    if (!enableErrorLogs) return;
    if (category != null && !_isCategoryEnabled(category)) return;
    print('ERROR: $message');
    if (exception != null) {
      print('Exception: $exception');
    }
  }

  // Category-specific logging methods
  static void wallet(String message, {LogLevel level = LogLevel.debug}) {
    _logWithLevel(message, 'wallet', level);
  }

  static void network(String message, {LogLevel level = LogLevel.debug}) {
    _logWithLevel(message, 'network', level);
  }

  static void notification(String message, {LogLevel level = LogLevel.debug}) {
    _logWithLevel(message, 'notification', level);
  }

  static void database(String message, {LogLevel level = LogLevel.debug}) {
    _logWithLevel(message, 'database', level);
  }

  static void auth(String message, {LogLevel level = LogLevel.debug}) {
    _logWithLevel(message, 'auth', level);
  }

  static void sync(String message, {LogLevel level = LogLevel.debug}) {
    _logWithLevel(message, 'sync', level);
  }

  static void transaction(String message, {LogLevel level = LogLevel.debug}) {
    _logWithLevel(message, 'transaction', level);
  }

  static void rust(String message, {LogLevel level = LogLevel.debug}) {
    _logWithLevel(message, 'rust', level);
  }

  static void storage(String message, {LogLevel level = LogLevel.debug}) {
    _logWithLevel(message, 'storage', level);
  }

  static void contact(String message, {LogLevel level = LogLevel.debug}) {
    _logWithLevel(message, 'contact', level);
  }

  // Helper methods
  static bool _isCategoryEnabled(String category) {
    switch (category.toLowerCase()) {
      case 'wallet':
        return enableWalletLogs;
      case 'network':
        return enableNetworkLogs;
      case 'notification':
        return enableNotificationLogs;
      case 'database':
        return enableDatabaseLogs;
      case 'auth':
        return enableAuthLogs;
      case 'sync':
        return enableSyncLogs;
      case 'transaction':
        return enableTransactionLogs;
      case 'rust':
        return enableRustLogs;
      case 'storage':
        return enableStorageLogs;
      case 'contact':
        return enableContactLogs;
      default:
        return true;
    }
  }

  static void _logWithLevel(String message, String category, LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        debug(message, category: category);
        break;
      case LogLevel.info:
        info(message, category: category);
        break;
      case LogLevel.warning:
        warning(message, category: category);
        break;
      case LogLevel.error:
        error(message, category: category);
        break;
    }
  }

  // Configuration methods for runtime control
  static void disableAllDebugLogs() {
    enableWalletLogs = false;
    enableNetworkLogs = false;
    enableNotificationLogs = false;
    enableDatabaseLogs = false;
    enableAuthLogs = false;
    enableSyncLogs = false;
    enableTransactionLogs = false;
    enableRustLogs = false;
    enableStorageLogs = false;
    enableContactLogs = false;
    enableDebugLogs = false;
  }

  static void enableOnlyErrors() {
    disableAllDebugLogs();
    enableInfoLogs = false;
    enableWarningLogs = false;
    enableErrorLogs = true;
  }

  static void enableProductionLogs() {
    disableAllDebugLogs();
    enableInfoLogs = false;
    enableWarningLogs = true;
    enableErrorLogs = true;
  }

  // Apply log profile configuration
  static void _applyProfile(LogProfile profile) {
    switch (profile) {
      case LogProfile.production:
        // Production: Only errors and critical warnings
        enableDebugLogs = false;
        enableInfoLogs = false;
        enableWarningLogs = true;
        enableErrorLogs = true;
        
        // Disable all battery-draining categories
        enableWalletLogs = false;
        enableNetworkLogs = false;
        enableNotificationLogs = false;
        enableDatabaseLogs = false;
        enableAuthLogs = false;
        enableSyncLogs = false;
        enableTransactionLogs = false;
        enableRustLogs = false;
        enableStorageLogs = false;
        enableContactLogs = false;
        break;
        
      case LogProfile.development:
        // Development: Enable selective logging
        enableDebugLogs = true;
        enableInfoLogs = true;
        enableWarningLogs = true;
        enableErrorLogs = true;
        
        // Enable only critical categories to reduce noise
        enableWalletLogs = false; // Still too verbose
        enableNetworkLogs = false; // Very battery draining
        enableNotificationLogs = true;
        enableDatabaseLogs = false; // Too verbose
        enableAuthLogs = true;
        enableSyncLogs = false; // Very battery draining
        enableTransactionLogs = true;
        enableRustLogs = false; // Too verbose
        enableStorageLogs = false;
        enableContactLogs = true;
        break;
        
      case LogProfile.verbose:
        // Verbose: Enable all logging (for debugging only)
        enableDebugLogs = true;
        enableInfoLogs = true;
        enableWarningLogs = true;
        enableErrorLogs = true;
        
        enableWalletLogs = true;
        enableNetworkLogs = true;
        enableNotificationLogs = true;
        enableDatabaseLogs = true;
        enableAuthLogs = true;
        enableSyncLogs = true;
        enableTransactionLogs = true;
        enableRustLogs = true;
        enableStorageLogs = true;
        enableContactLogs = true;
        break;
    }
  }
  
  // Get current profile
  static LogProfile get currentProfile => _currentProfile;
  
  // Set profile at runtime
  static void setProfile(LogProfile profile) {
    _currentProfile = profile;
    _applyProfile(profile);
  }
}

enum LogLevel {
  debug,
  info,
  warning,
  error,
}

enum LogProfile {
  production,   // Minimal logging for battery optimization
  development,  // Selective logging for development
  verbose,      // Full logging for debugging
}