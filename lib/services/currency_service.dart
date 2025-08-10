import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../models/currency_model.dart';

class CurrencyService {
  static const String _baseUrl = 'https://api.coingecko.com/api/v3';
  static const String _coinId = 'bitcoinz';
  static const Duration _cacheTimeout = Duration(minutes: 5);
  
  PriceData? _cachedPriceData;
  
  // Singleton pattern
  static final CurrencyService _instance = CurrencyService._internal();
  factory CurrencyService() => _instance;
  CurrencyService._internal();

  Future<PriceData?> fetchPrices({bool forceRefresh = false}) async {
    // Check if we have valid cached data
    if (!forceRefresh && _cachedPriceData != null && !_cachedPriceData!.isExpired) {
      if (kDebugMode) {
        print('[CurrencyService] Using cached price data');
      }
      return _cachedPriceData;
    }

    try {
      // Build the API URL with all supported currencies
      final currencyCodes = SupportedCurrencies.allCodes.join(',');
      final url = Uri.parse('$_baseUrl/simple/price?ids=$_coinId&vs_currencies=$currencyCodes');
      
      if (kDebugMode) {
        print('[CurrencyService] Fetching prices from CoinGecko...');
      }

      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data != null && data[_coinId] != null) {
          final Map<String, double> prices = {};
          
          // Extract prices for all currencies
          final btczData = data[_coinId] as Map<String, dynamic>;
          btczData.forEach((key, value) {
            if (value != null) {
              prices[key] = (value as num).toDouble();
            }
          });

          _cachedPriceData = PriceData(
            prices: prices,
            timestamp: DateTime.now(),
          );

          if (kDebugMode) {
            print('[CurrencyService] Successfully fetched ${prices.length} currency prices');
          }

          return _cachedPriceData;
        }
      } else {
        if (kDebugMode) {
          print('[CurrencyService] API returned status code: ${response.statusCode}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('[CurrencyService] Error fetching prices: $e');
      }
    }

    // Return cached data even if expired, if fetch failed
    return _cachedPriceData;
  }

  double? getPrice(String currencyCode) {
    if (_cachedPriceData == null) return null;
    return _cachedPriceData!.getPrice(currencyCode);
  }

  String formatCurrency(double amount, String currencyCode) {
    final currency = SupportedCurrencies.getByCode(currencyCode);
    
    // Format based on currency
    String formatted;
    if (currencyCode == 'JPY' || currencyCode == 'KRW' || currencyCode == 'VND' || currencyCode == 'IDR') {
      // No decimal places for these currencies
      formatted = amount.toStringAsFixed(0);
    } else {
      // 2 decimal places for most currencies
      formatted = amount.toStringAsFixed(2);
    }
    
    // Add thousand separators
    final parts = formatted.split('.');
    parts[0] = parts[0].replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    formatted = parts.join('.');
    
    // Add currency symbol
    if (currency.symbol.endsWith('\$')) {
      return '${currency.symbol}$formatted';
    } else {
      return '$formatted ${currency.symbol}';
    }
  }

  double? convertBtczToFiat(double btczAmount, String currencyCode) {
    final price = getPrice(currencyCode);
    if (price == null) return null;
    return btczAmount * price;
  }

  double? convertFiatToBtcz(double fiatAmount, String currencyCode) {
    final price = getPrice(currencyCode);
    if (price == null || price == 0) return null;
    return fiatAmount / price;
  }

  void clearCache() {
    _cachedPriceData = null;
  }
}