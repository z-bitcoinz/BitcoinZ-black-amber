# Wallet Data Cleanup - Complete

## Summary
Successfully deleted all old wallet data and preferences to ensure a clean state for the BitcoinZ Black Amber wallet.

## What Was Deleted

### ✅ Deleted Successfully
1. **Application Support Directory**
   - `/Users/name/Library/Application Support/com.bitcoinz.blackamber/` - Main wallet data directory
   
2. **Preferences**
   - `com.bitcoinz.blackamber.plist` - macOS preferences file

3. **Flutter Cache**
   - Build directory
   - `.dart_tool` directory
   - Ephemeral files
   - Plugin dependencies

### ❌ Not Found (Already Clean)
- BitcoinZ Blue wallet data
- BitcoinZ Black Amber (with spaces) directory
- Zecwallet Lightclient default directory
- Test/debug wallet directories
- Cache directories
- Database files in Documents

## Cleanup Script Created

A reusable cleanup script has been created at:
`delete_wallet_data.sh`

### Script Features
- Checks multiple potential wallet locations
- Deletes wallet data directories
- Clears preferences
- Removes cache files
- Provides clear feedback on what was deleted

### How to Use
```bash
# Make executable (already done)
chmod +x delete_wallet_data.sh

# Run cleanup
./delete_wallet_data.sh

# Then clean Flutter
flutter clean
flutter pub get
```

## Current State

### ✅ Clean State Achieved
- No old wallet data remains
- No cached preferences
- Flutter cache cleared
- App rebuilt successfully
- Ready for fresh wallet creation

### Next Steps
When you run the app now:
1. It will show the onboarding/welcome screen
2. You can create a new wallet
3. Or restore from a seed phrase
4. All data will be stored in proper locations

## Important Notes

⚠️ **All wallet data has been permanently deleted**
- You'll need to create a new wallet or restore from seed phrase
- No transaction history or addresses are retained
- This is a complete fresh start

## Wallet Data Locations (For Reference)

When new wallets are created, data will be stored in:
- **Default Rust location**: `~/Library/Application Support/Zecwallet Lightclient/`
- **Future Black Amber location**: `~/Library/Application Support/BitcoinZ Black Amber/`
  (Once custom directory serialization is fixed)

## Verification

Build status after cleanup:
```
✓ Built build/macos/Build/Products/Debug/BitcoinZ Black Amber.app
```

The app is ready to run with a completely clean state.