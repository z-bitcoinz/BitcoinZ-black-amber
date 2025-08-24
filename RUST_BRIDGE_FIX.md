# Rust Bridge Fix - Custom Wallet Directory Issue Resolved

## Problem
The Rust Bridge was crashing with a serialization error when trying to use custom wallet directories for BitcoinZ Black Amber:
```
assertion `left == right` failed, left: 273, right: 198
```

## Root Cause
The `WalletStorageService` was creating a nested structure with a `wallet` subdirectory:
- Expected by Rust: `~/Library/Application Support/BitcoinZ Black Amber/`
- What we were passing: `~/Library/Application Support/BitcoinZ Black Amber/wallet/`

The extra nesting caused the LightClientConfig in the Rust API to fail during initialization.

## Solution
Modified `bitcoinz_rust_service.dart` to:
1. Pass the base wallet directory instead of the nested subdirectory
2. Let the Rust API handle creating its own `wallet.dat` file structure
3. Added proper error handling for directory creation failures

## Changes Made

### lib/services/bitcoinz_rust_service.dart
```dart
// Before (temporary fix):
String? walletDirPath = null; // Use default for now

// After (proper implementation):
String? walletDirPath;
try {
  final walletDir = await WalletStorageService.getWalletDirectory();
  walletDirPath = walletDir.path;
  if (kDebugMode) print('📁 Using Black Amber wallet directory: $walletDirPath');
} catch (e) {
  if (kDebugMode) print('⚠️ Failed to get wallet directory, using default: $e');
  walletDirPath = null;
}
```

## Platform-Specific Wallet Locations
The wallet data is now correctly stored in:

- **macOS**: `~/Library/Application Support/BitcoinZ Black Amber/`
- **iOS**: `Documents/bitcoinz-black-amber/`
- **Android**: `/data/data/com.bitcoinz.blackamber/app_flutter/bitcoinz-black-amber/`
- **Windows**: `%APPDATA%/BitcoinZ Black Amber/`
- **Linux**: `~/.local/share/bitcoinz-black-amber/`

## Testing Checklist
- [x] Build compiles without errors
- [x] Rust Bridge initializes without panic
- [x] Custom wallet directory is used correctly
- [x] Mempool monitoring works (1-second polling)
- [x] Balance updates properly
- [x] Transactions are detected

## Next Steps
1. Test wallet creation on each platform
2. Verify wallet data persistence across app restarts
3. Test migration from BitcoinZ Blue wallet (macOS)
4. Ensure proper wallet backup and restore functionality

## Status
✅ **FIXED** - The Rust Bridge now works properly with custom wallet directories for BitcoinZ Black Amber.