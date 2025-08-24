# Rust Bridge Serialization Fix - SOLVED

## Problem
The Rust Bridge was panicking with SSE codec serialization errors when calling `initialize_from_phrase`:
```
assertion `left == right` failed
  left: 266
 right: 198
```

Even with `null` for wallet_dir, it failed with:
```
assertion `left == right` failed
  left: 199
 right: 198
```

## Root Cause
The SSE (Server-Sent Events) codec in flutter_rust_bridge v2.11.1 has a serialization issue with the complex parameter structure of `initialize_from_phrase`:
- 5 parameters including `Option<String>`, `u64`, and `bool`
- The codec expects exactly 198 bytes but receives different amounts

## Solution: Simplified API Function

Created a new simplified function that wraps the complex one:

### Rust Implementation (`rust/src/api.rs`)
```rust
/// Initialize from seed phrase (simplified version)
pub fn initialize_from_phrase_simple(
    server_uri: String,
    seed_phrase: String,
) -> String {
    // Use default values internally
    let birthday: u64 = 0;
    let overwrite = true;
    let wallet_dir: Option<String> = None;
    
    initialize_from_phrase(server_uri, seed_phrase, birthday, overwrite, wallet_dir)
}
```

### Dart Usage (`lib/services/bitcoinz_rust_service.dart`)
```dart
// Use simplified function to avoid serialization issues
final result = await rust_api.initializeFromPhraseSimple(
  serverUri: serverUri,
  seedPhrase: seedPhrase,
);
```

## Benefits
1. ✅ **No serialization errors** - Only 2 string parameters
2. ✅ **Same functionality** - Uses sensible defaults internally
3. ✅ **Clean API** - Simpler for common use case
4. ✅ **Backward compatible** - Original function still available

## Technical Details
- **Birthday**: Set to 0 (scan from genesis)
- **Overwrite**: Set to true (replace existing wallet)
- **Wallet Directory**: Set to None (use default location)

## Testing Results
- ✅ Build compiles successfully
- ✅ No serialization panics
- ✅ Wallet restoration works
- ✅ Rust Bridge initializes properly
- ✅ Mempool monitoring functions

## Future Improvements
1. **Investigate flutter_rust_bridge upgrade** - Newer versions may fix the serialization issue
2. **Custom directory support** - Add separate function for custom directories if needed
3. **Parameter optimization** - Test which specific parameter causes the issue

## Files Modified
1. `rust/src/api.rs` - Added `initialize_from_phrase_simple`
2. `lib/src/rust/api.dart` - Generated bindings for new function
3. `lib/services/bitcoinz_rust_service.dart` - Updated to use simplified function

## Status
✅ **FIXED** - Wallet restoration now works reliably using the simplified API function.