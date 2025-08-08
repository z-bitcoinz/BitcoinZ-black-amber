# BitcoinZ Mobile Wallet - Claude Development Notes

## Overview
This is a Flutter-based BitcoinZ wallet app that replicates the functionality of BitcoinZ Blue wallet. The app uses the BitcoinZ Light CLI as a backend for wallet operations.

## Key Architecture Components

### 1. Complete BitcoinZ Blue Integration
- **CompleteBitcoinzRpcService** (`lib/services/complete_bitcoinz_rpc_service.dart`)
  - Complete replication of BitcoinZ Blue's RPC class with all 40+ methods
  - Dual-timer system: 1-second fast polling + 60-second full refresh
  - Triple change detection: txid, balance, txCount
  - Complete transaction processing with multi-part memo handling
  - Pending transaction tracking with 1-minute timeout

### 2. Native Bridge with CLI Integration
- **NativeBridge** (`lib/services/native_bridge.dart`)
  - Exact interface matching BitcoinZ Blue's Neon.js bindings
  - CLI bridge implementation for all wallet operations
  - Platform-specific library loading support (ready for native module)

### 3. CLI State Manager
- **CliStateManager** (`lib/services/cli_state_manager.dart`)
  - Bridges async CLI operations with synchronous native interface
  - 1-second background updates for all wallet data
  - Cached state for instant synchronous access

### 4. BitcoinZ Light CLI Service
- **BtczCliService** (`lib/services/btcz_cli_service.dart`)
  - Direct interface to bitcoinz-light-cli executable
  - Path: `/Users/name/Documents/code/bitcoinz-mobile-wallet/btcz-light-cli/bitcoinz-light-cli-v1.0.0-macos-arm64/bitcoinz-light-cli-new`
  - Server: `https://lightd.btcz.rocks:9067`

## Important Implementation Details

### Transaction Status
- **0 confirmations** = "Confirming" (unconfirmed, in mempool)
- **1+ confirmations** = "Confirmed"
- All "Pending" terminology has been replaced with "Confirming" throughout the app

### Fast Mempool Monitoring
The app implements BitcoinZ Blue's exact polling mechanism:
1. **1-second interval**: Fast change detection (updateData)
2. **60-second interval**: Full refresh (refresh)
3. **Triple change detection**: Monitors lastTxId, lastBalance, lastTxCount

### Balance Management
Complete TotalBalance class implementation including:
- Transparent balance
- Shielded balance (Sapling)
- Unified address balance
- Pending balances (unconfirmed incoming)
- Pending change (unconfirmed outgoing change)
- Verified/unverified/spendable distinctions

### Transaction Processing
- Multi-part memo handling for long messages
- Transaction grouping by txid+type
- Automatic filtering of confusing self-send transactions
- Proper handling of both transparent and shielded transactions

## Build and Run Commands

### macOS Build
```bash
flutter build macos --debug
```

### Run with Live Reload
```bash
flutter run -d macos
```

### Test CLI Connection
```bash
./bitcoinz-light-cli --server https://lightd.btcz.rocks:9067 balance
```

## Common Issues and Solutions

### Issue: Unconfirmed transactions not showing
**Solution**: Implemented fast 1-second polling with triple change detection

### Issue: Transaction history disappearing
**Solution**: Removed database pagination, implemented local filtering like BitcoinZ Blue

### Issue: Sent transactions not showing immediately
**Solution**: Force refresh after send operations with immediate updateData call

### Issue: Async CLI operations with sync native interface
**Solution**: Created CliStateManager with background updates and cached state

## Future Improvements

### Phase 5: Native Module Integration
When ready to integrate the actual native Rust/C++ library:
1. Build `libzecwalletlitelib.dylib` from BitcoinZ Blue source
2. Place in appropriate platform directories
3. Update NativeBridge to use FFI calls instead of CLI bridge
4. Remove CLI dependencies once native module is stable

### Additional Features to Port
- Price fetching and currency conversion
- Wallet settings persistence
- Encryption support
- QR code generation/scanning
- Address book functionality
- Transaction memo encryption/decryption

## Testing Checklist

- [ ] Wallet creation with new seed phrase
- [ ] Wallet restoration from seed phrase
- [ ] Balance updates (transparent and shielded)
- [ ] Incoming unconfirmed transactions visible
- [ ] Outgoing transactions show as "Confirming" immediately
- [ ] Transaction history persistence
- [ ] Address generation (T and Z addresses)
- [ ] Send transactions with memo
- [ ] 1-second fast polling working
- [ ] 60-second full refresh working

## Development Tips

1. **Always use kDebugMode for logging** - Prevents logs in production
2. **Test with real transactions** - Use testnet or small amounts
3. **Monitor CLI output** - Check console for CLI command execution
4. **Force refresh after user actions** - Ensures immediate UI updates
5. **Handle CLI failures gracefully** - Always provide fallback data

## Contact and Resources

- BitcoinZ Blue Source: https://github.com/z-bitcoinz/BitcoinZ_Blue
- BitcoinZ Light CLI: Part of this repository
- Light Wallet Server: https://lightd.btcz.rocks:9067

## Last Updated
2025-08-08 - Complete BitcoinZ Blue logic integration with CLI bridge