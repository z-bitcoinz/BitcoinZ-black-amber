import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// Service to manage wallet data storage paths across different platforms
/// Ensures BitcoinZ Black Amber wallet data is stored in appropriate
/// platform-specific directories
class WalletStorageService {
  static const String appName = 'BitcoinZ Black Amber';
  static const String appDirName = 'bitcoinz-black-amber';

  /// Get the base directory for wallet data based on the platform
  static Future<Directory> getWalletDirectory() async {
    Directory baseDir;

    if (Platform.isAndroid) {
      // Android: Use app's support directory for persistent storage
      // Documents directory can be cleared by system, use application support instead
      // Path: /data/data/com.bitcoinz.wallet/files/bitcoinz-black-amber/
      final appSupportDir = await getApplicationSupportDirectory();
      baseDir = Directory(path.join(appSupportDir.path, appDirName));
    } else if (Platform.isIOS) {
      // iOS: Use documents directory (backed up to iCloud by default)
      // Path: ../Documents/bitcoinz-black-amber/
      final docDir = await getApplicationDocumentsDirectory();
      baseDir = Directory(path.join(docDir.path, appDirName));
    } else if (Platform.isWindows) {
      // Windows: Use application support directory
      // Path: C:\Users\{user}\AppData\Roaming\BitcoinZ Black Amber\
      final appSupportDir = await getApplicationSupportDirectory();
      baseDir = Directory(path.join(appSupportDir.path, appDirName));
    } else if (Platform.isMacOS) {
      // macOS: Use application support directory
      // Path: ~/Library/Application Support/BitcoinZ Black Amber/
      final appSupportDir = await getApplicationSupportDirectory();
      baseDir = Directory(path.join(appSupportDir.path, appDirName));
    } else if (Platform.isLinux) {
      // Linux: Use application support directory
      // Path: ~/.local/share/bitcoinz-black-amber/
      final appSupportDir = await getApplicationSupportDirectory();
      baseDir = Directory(path.join(appSupportDir.path, appDirName));
    } else {
      // Fallback to temp directory
      final tempDir = await getTemporaryDirectory();
      baseDir = Directory(path.join(tempDir.path, appDirName));
    }

    // Create directory if it doesn't exist
    if (!await baseDir.exists()) {
      await baseDir.create(recursive: true);
      if (kDebugMode) {
        print('📁 Created wallet directory: ${baseDir.path}');
      }
    }


    // One-time migration for legacy root-level folders on desktop platforms
    if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      try {
        final appSupportDir = await getApplicationSupportDirectory();
        final legacyWallet = Directory(path.join(appSupportDir.path, 'wallet'));
        final legacyCache = Directory(path.join(appSupportDir.path, 'cache'));
        final legacySettings = Directory(path.join(appSupportDir.path, 'settings'));

        Future<void> moveIfNeeded(Directory src, String name) async {
          if (await src.exists()) {
            final dst = Directory(path.join(baseDir.path, name));
            if (!await dst.exists()) {
              if (kDebugMode) print('🚚 Migrating $name from legacy root to ${dst.path}');
              try {
                await src.rename(dst.path);
              } catch (_) {
                // Fallback: copy then delete
                await dst.create(recursive: true);
                await for (final entity in src.list(recursive: false)) {
                  if (entity is File) {
                    final newPath = path.join(dst.path, path.basename(entity.path));
                    await entity.copy(newPath);
                  } else if (entity is Directory) {
                    final newDir = Directory(path.join(dst.path, path.basename(entity.path)));
                    await newDir.create(recursive: true);
                  }
                }
                try { await src.delete(recursive: true); } catch (_) {}
              }
            }
          }
        }

        await moveIfNeeded(legacyWallet, 'wallet');
        await moveIfNeeded(legacyCache, 'cache');
        await moveIfNeeded(legacySettings, 'settings');
      } catch (e) {
        if (kDebugMode) print('⚠️ Legacy folder migration skipped: $e');
      }
    }

