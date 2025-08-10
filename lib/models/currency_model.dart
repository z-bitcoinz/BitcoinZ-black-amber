class Currency {
  final String code;
  final String name;
  final String symbol;
  final String flag;

  const Currency({
    required this.code,
    required this.name,
    required this.symbol,
    required this.flag,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Currency &&
          runtimeType == other.runtimeType &&
          code == other.code;

  @override
  int get hashCode => code.hashCode;
}

class PriceData {
  final Map<String, double> prices;
  final DateTime timestamp;

  PriceData({
    required this.prices,
    required this.timestamp,
  });

  bool get isExpired {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    return difference.inMinutes >= 5;
  }

  double? getPrice(String currencyCode) {
    return prices[currencyCode.toLowerCase()];
  }
}

// Top 40 most popular fiat currencies
class SupportedCurrencies {
  static const List<Currency> currencies = [
    Currency(code: 'USD', name: 'US Dollar', symbol: '\$', flag: '🇺🇸'),
    Currency(code: 'EUR', name: 'Euro', symbol: '€', flag: '🇪🇺'),
    Currency(code: 'JPY', name: 'Japanese Yen', symbol: '¥', flag: '🇯🇵'),
    Currency(code: 'GBP', name: 'British Pound', symbol: '£', flag: '🇬🇧'),
    Currency(code: 'AUD', name: 'Australian Dollar', symbol: 'A\$', flag: '🇦🇺'),
    Currency(code: 'CAD', name: 'Canadian Dollar', symbol: 'C\$', flag: '🇨🇦'),
    Currency(code: 'CHF', name: 'Swiss Franc', symbol: 'Fr', flag: '🇨🇭'),
    Currency(code: 'CNY', name: 'Chinese Yuan', symbol: '¥', flag: '🇨🇳'),
    Currency(code: 'HKD', name: 'Hong Kong Dollar', symbol: 'HK\$', flag: '🇭🇰'),
    Currency(code: 'NZD', name: 'New Zealand Dollar', symbol: 'NZ\$', flag: '🇳🇿'),
    Currency(code: 'SEK', name: 'Swedish Krona', symbol: 'kr', flag: '🇸🇪'),
    Currency(code: 'NOK', name: 'Norwegian Krone', symbol: 'kr', flag: '🇳🇴'),
    Currency(code: 'MXN', name: 'Mexican Peso', symbol: '\$', flag: '🇲🇽'),
    Currency(code: 'SGD', name: 'Singapore Dollar', symbol: 'S\$', flag: '🇸🇬'),
    Currency(code: 'ZAR', name: 'South African Rand', symbol: 'R', flag: '🇿🇦'),
    Currency(code: 'KRW', name: 'South Korean Won', symbol: '₩', flag: '🇰🇷'),
    Currency(code: 'INR', name: 'Indian Rupee', symbol: '₹', flag: '🇮🇳'),
    Currency(code: 'BRL', name: 'Brazilian Real', symbol: 'R\$', flag: '🇧🇷'),
    Currency(code: 'RUB', name: 'Russian Ruble', symbol: '₽', flag: '🇷🇺'),
    Currency(code: 'DKK', name: 'Danish Krone', symbol: 'kr', flag: '🇩🇰'),
    Currency(code: 'PLN', name: 'Polish Zloty', symbol: 'zł', flag: '🇵🇱'),
    Currency(code: 'THB', name: 'Thai Baht', symbol: '฿', flag: '🇹🇭'),
    Currency(code: 'IDR', name: 'Indonesian Rupiah', symbol: 'Rp', flag: '🇮🇩'),
    Currency(code: 'HUF', name: 'Hungarian Forint', symbol: 'Ft', flag: '🇭🇺'),
    Currency(code: 'CZK', name: 'Czech Koruna', symbol: 'Kč', flag: '🇨🇿'),
    Currency(code: 'ILS', name: 'Israeli Shekel', symbol: '₪', flag: '🇮🇱'),
    Currency(code: 'CLP', name: 'Chilean Peso', symbol: '\$', flag: '🇨🇱'),
    Currency(code: 'PHP', name: 'Philippine Peso', symbol: '₱', flag: '🇵🇭'),
    Currency(code: 'AED', name: 'UAE Dirham', symbol: 'د.إ', flag: '🇦🇪'),
    Currency(code: 'COP', name: 'Colombian Peso', symbol: '\$', flag: '🇨🇴'),
    Currency(code: 'SAR', name: 'Saudi Riyal', symbol: '﷼', flag: '🇸🇦'),
    Currency(code: 'MYR', name: 'Malaysian Ringgit', symbol: 'RM', flag: '🇲🇾'),
    Currency(code: 'RON', name: 'Romanian Leu', symbol: 'lei', flag: '🇷🇴'),
    Currency(code: 'ARS', name: 'Argentine Peso', symbol: '\$', flag: '🇦🇷'),
    Currency(code: 'BGN', name: 'Bulgarian Lev', symbol: 'лв', flag: '🇧🇬'),
    Currency(code: 'HRK', name: 'Croatian Kuna', symbol: 'kn', flag: '🇭🇷'),
    Currency(code: 'PEN', name: 'Peruvian Sol', symbol: 'S/', flag: '🇵🇪'),
    Currency(code: 'VND', name: 'Vietnamese Dong', symbol: '₫', flag: '🇻🇳'),
    Currency(code: 'EGP', name: 'Egyptian Pound', symbol: '£', flag: '🇪🇬'),
    Currency(code: 'PKR', name: 'Pakistani Rupee', symbol: '₨', flag: '🇵🇰'),
  ];

  static Currency getByCode(String code) {
    return currencies.firstWhere(
      (c) => c.code == code,
      orElse: () => currencies.first, // Default to USD
    );
  }

  static List<String> get allCodes {
    return currencies.map((c) => c.code.toLowerCase()).toList();
  }
}