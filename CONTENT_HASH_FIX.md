# Content Hash Mismatch - Resolution Process

## Problem
After modifying Rust code, the app shows:
```
Content hash on Dart side (-598940969) is different from Rust side (-380413977)
```

This indicates the Rust library and Dart bindings are out of sync.

## Root Cause
When Rust API functions are added or modified, the compiled library and Dart bindings must be regenerated and synchronized.

## Complete Fix Process

### 1. Clean Everything
```bash
# Clean Flutter build artifacts
flutter clean

# Clean Rust build artifacts
cd rust
cargo clean
cd ..
```

### 2. Rebuild Rust Library
```bash
cd rust
cargo build --release
cd ..
```

This creates:
- `rust/target/release/libbitcoinz_wallet_rust.dylib` (macOS)
- `rust/target/release/libbitcoinz_wallet_rust.a` (static library)

### 3. Copy Library to Runner
```bash
cp rust/target/release/libbitcoinz_wallet_rust.dylib \
   macos/Runner/librust_lib_bitcoinz_black_amber.dylib
```

**Important**: The library must be renamed to match what Flutter expects.

### 4. Regenerate Bindings
```bash
flutter_rust_bridge_codegen generate
```

This updates:
- `lib/src/rust/api.dart` - Dart API bindings
- `lib/src/rust/frb_generated.dart` - Generated bridge code

### 5. Rebuild Flutter App
```bash
flutter pub get
flutter build macos --debug
```

## Verification

After following these steps:
1. ✅ No content hash mismatch errors
2. ✅ Rust Bridge initializes successfully
3. ✅ New functions (like `initializeNewWithInfo`) are available
4. ✅ Birthday block is properly captured

## When to Use This Process

Run this complete process when:
- Adding new Rust API functions
- Modifying existing Rust function signatures
- Changing parameter types or return types
- After pulling changes that modify Rust code
- When seeing content hash mismatch errors

## Quick Command Sequence

```bash
# All in one (copy and paste)
flutter clean && \
cd rust && cargo clean && cargo build --release && cd .. && \
cp rust/target/release/libbitcoinz_wallet_rust.dylib \
   macos/Runner/librust_lib_bitcoinz_black_amber.dylib && \
flutter_rust_bridge_codegen generate && \
flutter pub get && \
flutter build macos --debug
```

## Platform-Specific Notes

### macOS
- Library extension: `.dylib`
- Location: `macos/Runner/`

### Linux
- Library extension: `.so`
- Location: `linux/`

### Windows
- Library extension: `.dll`
- Location: `windows/`

## Troubleshooting

### Still Getting Hash Mismatch?
1. Ensure you're not running the app while rebuilding
2. Try `flutter clean` again
3. Delete `.dart_tool/` directory manually
4. Restart your IDE/terminal

### Library Not Found?
1. Check the library name matches exactly
2. Verify the library is in the correct directory
3. Check file permissions (`chmod +r` if needed)

## Status
✅ **RESOLVED** - Content hash mismatch fixed, app builds and runs successfully with birthday block support.