    return baseDir;
  }

  /// Get the wallet subdirectory (where wallet.dat is stored)
  static Future<Directory> getWalletDataDirectory() async {
    final baseDir = await getWalletDirectory();
    final walletDir = Directory(path.join(baseDir.path, 'wallet'));

    if (!await walletDir.exists()) {
      await walletDir.create(recursive: true);
    }

    return walletDir;
  }

  /// Get the cache directory for temporary data
  static Future<Directory> getCacheDirectory() async {
    final baseDir = await getWalletDirectory();
    final cacheDir = Directory(path.join(baseDir.path, 'cache'));

    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }

    return cacheDir;
  }

  /// Get the settings directory for app preferences
  static Future<Directory> getSettingsDirectory() async {
    final baseDir = await getWalletDirectory();
    final settingsDir = Directory(path.join(baseDir.path, 'settings'));

    if (!await settingsDir.exists()) {
      await settingsDir.create(recursive: true);
    }

    return settingsDir;
  }

  /// Get the database path for transaction cache
  static Future<String> getDatabasePath() async {
    final cacheDir = await getCacheDirectory();
    return path.join(cacheDir.path, 'transactions.db');
  }

  /// Check if wallet data exists
  static Future<bool> walletExists() async {
    final walletDir = await getWalletDataDirectory();
    final walletFile = File(path.join(walletDir.path, 'wallet.dat'));
    return await walletFile.exists();
  }

  /// Get the path to the wallet.dat file
  static Future<String> getWalletFilePath() async {
    final walletDir = await getWalletDataDirectory();
    return path.join(walletDir.path, 'wallet.dat');
  }

  /// Check for legacy BitcoinZ Blue wallet data (macOS only)
  static Future<bool> hasLegacyWallet() async {
    if (!Platform.isMacOS) return false;

    final homeDir = Platform.environment['HOME'] ?? '';
    if (homeDir.isEmpty) return false;

    final legacyPath = path.join(
      homeDir,
      'Library',
      'Application Support',
      'bitcoinz-blue-wallet-data',
      'wallet.dat'
    );

    return await File(legacyPath).exists();
  }

  /// Get the legacy wallet path (macOS only)
  static Future<String?> getLegacyWalletPath() async {
    if (!Platform.isMacOS) return null;

    final homeDir = Platform.environment['HOME'] ?? '';
    if (homeDir.isEmpty) return null;

    return path.join(
      homeDir,
      'Library',
      'Application Support',
      'bitcoinz-blue-wallet-data'
    );
  }

  /// Migrate wallet from legacy location to new location
  static Future<bool> migrateLegacyWallet() async {
    try {
      if (!Platform.isMacOS) return false;

      final legacyPath = await getLegacyWalletPath();
      if (legacyPath == null) return false;

      final legacyDir = Directory(legacyPath);
      if (!await legacyDir.exists()) return false;

      final newWalletDir = await getWalletDataDirectory();

      // Copy all files from legacy directory to new directory
      await for (final entity in legacyDir.list(recursive: false)) {
        if (entity is File) {
          final fileName = path.basename(entity.path);
          final newPath = path.join(newWalletDir.path, fileName);
          await entity.copy(newPath);

          if (kDebugMode) {
            print('📋 Copied: $fileName to new location');
          }
        }
      }

      if (kDebugMode) {
        print('✅ Successfully migrated wallet from BitcoinZ Blue to Black Amber');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to migrate wallet: $e');
      }
      return false;
    }
  }

  /// Get a human-readable path for display
  static Future<String> getDisplayPath() async {
    final dir = await getWalletDirectory();
    String displayPath = dir.path;

    // Replace home directory with ~ for Unix-like systems
    if (Platform.isMacOS || Platform.isLinux) {
      final homeDir = Platform.environment['HOME'] ?? '';
      if (homeDir.isNotEmpty && displayPath.startsWith(homeDir)) {
        displayPath = displayPath.replaceFirst(homeDir, '~');
      }
    }

    return displayPath;
  }

  /// Clean up cache and temporary files
  static Future<void> cleanupCache() async {
    try {
      final cacheDir = await getCacheDirectory();

      // Delete old cache files (older than 7 days)
      final now = DateTime.now();
      await for (final entity in cacheDir.list()) {
        if (entity is File) {
          final stat = await entity.stat();
          final age = now.difference(stat.modified);
          if (age.inDays > 7) {
            await entity.delete();
            if (kDebugMode) {
              print('🗑️ Deleted old cache file: ${path.basename(entity.path)}');
            }
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Cache cleanup failed: $e');
      }
    }
  }
}