import 'package:flutter_test/flutter_test.dart';
import 'dart:io';
import '../lib/services/btcz_cli_service.dart';

void main() {
  group('BitcoinZ CLI Wallet Tests', () {
    late BtczCliService cliService;
    late String testDataDir;
    
    // Use the known working seed phrase from our previous tests
    const testSeedPhrase = 'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon art';

    setUp(() async {
      cliService = BtczCliService();
      
      // Create temporary directory for test wallet
      final tempDir = await Directory.systemTemp.createTemp('btcz_test_wallet');
      testDataDir = tempDir.path;
      print('🔥 Using test data directory: $testDataDir');
    });

    tearDown(() async {
      // Clean up test directory
      final dir = Directory(testDataDir);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        print('🧹 Cleaned up test directory: $testDataDir');
      }
    });

    test('Should be able to initialize wallet with seed phrase and check balance', () async {
      print('🔥 Testing wallet initialization with working seed phrase...');
      
      // Initialize wallet in temporary directory (this creates the wallet with seed)
      final initResult = await cliService.initWallet(
        testSeedPhrase, 
        birthday: 100000, // Start from a more recent block for faster sync
        dataDir: testDataDir
      );
      
      print('Init Result: $initResult');
      
      // The init command might take time as it syncs, so we'll just check if it starts successfully
      expect(initResult['success'], true, reason: 'Wallet initialization should start successfully');
      
      // Try to get balance (even if 0, it should work)
      print('🔥 Testing balance query...');
      final balanceResult = await cliService.getBalance(dataDir: testDataDir);
      print('Balance Result: $balanceResult');
      
      // We expect this to work even if balance is 0
      expect(balanceResult['success'], true, reason: 'Should be able to query balance');
      
    }, timeout: Timeout(Duration(minutes: 3))); // Allow more time for blockchain sync
    
  }, skip: false);
}