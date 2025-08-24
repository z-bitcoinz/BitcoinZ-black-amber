# Rust Bridge Serialization Workaround

## Issue
The Rust Bridge panics with a serialization error when using custom wallet directories:
```
assertion `left == right` failed
  left: 266
 right: 198
```

This occurs specifically during `initialize_from_phrase` calls when passing a custom wallet directory path.

## Root Cause
The SSE (Server-Sent Events) codec in the Flutter Rust Bridge has issues serializing `Option<String>` parameters with certain path strings, particularly:
- Paths containing spaces (e.g., "Application Support")
- Paths of specific lengths that trigger the serialization mismatch

## Workaround Implementation

### Fallback Strategy
The `bitcoinz_rust_service.dart` now implements a fallback mechanism:

1. **First attempt**: Try to use the custom Black Amber wallet directory
2. **On failure**: Automatically fallback to the default wallet directory
3. **Log the issue**: For debugging purposes while maintaining functionality

### Code Changes

```dart
// For each initialization method (new, existing, from phrase):
try {
  // Try with custom directory first
  if (walletDirPath != null) {
    result = await rust_api.initializeFromPhrase(
      serverUri: serverUri,
      seedPhrase: seedPhrase,
      walletDir: walletDirPath,
    );
  }
} catch (e) {
  // Fallback to default directory
  print('⚠️ Custom directory failed, using default');
  result = await rust_api.initializeFromPhrase(
    serverUri: serverUri,
    seedPhrase: seedPhrase,
    walletDir: null, // Use default
  );
}
```

## Impact

### What Works
- ✅ Wallet creation and restoration
- ✅ Rust Bridge initialization
- ✅ Mempool monitoring (1-second polling)
- ✅ Balance and transaction updates
- ✅ All wallet operations

### Limitations
- ⚠️ Wallet data may be stored in default location instead of Black Amber directory
- ⚠️ On macOS: `~/Library/Application Support/Zecwallet Lightclient` (default) instead of `~/Library/Application Support/BitcoinZ Black Amber`

## Future Fix

### Proper Solution Options
1. **Fix Rust FFI Bridge**: Update the SSE codec to handle longer path strings
2. **Path Encoding**: Encode paths before passing through FFI (e.g., base64)
3. **Use Relative Paths**: Pass relative paths instead of absolute
4. **Environment Variable**: Set wallet directory via environment variable instead of parameter

### Investigation Steps
1. Test with paths of different lengths to identify the exact trigger
2. Check if escaping spaces helps
3. Review flutter_rust_bridge SSE codec implementation
4. Consider updating to newer version of flutter_rust_bridge

## Testing Checklist
- [x] Wallet restoration works with fallback
- [x] Error is logged but doesn't crash app
- [x] Rust Bridge initializes successfully
- [x] Mempool monitoring functions properly
- [x] Balance and transactions update correctly

## Status
**WORKAROUND ACTIVE** - The app functions correctly but may use default wallet directory instead of Black Amber directory in some cases.

## Related Files
- `lib/services/bitcoinz_rust_service.dart` - Contains the fallback logic
- `rust/src/api.rs` - Rust API that receives the wallet_dir parameter
- `lib/services/wallet_storage_service.dart` - Defines Black Amber directory paths