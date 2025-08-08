import 'lib/services/cli_wallet_detector.dart';

void main() async {
  print('🧪 Testing CLI wallet detection...');
  
  final detector = CliWalletDetector();
  final result = await detector.detectExistingWallet();
  
  print('Detection result: $result');
  
  if (result != null) {
    print('Wallet found: ${result.isFound}');
    print('Accessible: ${result.isAccessible}');
    print('Error: ${result.error}');
    
    if (result.isFound) {
      final summary = detector.extractWalletSummary(result);
      print('Summary: $summary');
    }
  }
}