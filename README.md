# BitcoinZ Black Amber - Flutter Application

**Professional mobile wallet for BitcoinZ cryptocurrency - Flutter frontend component**

This Flutter application provides the user interface and platform integration for BitcoinZ Black Amber v0.8.1, the first production-ready mobile wallet for BitcoinZ cryptocurrency.

## 🏗️ Architecture Overview

### Hybrid Flutter + Rust FFI Design
```
┌─────────────────────────────────────────────────────┐
│              Flutter UI Layer                       │
│  ┌─────────────────┐ ┌─────────────────────────────┐│
│  │   Material 3    │ │      State Management       ││
│  │   Interface     │ │      (Provider Pattern)     ││
│  └─────────────────┘ └─────────────────────────────┘│
└─────────────────────┬───────────────────────────────┘
                      │ Flutter Rust Bridge (FFI)
┌─────────────────────┴───────────────────────────────┐
│              Rust Core Library                     │
│           (Native Performance)                     │
└─────────────────────────────────────────────────────┘
```

### Key Components

- **Flutter UI**: Material 3 design with cross-platform support
- **Provider State Management**: Reactive state updates across the app
- **FFI Bridge**: Direct Rust integration for cryptographic operations
- **Secure Storage**: Platform-native secure storage for sensitive data
- **Biometric Auth**: Face ID, Touch ID, and fingerprint integration

## 🚀 Quick Start

### Prerequisites
- Flutter SDK 3.2.0+
- Dart 3.0+
- Platform-specific tools (Xcode for iOS, Android Studio for Android)

### Development Setup
```bash
# Navigate to Flutter app directory
cd flutter_app

# Install dependencies
flutter pub get

# Run on connected device
flutter run

# Build for specific platforms
flutter build apk           # Android APK
flutter build ios          # iOS (requires macOS)
flutter build macos        # macOS desktop
```

### Rust Core Integration
The app requires the Rust core library to be built first:
```bash
# From repository root
./scripts/build_rust_android.sh    # For Android
./scripts/build_rust_ios.sh        # For iOS
./scripts/build_rust_macos.sh      # For macOS
```

## 📱 Platform Support

| Platform | Status | Build Command |
|----------|--------|---------------|
| **Android** | ✅ Production | `flutter build apk` |
| **iOS** | ✅ Production | `flutter build ios` |
| **macOS** | ✅ Production | `flutter build macos` |
| **Windows** | ✅ Production | `flutter build windows` |
| **Linux** | ✅ Production | `flutter build linux` |

## 🎯 Core Features

### 💰 Wallet Operations
- Send and receive BitcoinZ with transparent (t1) and shielded (zs) addresses
- Real-time balance tracking with confirmation status
- Complete transaction history with memo support
- Address generation for enhanced privacy

### 🔒 Security Features
- Biometric authentication (Face ID, Touch ID, Fingerprint)
- PIN protection with auto-lock functionality
- Secure storage using platform-native encryption
- No data collection or tracking

### 👥 Contact Management
- Address book with contact photos
- Quick send to saved contacts
- Secure backup and restore functionality
- Address validation and duplicate detection

### 🎨 User Experience
- Material 3 design system
- Dark and light theme support
- Accessibility compliance
- Responsive design for all screen sizes

## 🛠️ Development

### Project Structure
```
lib/
├── models/              # Data models with JSON serialization
├── providers/           # State management (Provider pattern)
├── screens/             # UI screens and pages
├── services/            # Business logic and external integrations
├── widgets/             # Reusable UI components
└── utils/              # Helper functions and utilities
```

### Key Files
- `lib/providers/wallet_provider.dart` - Core wallet state management
- `lib/services/bitcoinz_rust_service.dart` - Rust FFI integration
- `lib/services/contact_service.dart` - Contact management
- `lib/models/` - Data models for wallet, transactions, contacts
- `pubspec.yaml` - Dependencies and project configuration

### State Management Pattern
The app uses Provider pattern with ChangeNotifier for reactive UI updates:
```dart
// Example provider usage
Consumer<WalletProvider>(
  builder: (context, wallet, child) {
    return Text('Balance: ${wallet.totalBalance}');
  },
)
```

### FFI Integration
Direct Rust function calls for cryptographic operations:
```dart
// Example FFI call
final result = await RustFFIService.instance.getBalance();
```

## 🧪 Testing

### Running Tests
```bash
# Unit and widget tests
flutter test

# Code analysis
flutter analyze

# Test coverage
flutter test --coverage
```

### Test Structure
- Unit tests for business logic and models
- Widget tests for UI components
- Integration tests for FFI bridge functionality

## 🔧 Configuration

### Network Settings
- Default server: `https://lightd.btcz.rocks:9067`
- Customizable lightwalletd servers
- Direct blockchain connection (no intermediary servers)

### Security Configuration
- Biometric authentication setup
- PIN requirements and auto-lock timing
- Secure storage encryption settings

## 📦 Dependencies

### Core Dependencies
- `flutter` - UI framework
- `provider` - State management
- `flutter_rust_bridge` - Rust FFI integration
- `flutter_secure_storage` - Secure data storage
- `local_auth` - Biometric authentication

### Platform Integration
- `mobile_scanner` - QR code scanning
- `share_plus` - Native sharing functionality
- `url_launcher` - External link handling
- `window_manager` - Desktop window management

### UI/UX
- Material 3 design system (built-in Flutter)
- `fl_chart` - Financial charts and analytics
- `image_picker` - Contact photo management

## 🚀 Build and Deployment

### Release Builds
```bash
# Android release
flutter build apk --release
flutter build appbundle --release

# iOS release (requires macOS)
flutter build ios --release

# Desktop releases
flutter build macos --release
flutter build windows --release
flutter build linux --release
```

### Code Signing
- Android: Configure `android/app/build.gradle` with signing config
- iOS: Use Xcode for code signing and provisioning profiles
- macOS: Configure signing certificates for distribution

## 🔍 Debugging

### Common Issues
1. **FFI Library Not Found**: Ensure Rust core is built for target platform
2. **Sync Issues**: Check network connectivity and server status
3. **State Not Updating**: Verify Provider is properly notifying listeners
4. **Build Failures**: Run `flutter clean && flutter pub get`

### Debug Tools
```bash
# Enable Flutter inspector
flutter run --debug

# View device logs
flutter logs

# Performance profiling
flutter run --profile
```

## 🤝 Contributing

### Development Workflow
1. Create feature branch from `main`
2. Make changes following Flutter best practices
3. Test thoroughly on target platforms
4. Submit pull request with clear description

### Code Standards
- Follow Flutter/Dart style guidelines
- Use meaningful variable and function names
- Add comments for complex business logic
- Maintain test coverage for new features

## 📄 License

This Flutter application is part of BitcoinZ Black Amber, released under the MIT License.

---

## 🌟 BitcoinZ Values

- **Decentralization**: Community-driven, no central authority
- **Privacy**: Your financial data belongs to you alone
- **Security**: Military-grade cryptography
- **Accessibility**: Financial freedom for everyone
- **Transparency**: Open source, auditable code

**BitcoinZ: Your Keys, Your Coins, Your Freedom.**
