# BitcoinZ Wallet - Android Build Guide

## ✅ Build Complete!

The BitcoinZ Wallet Android APK has been successfully built.

### APK Location
- **Debug APK**: `build/app/outputs/flutter-apk/app-debug.apk` (87MB)

### How to Install on Android Phone

#### Method 1: Direct Installation (USB)
1. **Enable Developer Mode on your Android phone:**
   - Go to Settings → About Phone
   - Tap "Build Number" 7 times
   - Developer options will be enabled

2. **Enable USB Debugging:**
   - Go to Settings → Developer Options
   - Enable "USB Debugging"
   - Enable "Install via USB" (if available)

3. **Connect phone to computer via USB**

4. **Install using ADB:**
   ```bash
   flutter install
   # OR
   adb install build/app/outputs/flutter-apk/app-debug.apk
   ```

#### Method 2: Transfer APK
1. **Transfer the APK to your phone:**
   - Email it to yourself
   - Upload to Google Drive/Dropbox
   - Use USB file transfer

2. **On your Android phone:**
   - Go to Settings → Security
   - Enable "Unknown Sources" or "Install unknown apps"
   - Open the APK file from your file manager
   - Tap "Install"

#### Method 3: Run directly from Flutter
```bash
# With phone connected via USB
flutter run

# List available devices
flutter devices
```

### App Features
- **Name**: BitcoinZ Wallet
- **Package**: com.bitcoinz.wallet
- **Min Android Version**: 5.0 (API 21)
- **Permissions**:
  - Internet access
  - Camera (QR scanning)
  - Biometric authentication
  - Vibration feedback

### Building for Production

To build a release APK (smaller, optimized):
```bash
flutter build apk --release
```

To build an App Bundle for Google Play:
```bash
flutter build appbundle --release
```

### Troubleshooting

If you encounter issues:
1. Ensure USB debugging is enabled
2. Check that your phone is detected: `adb devices`
3. If "App not installed" error occurs, uninstall any previous version first
4. For release builds, you'll need to set up signing keys

### Next Steps
1. Test all wallet features on real device
2. Set up proper app icons
3. Configure signing for release builds
4. Consider publishing to Google Play Store

## Build Details
- Build Date: 2025-08-19
- Flutter Version: 3.32.8
- Android NDK: 26.3.11579264
- Supported Architectures: arm64-v8a, armeabi-v7a, x86_64