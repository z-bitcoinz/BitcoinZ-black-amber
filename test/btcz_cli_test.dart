import 'package:flutter_test/flutter_test.dart';
import '../lib/services/btcz_cli_service.dart';

void main() {
  group('BitcoinZ CLI Service Tests', () {
    late BtczCliService cliService;

    setUp(() {
      cliService = BtczCliService();
    });

    test('CLI should be available and executable', () async {
      final isAvailable = await cliService.isCliAvailable();
      expect(isAvailable, true, reason: 'CLI executable should be available');
    });

    test('CLI should return version information', () async {
      final versionInfo = await cliService.getCliInfo();
      expect(versionInfo['success'], true);
      print('CLI Version Info: ${versionInfo['data']}');
    });
  }, skip: false);
}