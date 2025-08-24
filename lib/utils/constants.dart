class AppConstants {
  // Network Configuration
  static const String defaultLightwalletdServer = 'https://lightd.btcz.rocks:9067';
  
  // BitcoinZ Constants
  static const int zatoshisPerBtcz = 100000000; // 1 BTCZ = 100,000,000 zatoshis
  static const double minTransactionAmount = 0.00000001; // Minimum transaction amount
  static const int defaultFeeZatoshis = 10000; // Default fee: 0.0001 BTCZ
  
  // Wallet Configuration
  static const int seedPhraseWordCount = 24;
  static const int pinLength = 6;
  static const int maxMemoLength = 512;
  
  // UI Constants
  static const double cardBorderRadius = 12.0;
  static const double buttonBorderRadius = 8.0;
  static const double defaultPadding = 16.0;
  static const double smallPadding = 8.0;
  static const double largePadding = 24.0;
  
  // Animation Durations
  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 400);
  static const Duration longAnimation = Duration(milliseconds: 600);
  
  // Security Settings
  static const Duration autoLockDuration = Duration(minutes: 5);
  static const int maxFailedAttempts = 5;
  static const Duration lockoutDuration = Duration(minutes: 15);
  
  // Storage Keys
  static const String walletIdKey = 'wallet_id';
  static const String hasWalletKey = 'has_wallet';
  static const String biometricsEnabledKey = 'biometrics_enabled';
  static const String autoLockEnabledKey = 'auto_lock_enabled';
  static const String themeKey = 'theme_mode';
  static const String languageKey = 'language';
  static const String currentServerKey = 'current_server_url';
  static const String customServersKey = 'custom_servers_list';
  
  // API Configuration
  static const Duration requestTimeout = Duration(seconds: 30);
  static const int maxRetryAttempts = 3;
  
  // Transaction Types
  static const String transactionTypeSent = 'sent';
  static const String transactionTypeReceived = 'received';
  static const String transactionTypePending = 'pending';
  
  // Address Types
  static const String addressTypeTransparent = 't';
  static const String addressTypeShielded = 'z';
  
  // Address Prefixes
  static const String transparentAddressPrefix = 't1';
  static const String transparentTestnetPrefix = 't3';
  static const String shieldedAddressPrefix = 'zs1';
  
  // QR Code Configuration
  static const double qrCodeSize = 200.0;
  static const int qrCodeVersion = 4;
  
  // Validation Patterns
  static final RegExp transparentAddressPattern = RegExp(r'^t[13][a-km-zA-HJ-NP-Z1-9]{25,34}$');
  static final RegExp shieldedAddressPattern = RegExp(r'^zs1[0-9a-z]{76}$');
  static final RegExp amountPattern = RegExp(r'^\d+(\.\d{1,8})?$');
  
  // App Information
  static const String appName = 'BitcoinZ Mobile Wallet';
  static const String appVersion = '1.0.0';
  static const String supportEmail = 'support@bitcoinz.global';
  static const String githubUrl = 'https://github.com/z-bitcoinz/BitcoinZ-Mobile-Wallet';
  static const String websiteUrl = 'https://bitcoinz.global';
  
  // Error Messages
  static const String errorNetworkUnavailable = 'Network is not available';
  static const String errorWalletNotInitialized = 'Wallet is not initialized';
  static const String errorInvalidSeedPhrase = 'Invalid seed phrase';
  static const String errorInvalidPin = 'Invalid PIN';
  static const String errorInsufficientFunds = 'Insufficient funds';
  static const String errorInvalidAddress = 'Invalid address';
  static const String errorTransactionFailed = 'Transaction failed';
  static const String errorSyncFailed = 'Sync failed';
  static const String errorBiometricsUnavailable = 'Biometrics not available';
  
  // Success Messages
  static const String successWalletCreated = 'Wallet created successfully';
  static const String successWalletRestored = 'Wallet restored successfully';
  static const String successTransactionSent = 'Transaction sent successfully';
  static const String successWalletSynced = 'Wallet synced successfully';
  static const String successAddressGenerated = 'New address generated';
  
  // Notification Messages
  static const String notificationNewTransaction = 'New transaction received';
  static const String notificationSyncComplete = 'Wallet sync completed';
  static const String notificationAutoLock = 'Wallet automatically locked';
}