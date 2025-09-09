# Bitcoinz black amber 8.0.1 beta

Fast, cross‑platform BitcoinZ wallet built with Flutter and Rust FFI.

- Platforms: Android, iOS, macOS, Windows, Linux, Web
- Rust backend for high‑performance sync and transactions
- Clean UI with enhanced sync feedback and message-aware notifications

## Quick start (developers)

Prerequisites:
- Flutter (stable channel)
- For Android: Java 17, Android SDK/NDK (ndk 27.0.12077973 recommended)
- For iOS/macOS: Xcode + CocoaPods
- For Linux: clang, cmake, ninja, pkg-config, libgtk-3-dev
- For Windows: Visual Studio C++ build tools

Install deps and run:

```bash
flutter pub get
flutter run
```

## Building locally

Android (arm64):
```bash
flutter build apk --release --target-platform=android-arm64
```

iOS (no codesign):
```bash
flutter build ios --release --no-codesign
```

macOS:
```bash
flutter build macos --release
```

Windows:
```bash
flutter build windows --release
```

Linux:
```bash
flutter build linux --release
```

## CI/CD

GitHub Actions workflow builds all platforms and uploads artifacts on push and on demand:
- .github/workflows/cross-platform-build.yml

## Naming
The application label is set to: `Bitcoinz black amber 8.0.1 beta` (AndroidManifest.xml).

## License
MIT
