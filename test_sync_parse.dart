void main() {
  // Test parsing sync status - EXACT format from logs
  final statusStr = "id: 1, batch: 0/6, blocks: 25499/50000, decryptions: 26000, tx_scan: 0";
  
  print('Testing sync status parsing...');
  print('Input: "$statusStr"');
  
  // Check if it contains the markers
  print('Contains "batch:": ${statusStr.contains('batch:')}');
  print('Contains "blocks:": ${statusStr.contains('blocks:')}');
  
  if (statusStr.contains('batch:') && statusStr.contains('blocks:')) {
    print('✅ Found both markers');
  } else {
    print('❌ Missing markers!');
  }
}