import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:bitcoinz_black_amber/services/qr_service.dart';
import 'package:bitcoinz_black_amber/services/sharing_service.dart';
import 'package:bitcoinz_black_amber/widgets/enhanced_amount_input.dart';
import 'package:bitcoinz_black_amber/providers/currency_provider.dart';
import 'package:bitcoinz_black_amber/models/currency_model.dart';

void main() {
  group('Enhanced Payment Request Tests', () {
    
    group('QR Service Tests', () {
      test('should generate valid BitcoinZ payment URI', () {
        const address = 't1PtuKc1ggHVaaqRVUwwuTHHTdAF6A4n9xX';
        const amount = 1.5;
        const memo = 'Test payment';
        
        final uri = QRService.generatePaymentURI(
          address: address,
          amount: amount,
          memo: memo,
        );
        
        expect(uri, startsWith('bitcoinz:$address'));
        expect(uri, contains('amount=1.50000000'));
        expect(uri, contains('message=Test%20payment'));
      });
      
      test('should generate URI with address only when no amount or memo', () {
        const address = 't1PtuKc1ggHVaaqRVUwwuTHHTdAF6A4n9xX';
        
        final uri = QRService.generatePaymentURI(address: address);
        
        expect(uri, equals('bitcoinz:$address'));
      });
      
      test('should handle special characters in memo', () {
        const address = 't1PtuKc1ggHVaaqRVUwwuTHHTdAF6A4n9xX';
        const memo = 'Payment for café & restaurant';
        
        final uri = QRService.generatePaymentURI(
          address: address,
          memo: memo,
        );
        
        expect(uri, contains('message=Payment%20for%20caf%C3%A9%20%26%20restaurant'));
      });
      
      test('should parse BitcoinZ payment URI correctly', () {
        const uri = 'bitcoinz:t1PtuKc1ggHVaaqRVUwwuTHHTdAF6A4n9xX?amount=1.50000000&message=Test%20payment';
        
        final parsed = QRService.parsePaymentURI(uri);
        
        expect(parsed['address'], equals('t1PtuKc1ggHVaaqRVUwwuTHHTdAF6A4n9xX'));
        expect(parsed['amount'], equals('1.50000000'));
        expect(parsed['message'], equals('Test payment'));
      });
      
      test('should validate BitcoinZ addresses correctly', () {
        // Valid transparent addresses
        expect(QRService.isValidBitcoinZAddress('t1PtuKc1ggHVaaqRVUwwuTHHTdAF6A4n9xX'), isTrue);
        expect(QRService.isValidBitcoinZAddress('t3Vz22vK5z2LcKEdg16Yv4FFneEL1zg9ojd'), isTrue);
        
        // Valid shielded addresses (examples)
        expect(QRService.isValidBitcoinZAddress('zcBqWB8VDjVER7uLKb4oHp2v54v2a1VKjn9'), isTrue);
        expect(QRService.isValidBitcoinZAddress('zs1z7rejlpsa98s2rrrfkwmaxu53e4ue0ulcrw0h4x5g8jl04tak0d3mm47vdtahatqrlkngh9sly'), isTrue);
        
        // Invalid addresses
        expect(QRService.isValidBitcoinZAddress(''), isFalse);
        expect(QRService.isValidBitcoinZAddress('invalid'), isFalse);
        expect(QRService.isValidBitcoinZAddress('1BvBMSEYstWetqTFn5Au4m4GFg7xJaNVN2'), isFalse); // Bitcoin address
      });
    });
    
    group('Enhanced Amount Input Widget Tests', () {
      late CurrencyProvider mockCurrencyProvider;
      
      setUp(() {
        mockCurrencyProvider = CurrencyProvider();
      });
      
      testWidgets('should display amount input with currency toggle', (WidgetTester tester) async {
        final controller = TextEditingController();
        
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ChangeNotifierProvider<CurrencyProvider>.value(
                value: mockCurrencyProvider,
                child: EnhancedAmountInput(
                  controller: controller,
                  label: 'Test Amount',
                ),
              ),
            ),
          ),
        );
        
        expect(find.text('Test Amount'), findsOneWidget);
        expect(find.text('BTCZ'), findsOneWidget);
        expect(find.byIcon(Icons.swap_horiz), findsOneWidget);
      });
      
      testWidgets('should toggle between BTCZ and fiat input modes', (WidgetTester tester) async {
        final controller = TextEditingController();
        
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ChangeNotifierProvider<CurrencyProvider>.value(
                value: mockCurrencyProvider,
                child: EnhancedAmountInput(
                  controller: controller,
                  label: 'Test Amount',
                ),
              ),
            ),
          ),
        );
        
        // Initially should show BTCZ
        expect(find.text('BTCZ'), findsOneWidget);
        
        // Tap the toggle button
        await tester.tap(find.byIcon(Icons.swap_horiz));
        await tester.pump();
        
        // Should now show USD (default currency)
        expect(find.text('USD'), findsOneWidget);
      });
    });
    
    group('Sharing Service Tests', () {
      test('should validate sharing service exists', () {
        // Test that the SharingService class exists and has required methods
        expect(SharingService.sharePaymentRequest, isA<Function>());
        expect(SharingService.shareToWhatsApp, isA<Function>());
        expect(SharingService.shareToTelegram, isA<Function>());
        expect(SharingService.shareToSMS, isA<Function>());
      });
    });
    
    group('Integration Tests', () {
      testWidgets('should generate QR code with amount and display equivalent fiat value', (WidgetTester tester) async {
        final controller = TextEditingController();
        
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MultiProvider(
                providers: [
                  ChangeNotifierProvider<CurrencyProvider>(
                    create: (_) => CurrencyProvider(),
                  ),
                ],
                child: Column(
                  children: [
                    EnhancedAmountInput(
                      controller: controller,
                      label: 'Amount',
                    ),
                    Builder(
                      builder: (context) {
                        final amount = double.tryParse(controller.text);
                        final qrData = QRService.generatePaymentURI(
                          address: 't1PtuKc1ggHVaaqRVUwwuTHHTdAF6A4n9xX',
                          amount: amount,
                        );
                        return Text('QR: $qrData');
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        
        // Enter amount
        await tester.enterText(find.byType(TextField), '1.5');
        await tester.pump();
        
        // Should generate QR with amount
        expect(find.textContaining('amount=1.50000000'), findsOneWidget);
      });
    });
  });
}


