import 'package:intl/intl.dart';
import 'constants.dart';

class Formatters {
  static final NumberFormat _currencyFormat = NumberFormat('#,##0.00000000', 'en_US');
  static final NumberFormat _compactCurrencyFormat = NumberFormat.compact(locale: 'en_US');
  static final DateFormat _dateFormat = DateFormat('MMM dd, yyyy');
  static final DateFormat _timeFormat = DateFormat('HH:mm');
  static final DateFormat _dateTimeFormat = DateFormat('MMM dd, yyyy HH:mm');

  /// Format BTCZ amount with proper decimal places
  static String formatBtcz(double amount, {bool showSymbol = true, int? decimals}) {
    if (amount == 0) return showSymbol ? '0.00000000 BTCZ' : '0.00000000';
    
    final formatted = decimals != null 
        ? amount.toStringAsFixed(decimals)
        : _formatBtczAmount(amount);
    
    return showSymbol ? '$formatted BTCZ' : formatted;
  }

  /// Format amount in zatoshis to BTCZ
  static String formatZatoshis(int zatoshis, {bool showSymbol = true, int? decimals}) {
    final btcz = zatoshis / AppConstants.zatoshisPerBtcz;
    return formatBtcz(btcz, showSymbol: showSymbol, decimals: decimals);
  }

  /// Format large numbers in compact form (1.2K, 1.5M, etc.)
  static String formatCompactNumber(double number) {
    return _compactCurrencyFormat.format(number);
  }

  /// Format percentage
  static String formatPercentage(double percentage, {int decimals = 1}) {
    return '${percentage.toStringAsFixed(decimals)}%';
  }

  /// Format date
  static String formatDate(DateTime date) {
    return _dateFormat.format(date);
  }

  /// Format time
  static String formatTime(DateTime date) {
    return _timeFormat.format(date);
  }

  /// Format date and time
  static String formatDateTime(DateTime date) {
    return _dateTimeFormat.format(date);
  }

  /// Format relative time (e.g., "2 minutes ago", "1 hour ago")
  static String formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      final minutes = difference.inMinutes;
      return '$minutes minute${minutes == 1 ? '' : 's'} ago';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return '$hours hour${hours == 1 ? '' : 's'} ago';
    } else if (difference.inDays < 7) {
      final days = difference.inDays;
      return '$days day${days == 1 ? '' : 's'} ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks week${weeks == 1 ? '' : 's'} ago';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '$months month${months == 1 ? '' : 's'} ago';
    } else {
      final years = (difference.inDays / 365).floor();
      return '$years year${years == 1 ? '' : 's'} ago';
    }
  }

  /// Format address for display (truncate middle)
  static String formatAddress(String address, {int startChars = 6, int endChars = 6}) {
    if (address.length <= startChars + endChars) {
      return address;
    }
    return '${address.substring(0, startChars)}...${address.substring(address.length - endChars)}';
  }

  /// Format transaction ID for display
  static String formatTxId(String txId, {int startChars = 8, int endChars = 8}) {
    return formatAddress(txId, startChars: startChars, endChars: endChars);
  }

  /// Format file size
  static String formatFileSize(int bytes) {
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double size = bytes.toDouble();
    
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    
    return '${size.toStringAsFixed(size < 10 ? 1 : 0)} ${suffixes[i]}';
  }

  /// Format duration
  static String formatDuration(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays}d ${duration.inHours % 24}h';
    } else if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${duration.inSeconds % 60}s';
    } else {
      return '${duration.inSeconds}s';
    }
  }

  /// Format sync progress
  static String formatSyncProgress(int currentBlock, int totalBlocks) {
    if (totalBlocks == 0) return '0%';
    final percentage = (currentBlock / totalBlocks * 100).clamp(0, 100);
    return '${percentage.toStringAsFixed(1)}%';
  }

  /// Format block height with thousands separator
  static String formatBlockHeight(int blockHeight) {
    return NumberFormat('#,###').format(blockHeight);
  }

  /// Validate and format user input amount
  static String? formatInputAmount(String input) {
    if (input.isEmpty) return null;
    
    // Remove any non-numeric characters except decimal point
    final cleaned = input.replaceAll(RegExp(r'[^\d.]'), '');
    
    // Check if it's a valid number
    final number = double.tryParse(cleaned);
    if (number == null) return null;
    
    // Limit to 8 decimal places
    return number.toStringAsFixed(8).replaceAll(RegExp(r'0*$'), '').replaceAll(RegExp(r'\.$'), '');
  }

  /// Private helper to format BTCZ amount with proper precision
  static String _formatBtczAmount(double amount) {
    // Show up to 8 decimal places, removing trailing zeros
    String formatted = amount.toStringAsFixed(8);
    formatted = formatted.replaceAll(RegExp(r'0*$'), '');
    formatted = formatted.replaceAll(RegExp(r'\.$'), '');
    
    // Ensure at least 2 decimal places for small amounts
    if (!formatted.contains('.')) {
      formatted += '.00';
    } else {
      final decimals = formatted.split('.')[1];
      if (decimals.length == 1) {
        formatted += '0';
      }
    }
    
    return formatted;
  }

  /// Parse user input to double
  static double? parseAmount(String input) {
    if (input.isEmpty) return null;
    
    // Remove any non-numeric characters except decimal point
    final cleaned = input.replaceAll(RegExp(r'[^\d.]'), '');
    
    return double.tryParse(cleaned);
  }

  /// Convert BTCZ to zatoshis
  static int btczToZatoshis(double btcz) {
    return (btcz * AppConstants.zatoshisPerBtcz).round();
  }

  /// Convert zatoshis to BTCZ
  static double zatoshisToBtcz(int zatoshis) {
    return zatoshis / AppConstants.zatoshisPerBtcz;
  }

  /// Format seed phrase for display (masked)
  static String formatSeedPhrase(List<String> words, {bool masked = false}) {
    if (masked) {
      return words.map((word) => '•' * word.length).join(' ');
    }
    return words.join(' ');
  }

  /// Format PIN for display (masked)
  static String formatPin(String pin, {bool masked = true}) {
    if (masked) {
      return '•' * pin.length;
    }
    return pin;
  }
}