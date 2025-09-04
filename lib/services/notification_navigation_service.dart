import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../screens/main_screen.dart';

/// Service to handle navigation from notifications
class NotificationNavigationService {
  static final NotificationNavigationService _instance = NotificationNavigationService._internal();
  factory NotificationNavigationService() => _instance;
  NotificationNavigationService._internal();

  static NotificationNavigationService get instance => _instance;

  /// Handle notification tap and navigate to appropriate screen
  Future<void> handleNotificationTap(String? payload) async {
    if (payload == null || payload.isEmpty) return;

    try {
      if (kDebugMode) print('🔔 Handling notification tap: $payload');

      // Parse the payload to determine navigation action
      if (payload.startsWith('/')) {
        // Direct route navigation
        await _navigateToRoute(payload);
      } else {
        // JSON payload with additional data
        await _handleJsonPayload(payload);
      }
    } catch (e) {
      if (kDebugMode) print('❌ Failed to handle notification tap: $e');
    }
  }

  /// Navigate to a specific route
  Future<void> _navigateToRoute(String route) async {
    final context = MainScreen.navigatorKey.currentContext;
    if (context == null) {
      if (kDebugMode) print('⚠️ No navigation context available');
      return;
    }

    switch (route) {
      case '/wallet/dashboard':
        _navigateToTab(0); // Dashboard tab
        break;
      case '/wallet/send':
        _navigateToTab(1); // Send tab
        break;
      case '/wallet/receive':
        _navigateToTab(2); // Receive tab
        break;
      case '/wallet/transactions':
      case '/transactions':
        _navigateToTab(3); // Transaction history tab
        break;
      case '/messages':
        _navigateToTab(3); // Transaction history tab (where messages are shown)
        break;
      case '/analytics':
        _navigateToTab(4); // Analytics tab (if visible)
        break;
      case '/contacts':
        _navigateToTab(5); // Contacts tab
        break;
      case '/settings':
        _navigateToSettings();
        break;
      default:
        if (kDebugMode) print('⚠️ Unknown route: $route');
        _navigateToTab(0); // Default to dashboard
    }
  }

  /// Handle JSON payload with additional data
  Future<void> _handleJsonPayload(String jsonPayload) async {
    // For now, just navigate to dashboard
    // In the future, this could parse JSON and extract specific navigation data
    _navigateToTab(0);
  }

  /// Navigate to a specific tab in the main screen
  void _navigateToTab(int tabIndex) {
    try {
      if (kDebugMode) print('🔔 Navigating to tab: $tabIndex');

      // Use the MainScreen static method to navigate to the tab
      MainScreen.navigateToTab(tabIndex);
    } catch (e) {
      if (kDebugMode) print('❌ Failed to navigate to tab $tabIndex: $e');
    }
  }

  /// Navigate to settings screen
  void _navigateToSettings() {
    final context = MainScreen.navigatorKey.currentContext;
    if (context == null) {
      if (kDebugMode) print('⚠️ No navigation context available for settings');
      return;
    }

    // Navigate to settings (this would need to be implemented)
    if (kDebugMode) print('🔔 Would navigate to settings');
  }

  /// Navigate to transaction details
  Future<void> navigateToTransactionDetails(String transactionId) async {
    if (kDebugMode) print('🔔 Navigating to transaction details: $transactionId');
    
    // Navigate to transaction history tab first
    _navigateToTab(3);
    
    // TODO: Implement transaction details navigation
    // This could involve passing the transaction ID to the transaction history screen
    // and having it automatically scroll to or highlight the specific transaction
  }

  /// Navigate to messages/memos
  Future<void> navigateToMessages() async {
    if (kDebugMode) print('🔔 Navigating to messages');
    
    // Navigate to transaction history tab where messages are shown
    _navigateToTab(3);
    
    // TODO: Implement message filtering or highlighting
    // This could involve setting a filter on the transaction history screen
    // to show only transactions with memos
  }

  /// Navigate to specific message
  Future<void> navigateToMessage(String transactionId) async {
    if (kDebugMode) print('🔔 Navigating to message: $transactionId');
    
    // Navigate to transaction details
    await navigateToTransactionDetails(transactionId);
  }

  /// Navigate to balance/dashboard
  Future<void> navigateToDashboard() async {
    if (kDebugMode) print('🔔 Navigating to dashboard');
    _navigateToTab(0);
  }

  /// Check if the app is in foreground and navigation is possible
  bool get canNavigate {
    return MainScreen.navigatorKey.currentContext != null;
  }
}
