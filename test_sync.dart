void main() {
  // Test parsing sync status
  final statusStr = "id: 1, batch: 0/7, blocks: 37499/50000, decryptions: 38000, tx_scan: 0";
  
  print('Testing sync status parsing...');
  print('Input: "$statusStr"');
  
  if (statusStr.contains('batch:') && statusStr.contains('blocks:')) {
    print('Found batch and blocks markers');
    
    final parts = statusStr.split(',').map((s) => s.trim()).toList();
    
    int? batchNum, batchTotal, syncedBlocks, totalBlocks;
    
    for (final part in parts) {
      print('Checking part: "$part"');
      
      if (part.contains('batch:')) {
        final batchMatch = RegExp(r'batch:\s*(\d+)/(\d+)').firstMatch(part);
        if (batchMatch != null) {
          batchNum = int.tryParse(batchMatch.group(1)!) ?? 0;
          batchTotal = int.tryParse(batchMatch.group(2)!) ?? 0;
          if (batchTotal > 0) batchNum = batchNum + 1;
          print('  Found batch: $batchNum/$batchTotal');
        }
      }
      
      if (part.contains('blocks:')) {
        final blockMatch = RegExp(r'blocks:\s*(\d+)/(\d+)').firstMatch(part);
        if (blockMatch != null) {
          syncedBlocks = int.tryParse(blockMatch.group(1)!) ?? 0;
          totalBlocks = int.tryParse(blockMatch.group(2)!) ?? 0;
          print('  Found blocks: $syncedBlocks/$totalBlocks');
        }
      }
    }
    
    final inProgress = (batchTotal != null && batchTotal > 0 && batchNum != null && batchNum <= batchTotal) || 
                      (totalBlocks != null && totalBlocks > 0 && syncedBlocks != null && syncedBlocks < totalBlocks);
    
    print('\nParsed results:');
    print('  in_progress: $inProgress');
    print('  batch_num: $batchNum');
    print('  batch_total: $batchTotal');
    print('  synced_blocks: $syncedBlocks');
    print('  total_blocks: $totalBlocks');
  } else {
    print('ERROR: No batch/blocks markers found!');
  }
}