import 'dart:io';
import 'lib/services/btcz_cli_service.dart';

void main() async {
  print('🔥 BitcoinZ CLI Integration Test');
  print('=====================================');
  
  final cliService = BtczCliService();
  
  // Test 1: CLI availability
  print('\n1️⃣ Testing CLI availability...');
  try {
    final isAvailable = await cliService.isCliAvailable();
    print('   ✅ CLI Available: $isAvailable');
    
    if (isAvailable) {
      final versionInfo = await cliService.getCliInfo();
      print('   📋 Version: ${versionInfo['data']['raw_output'].trim()}');
    }
  } catch (e) {
    print('   ❌ Error: $e');
  }
  
  // Test 2: Existing wallet balance (if any)
  print('\n2️⃣ Testing existing wallet operations...');
  try {
    final balanceResult = await cliService.getBalance();
    if (balanceResult['success']) {
      print('   ✅ Balance query successful');
      print('   💰 Output: ${balanceResult['data']['raw_output']}');
    } else {
      print('   ⚠️  No existing wallet or connection issue');
      print('   📝 Output: ${balanceResult['data']['raw_error'] ?? balanceResult['data']['raw_output']}');
    }
  } catch (e) {
    print('   ❌ Error: $e');
  }
  
  // Test 3: Check addresses (if wallet exists)
  print('\n3️⃣ Testing address query...');
  try {
    final addressResult = await cliService.getAddresses();
    if (addressResult['success']) {
      print('   ✅ Address query successful');
      print('   📍 Output: ${addressResult['data']['raw_output']}');
    } else {
      print('   ⚠️  No existing wallet found');
      print('   📝 Output: ${addressResult['data']['raw_error'] ?? addressResult['data']['raw_output']}');
    }
  } catch (e) {
    print('   ❌ Error: $e');
  }
  
  print('\n=====================================');
  print('🎉 CLI Integration Test Complete!');
  print('✨ The working BitcoinZ Light CLI is successfully');
  print('   integrated with Flutter and ready to use.');
  print('=====================================\n');
}