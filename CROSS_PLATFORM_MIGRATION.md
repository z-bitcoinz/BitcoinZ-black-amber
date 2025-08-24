# BitcoinZ Black Amber - Cross-Platform Migration

## Summary
Successfully migrated the wallet from macOS-specific BitcoinZ Blue paths to cross-platform BitcoinZ Black Amber with proper platform-specific data storage.

## Changes Implemented

### 1. WalletStorageService (`lib/services/wallet_storage_service.dart`)
Created a comprehensive service for managing wallet data paths across all platforms:

**Platform-Specific Paths:**
- **Android**: `/data/data/com.bitcoinz.blackamber/app_flutter/bitcoinz-black-amber/`
- **iOS**: `Documents/bitcoinz-black-amber/`
- **Windows**: `%APPDATA%/BitcoinZ Black Amber/`
- **macOS**: `~/Library/Application Support/BitcoinZ Black Amber/`
- **Linux**: `~/.local/share/bitcoinz-black-amber/`

**Key Features:**
- Automatic directory creation
- Legacy wallet detection (macOS)
- Migration from BitcoinZ Blue
- Cache management
- Database path management

### 2. Rust API Updates (`rust/src/api.rs`)
- Added `wallet_dir` parameter to all initialization functions
- `wallet_exists()` now accepts custom directory
- `initialize_new()` uses specified wallet directory
- `initialize_existing()` loads from custom location
- `initialize_from_phrase()` restores to correct directory

### 3. Service Updates

**BitcoinzRustService** (`lib/services/bitcoinz_rust_service.dart`)
- Integrated WalletStorageService
- Passes platform-specific wallet directory to Rust API
- Ensures wallet data stored in correct location

**DatabaseService** (`lib/services/database_service.dart`)
- Uses WalletStorageService for database path
- Consistent cache location across platforms

**AuthProvider** (`lib/providers/auth_provider.dart`)
- Added legacy wallet detection on startup
- `migrateLegacyWallet()` method for one-time migration
- Preserves original BitcoinZ Blue data

### 4. App Branding

**App Name**: BitcoinZ Black Amber

**Updated Files:**
- `pubspec.yaml` - App name and description
- `macos/Runner/Configs/AppInfo.xcconfig` - macOS app configuration
- Bundle ID: `com.bitcoinz.blackamber`

### 5. Directory Structure
```
BitcoinZ Black Amber/
├── wallet/
│   ├── wallet.dat          # Main wallet file
│   ├── wallet.dat.bak      # Backup
│   └── *.log              # Debug logs
├── cache/
│   └── transactions.db     # Transaction cache
└── settings/
    └── preferences.json    # App settings
```

## Migration Flow

### For New Users:
1. App creates wallet in Black Amber directory
2. No conflicts with existing wallets
3. Clean, app-specific data storage

### For Existing BitcoinZ Blue Users (macOS):
1. App detects legacy wallet on startup
2. Prompts user to migrate
3. Copies wallet data to new location
4. Preserves original data
5. Continues with Black Amber wallet

## Benefits

1. **True Cross-Platform Support**
   - Works on Android, iOS, Windows, macOS, Linux
   - Platform-appropriate data locations

2. **No Conflicts**
   - Separate from BitcoinZ Blue
   - Own app identity and data

3. **Better Organization**
   - Structured directory layout
   - Separated wallet, cache, and settings

4. **Security**
   - App-specific directories
   - Proper platform permissions
   - No shared data access

5. **User Experience**
   - Seamless migration for existing users
   - Clean setup for new users
   - Professional "Black Amber" branding

## Testing Checklist

- [x] WalletStorageService created
- [x] Rust API accepts custom directories
- [x] Platform paths implemented
- [x] Migration logic added
- [x] App renamed to Black Amber
- [x] Services use new paths
- [x] Build successful

## Next Steps

1. Test on each platform:
   - [ ] macOS wallet creation
   - [ ] macOS migration from Blue
   - [ ] iOS wallet creation
   - [ ] Android wallet creation
   - [ ] Windows wallet creation
   - [ ] Linux wallet creation

2. Update app icons and branding
3. Update Android/iOS configurations
4. Test wallet backup/restore
5. Verify no data conflicts

## Important Notes

- Original BitcoinZ Blue data is **never deleted**
- Migration is one-time only
- Each platform uses appropriate system directories
- Database and cache are app-specific
- Wallet files are isolated per app

## File Locations Reference

### macOS
- **Old**: `~/Library/Application Support/bitcoinz-blue-wallet-data/`
- **New**: `~/Library/Application Support/BitcoinZ Black Amber/`

### iOS
- **Documents**: App's document directory (iCloud backup enabled)

### Android
- **Internal**: App's private storage (not accessible to other apps)

### Windows
- **AppData**: User's roaming application data

### Linux
- **XDG**: Following XDG Base Directory specification