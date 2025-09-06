import 'package:flutter/foundation.dart';

/// Centralized logging utility for the BitcoinZ wallet app
class Logger {
  // Log categories for fine-grained control
  static bool enableWalletLogs = kDebugMode;
  static bool enableNetworkLogs = kDebugMode;
  static bool enableNotificationLogs = kDebugMode;
  static bool enableDatabaseLogs = kDebugMode;
  static bool enableAuthLogs = kDebugMode;
  static bool enableSyncLogs = kDebugMode;
  static bool enableTransactionLogs = kDebugMode;
  static bool enableRustLogs = kDebugMode;
  static bool enableStorageLogs = kDebugMode;
  static bool enableContactLogs = kDebugMode;
  
  // Global log level control
  static bool enableDebugLogs = kDebugMode;
  static bool enableInfoLogs = true;
  static bool enableWarningLogs = true;
  static bool enableErrorLogs = true;

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
}

enum LogLevel {
  debug,
  info,
  warning,
  error,
}