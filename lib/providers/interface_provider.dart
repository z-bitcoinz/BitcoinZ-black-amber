import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider for managing interface and display preferences
class InterfaceProvider extends ChangeNotifier {
  static const String _analyticsTabVisibleKey = 'analytics_tab_visible';
  static const String _showDecimalsKey = 'show_decimals';

  bool _analyticsTabVisible = false;
  bool _showDecimals = true; // default: show fractional digits
  bool _isInitialized = false;

  /// Whether the analytics tab should be visible in the main navigation
  bool get analyticsTabVisible => _analyticsTabVisible;

  /// Whether to show decimal places after the dot
  bool get showDecimals => _showDecimals;

  /// Whether the provider has been initialized from storage
  bool get isInitialized => _isInitialized;

  /// Initialize the provider by loading preferences from storage
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      _analyticsTabVisible = prefs.getBool(_analyticsTabVisibleKey) ?? false; // Default to hidden
      _showDecimals = prefs.getBool(_showDecimalsKey) ?? true; // Default to showing decimals
      _isInitialized = true;

      if (kDebugMode) {
        print('🎨 Interface preferences loaded: analyticsTabVisible=$_analyticsTabVisible, showDecimals=$_showDecimals');
      }

      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to load interface preferences: $e');
      }
      // Use defaults if loading fails
      _analyticsTabVisible = false;
      _showDecimals = true;
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Set the visibility of the analytics tab
  Future<void> setAnalyticsTabVisible(bool visible) async {
    if (_analyticsTabVisible == visible) return;

    _analyticsTabVisible = visible;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_analyticsTabVisibleKey, visible);

      if (kDebugMode) {
        print('🎨 Analytics tab visibility changed to: $visible');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to save analytics tab visibility: $e');
      }
    }

    notifyListeners();
  }

  /// Toggle the analytics tab visibility
  Future<void> toggleAnalyticsTabVisible() async {
    await setAnalyticsTabVisible(!_analyticsTabVisible);
  }

  /// Set whether to show decimal places
  Future<void> setShowDecimals(bool value) async {
    if (_showDecimals == value) return;
    _showDecimals = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_showDecimalsKey, value);
      if (kDebugMode) {
        print('🎨 Show decimals changed to: $value');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to save showDecimals: $e');
      }
    }
    notifyListeners();
  }

  Future<void> toggleShowDecimals() async {
    await setShowDecimals(!_showDecimals);
  }

  /// Reset all interface preferences to defaults
  Future<void> resetToDefaults() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_analyticsTabVisibleKey);
      await prefs.remove(_showDecimalsKey);

      _analyticsTabVisible = false;
      _showDecimals = true;

      if (kDebugMode) {
        print('🎨 Interface preferences reset to defaults');
      }

      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to reset interface preferences: $e');
      }
    }
  }

  /// Get interface statistics for debugging
  Map<String, dynamic> getInterfaceStats() {
    return {
      'analyticsTabVisible': _analyticsTabVisible,
      'showDecimals': _showDecimals,
      'isInitialized': _isInitialized,
    };
  }

  @override
  void dispose() {
    super.dispose();
    if (kDebugMode) {
      print('🎨 InterfaceProvider disposed');
    }
  }
}
