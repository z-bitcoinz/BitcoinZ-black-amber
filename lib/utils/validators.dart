import 'package:bip39/bip39.dart' as bip39;
import 'constants.dart';

class Validators {
  /// Validate BitcoinZ address (transparent or shielded)
  static String? validateAddress(String? address) {
    if (address == null || address.isEmpty) {
      return 'Address is required';
    }

    final trimmed = address.trim();
    
    // Check transparent address
    if (trimmed.startsWith('t')) {
      if (AppConstants.transparentAddressPattern.hasMatch(trimmed)) {
        return null; // Valid transparent address
      }
      return 'Invalid transparent address format';
    }
    
    // Check shielded address
    if (trimmed.startsWith('zs1')) {
      if (AppConstants.shieldedAddressPattern.hasMatch(trimmed)) {
        return null; // Valid shielded address
      }
      return 'Invalid shielded address format';
    }
    
    return 'Invalid address format';
  }

  /// Validate amount
  static String? validateAmount(String? amount, {double? balance, double? minAmount}) {
    if (amount == null || amount.isEmpty) {
      return 'Amount is required';
    }

    final trimmed = amount.trim();
    
    // Check if it's a valid number format
    if (!AppConstants.amountPattern.hasMatch(trimmed)) {
      return 'Invalid amount format';
    }

    final parsedAmount = double.tryParse(trimmed);
    if (parsedAmount == null) {
      return 'Invalid amount';
    }

    // Check minimum amount
    final minimum = minAmount ?? AppConstants.minTransactionAmount;
    if (parsedAmount < minimum) {
      return 'Amount must be at least ${minimum.toStringAsFixed(8)} BTCZ';
    }

    // Check maximum amount (if balance provided)
    if (balance != null && parsedAmount > balance) {
      return 'Insufficient balance';
    }

    return null; // Valid amount
  }

  /// Validate seed phrase
  static String? validateSeedPhrase(String? seedPhrase) {
    if (seedPhrase == null || seedPhrase.isEmpty) {
      return 'Seed phrase is required';
    }

    final words = seedPhrase.trim().split(RegExp(r'\s+'));
    
    // Check word count
    if (words.length != AppConstants.seedPhraseWordCount) {
      return 'Seed phrase must be exactly ${AppConstants.seedPhraseWordCount} words';
    }

    // Validate using BIP39
    if (!bip39.validateMnemonic(seedPhrase.trim())) {
      return 'Invalid seed phrase';
    }

    return null; // Valid seed phrase
  }

  /// Validate PIN
  static String? validatePin(String? pin, {String? confirmPin}) {
    if (pin == null || pin.isEmpty) {
      return 'PIN is required';
    }

    if (pin.length != AppConstants.pinLength) {
      return 'PIN must be exactly ${AppConstants.pinLength} digits';
    }

    if (!RegExp(r'^\d+$').hasMatch(pin)) {
      return 'PIN must contain only digits';
    }

    // Check for simple patterns (optional security enhancement)
    if (_isWeakPin(pin)) {
      return 'PIN is too simple. Please choose a stronger PIN';
    }

    // Validate confirmation if provided
    if (confirmPin != null && pin != confirmPin) {
      return 'PINs do not match';
    }

    return null; // Valid PIN
  }

  /// Validate memo
  static String? validateMemo(String? memo, {required bool isShieldedTransaction}) {
    if (memo == null || memo.isEmpty) {
      return null; // Memo is optional
    }

    if (!isShieldedTransaction) {
      return 'Memos can only be sent to shielded addresses';
    }

    if (memo.length > AppConstants.maxMemoLength) {
      return 'Memo must be less than ${AppConstants.maxMemoLength} characters';
    }

    return null; // Valid memo
  }

  /// Validate email
  static String? validateEmail(String? email) {
    if (email == null || email.isEmpty) {
      return 'Email is required';
    }

    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email)) {
      return 'Invalid email format';
    }

    return null; // Valid email
  }

  /// Validate password
  static String? validatePassword(String? password, {String? confirmPassword}) {
    if (password == null || password.isEmpty) {
      return 'Password is required';
    }

    if (password.length < 8) {
      return 'Password must be at least 8 characters';
    }

    // Check for at least one uppercase, lowercase, and number
    if (!RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)').hasMatch(password)) {
      return 'Password must contain uppercase, lowercase, and number';
    }

    // Validate confirmation if provided
    if (confirmPassword != null && password != confirmPassword) {
      return 'Passwords do not match';
    }

    return null; // Valid password
  }

  /// Validate wallet name
  static String? validateWalletName(String? name) {
    if (name == null || name.isEmpty) {
      return 'Wallet name is required';
    }

    final trimmed = name.trim();
    
    if (trimmed.length < 2) {
      return 'Wallet name must be at least 2 characters';
    }

    if (trimmed.length > 50) {
      return 'Wallet name must be less than 50 characters';
    }

    // Check for valid characters (alphanumeric, spaces, hyphens, underscores)
    if (!RegExp(r'^[a-zA-Z0-9\s\-_]+$').hasMatch(trimmed)) {
      return 'Wallet name contains invalid characters';
    }

    return null; // Valid wallet name
  }

  /// Validate birthday height
  static String? validateBirthdayHeight(String? height) {
    if (height == null || height.isEmpty) {
      return null; // Birthday height is optional
    }

    final parsedHeight = int.tryParse(height);
    if (parsedHeight == null) {
      return 'Invalid block height';
    }

    if (parsedHeight < 0) {
      return 'Block height must be positive';
    }

    // Check reasonable upper bound (current height + some buffer)
    const maxReasonableHeight = 2000000; // Adjust based on network
    if (parsedHeight > maxReasonableHeight) {
      return 'Block height seems too high';
    }

    return null; // Valid birthday height
  }

  /// Check if amount has sufficient balance
  static bool hasSufficientBalance(double amount, double balance, {double? fee}) {
    final totalRequired = amount + (fee ?? AppConstants.defaultFeeZatoshis / AppConstants.zatoshisPerBtcz);
    return balance >= totalRequired;
  }

  /// Check if address is shielded
  static bool isShieldedAddress(String address) {
    return address.startsWith(AppConstants.shieldedAddressPrefix);
  }

  /// Check if address is transparent
  static bool isTransparentAddress(String address) {
    return address.startsWith('t1') || address.startsWith('t3');
  }

  /// Generate seed phrase
  static String generateSeedPhrase() {
    return bip39.generateMnemonic();
  }

  /// Validate seed phrase word
  static bool isValidSeedWord(String word) {
    return bip39.getWordList().contains(word.toLowerCase());
  }

  /// Private helper to check for weak PINs
  static bool _isWeakPin(String pin) {
    // Check for repeated digits
    if (RegExp(r'^(\d)\1+$').hasMatch(pin)) {
      return true; // All same digits (111111, 222222, etc.)
    }

    // Check for sequential digits
    if (_isSequential(pin)) {
      return true;
    }

    // Check for common weak PINs
    const weakPins = [
      '123456',
      '654321',
      '000000',
      '111111',
      '222222',
      '333333',
      '444444',
      '555555',
      '666666',
      '777777',
      '888888',
      '999999',
      '012345',
      '543210',
    ];

    return weakPins.contains(pin);
  }

  /// Check if PIN is sequential
  static bool _isSequential(String pin) {
    for (int i = 0; i < pin.length - 1; i++) {
      final current = int.parse(pin[i]);
      final next = int.parse(pin[i + 1]);
      
      // Check ascending sequence
      if (next != current + 1 && next != current - 1) {
        return false;
      }
    }
    return true;
  }
}