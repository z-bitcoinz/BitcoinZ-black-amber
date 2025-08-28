import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

import '../lib/providers/wallet_provider.dart';
import '../lib/providers/currency_provider.dart';
import '../lib/screens/wallet/receive_screen.dart';
import '../lib/widgets/address_selector_widget.dart';
import '../lib/models/address_label.dart';
import '../lib/services/qr_service.dart';

// Generate mocks
@GenerateMocks([WalletProvider, CurrencyProvider])
import 'address_handling_fixes_test.mocks.dart';

void main() {
  group('Address Handling Fixes Tests', () {
    late MockWalletProvider mockWalletProvider;
    late MockCurrencyProvider mockCurrencyProvider;

    setUp(() {
      mockWalletProvider = MockWalletProvider();
      mockCurrencyProvider = MockCurrencyProvider();
      
      // Setup default mock behaviors
      when(mockWalletProvider.isLoading).thenReturn(false);
      when(mockWalletProvider.getAddressesOfType(any)).thenReturn(['test_address_1', 'test_address_2']);
      when(mockWalletProvider.getAddressByType(any)).thenReturn('test_address_1');
      when(mockWalletProvider.getAddressLabels(any)).thenAnswer((_) async => []);
      when(mockCurrencyProvider.selectedCurrency).thenReturn(
        Currency(code: 'USD', name: 'US Dollar', symbol: '\$', rate: 1.0)
      );
    });

    testWidgets('Address Type Bug Fix - QR uses correct address type', (WidgetTester tester) async {
      // Setup transparent addresses
      when(mockWalletProvider.getAddressesOfType(false)).thenReturn(['transparent_addr_1']);
      when(mockWalletProvider.getAddressByType(false)).thenReturn('transparent_addr_1');
      
      // Setup shielded addresses  
      when(mockWalletProvider.getAddressesOfType(true)).thenReturn(['shielded_addr_1']);
      when(mockWalletProvider.getAddressByType(true)).thenReturn('shielded_addr_1');

      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider<WalletProvider>.value(value: mockWalletProvider),
              ChangeNotifierProvider<CurrencyProvider>.value(value: mockCurrencyProvider),
            ],
            child: const ReceiveScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Initially should be transparent (default)
      expect(find.text('Transparent Address'), findsOneWidget);
      
      // Switch to shielded
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      
      expect(find.text('Shielded Address'), findsOneWidget);
      
      // Verify the correct address type is being used
      verify(mockWalletProvider.getAddressByType(true)).called(greaterThan(0));
    });

    testWidgets('Address Selector Widget displays correctly', (WidgetTester tester) async {
      final testAddresses = ['addr1', 'addr2', 'addr3'];
      when(mockWalletProvider.getAddressesOfType(false)).thenReturn(testAddresses);
      
      // Mock address labels
      when(mockWalletProvider.getAddressLabels('addr1')).thenAnswer((_) async => [
        AddressLabel(
          address: 'addr1',
          labelName: 'Main Address',
          category: AddressLabelCategory.income,
          type: AddressLabelType.salary,
          color: '#4CAF50',
          isOwned: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        )
      ]);
      when(mockWalletProvider.getAddressLabels('addr2')).thenAnswer((_) async => []);
      when(mockWalletProvider.getAddressLabels('addr3')).thenAnswer((_) async => []);

      String? selectedAddress;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MultiProvider(
              providers: [
                ChangeNotifierProvider<WalletProvider>.value(value: mockWalletProvider),
              ],
              child: AddressSelectorWidget(
                isShieldedAddress: false,
                selectedAddress: selectedAddress,
                onAddressSelected: (address) {
                  selectedAddress = address;
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should display the address selector
      expect(find.text('Selected Address'), findsOneWidget);
      expect(find.text('Transparent Address 1'), findsOneWidget);
    });

    testWidgets('No Create New Address buttons in receive screen', (WidgetTester tester) async {
      when(mockWalletProvider.getAddressesOfType(any)).thenReturn(['test_address']);

      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider<WalletProvider>.value(value: mockWalletProvider),
              ChangeNotifierProvider<CurrencyProvider>.value(value: mockCurrencyProvider),
            ],
            child: const ReceiveScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should not find any "Create" buttons
      expect(find.textContaining('Create'), findsNothing);
      expect(find.textContaining('New'), findsNothing);
    });

    testWidgets('Address selector shows when no addresses available', (WidgetTester tester) async {
      when(mockWalletProvider.getAddressesOfType(any)).thenReturn([]);

      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider<WalletProvider>.value(value: mockWalletProvider),
              ChangeNotifierProvider<CurrencyProvider>.value(value: mockCurrencyProvider),
            ],
            child: const ReceiveScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should show message about going to address list
      expect(find.textContaining('Go to Address List'), findsOneWidget);
    });

    test('QR Service generates correct URI with proper address', () {
      const testAddress = 'test_shielded_address_123';
      const testAmount = 1.5;
      const testMemo = 'Test payment';

      final uri = QRService.generatePaymentURI(
        address: testAddress,
        amount: testAmount,
        memo: testMemo,
      );

      expect(uri, contains('bitcoinz:$testAddress'));
      expect(uri, contains('amount=1.50000000'));
      expect(uri, contains('message=Test%20payment'));
    });

    test('Address display name generation works correctly', () {
      // Test with label
      final labeledAddress = AddressLabel(
        address: 'test_addr',
        labelName: 'My Savings',
        category: AddressLabelCategory.savings,
        type: AddressLabelType.savings,
        color: '#4CAF50',
        isOwned: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(labeledAddress.labelName, equals('My Savings'));
      
      // Test address formatting
      const longAddress = 'bitcoinz1234567890abcdefghijklmnopqrstuvwxyz';
      const expectedFormatted = 'bitcoinz...rstuvwxyz';
      
      final formatted = '${longAddress.substring(0, 8)}...${longAddress.substring(longAddress.length - 8)}';
      expect(formatted, equals('bitcoinz...rstuvwxyz'));
    });
  });

  group('Address Label Integration Tests', () {
    testWidgets('Address labels display correctly in selector', (WidgetTester tester) async {
      final mockWalletProvider = MockWalletProvider();
      
      when(mockWalletProvider.getAddressesOfType(false)).thenReturn(['labeled_addr', 'unlabeled_addr']);
      
      // Mock labeled address
      when(mockWalletProvider.getAddressLabels('labeled_addr')).thenAnswer((_) async => [
        AddressLabel(
          address: 'labeled_addr',
          labelName: 'Business Account',
          category: AddressLabelCategory.income,
          type: AddressLabelType.business,
          color: '#2196F3',
          isOwned: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        )
      ]);
      
      // Mock unlabeled address
      when(mockWalletProvider.getAddressLabels('unlabeled_addr')).thenAnswer((_) async => []);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<WalletProvider>.value(
              value: mockWalletProvider,
              child: AddressSelectorWidget(
                isShieldedAddress: false,
                selectedAddress: 'labeled_addr',
                onAddressSelected: (address) {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should show the label name
      expect(find.text('Business Account'), findsOneWidget);
    });
  });
}

// Mock Currency class for testing
class Currency {
  final String code;
  final String name;
  final String symbol;
  final double rate;

  Currency({
    required this.code,
    required this.name,
    required this.symbol,
    required this.rate,
  });
}
