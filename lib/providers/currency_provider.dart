import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/currency_model.dart';
import '../services/currency_service.dart';

class CurrencyProvider extends ChangeNotifier {
  static const String _currencyPrefKey = 'selected_currency';
  
  final CurrencyService _currencyService = CurrencyService();
  Currency _selectedCurrency = SupportedCurrencies.currencies.first; // Default to USD
  PriceData? _priceData;
  bool _isLoading = false;
  Timer? _refreshTimer;
  
  Currency get selectedCurrency => _selectedCurrency;
  PriceData? get priceData => _priceData;
  bool get isLoading => _isLoading;
  
  double? get currentPrice => _priceData?.getPrice(_selectedCurrency.code);
  
  CurrencyProvider() {
    _initialize();
  }
  
  Future<void> _initialize() async {
    await _loadSelectedCurrency();
    await fetchPrices();
    _startAutoRefresh();
  }
  
  Future<void> _loadSelectedCurrency() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currencyCode = prefs.getString(_currencyPrefKey) ?? 'USD';
      _selectedCurrency = SupportedCurrencies.getByCode(currencyCode);
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('[CurrencyProvider] Error loading currency preference: $e');
      }
    }
  }
  
  Future<void> setSelectedCurrency(Currency currency) async {
    if (_selectedCurrency == currency) return;
    
    _selectedCurrency = currency;
    notifyListeners();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_currencyPrefKey, currency.code);
    } catch (e) {
      if (kDebugMode) {
        print('[CurrencyProvider] Error saving currency preference: $e');
      }
    }
  }
  
  Future<void> fetchPrices({bool forceRefresh = false}) async {
    if (_isLoading) return;
    
    _isLoading = true;
    notifyListeners();
    
    try {
      final data = await _currencyService.fetchPrices(forceRefresh: forceRefresh);
      if (data != null) {
        _priceData = data;
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) {
        print('[CurrencyProvider] Error fetching prices: $e');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      fetchPrices();
    });
  }
  
  String formatFiatAmount(double btczAmount) {
    final fiatAmount = convertBtczToFiat(btczAmount);
    if (fiatAmount == null) return '';
    return _currencyService.formatCurrency(fiatAmount, _selectedCurrency.code);
  }
  
  double? convertBtczToFiat(double btczAmount) {
    return _currencyService.convertBtczToFiat(btczAmount, _selectedCurrency.code);
  }
  
  double? convertFiatToBtcz(double fiatAmount) {
    return _currencyService.convertFiatToBtcz(fiatAmount, _selectedCurrency.code);
  }
  
  String formatWithSymbol(double amount) {
    return _currencyService.formatCurrency(amount, _selectedCurrency.code);
  }
  
  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}