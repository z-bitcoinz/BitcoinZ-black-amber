import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import '../../models/currency_model.dart';
import '../../providers/currency_provider.dart';

class CurrencySettingsScreen extends StatefulWidget {
  const CurrencySettingsScreen({super.key});

  @override
  State<CurrencySettingsScreen> createState() => _CurrencySettingsScreenState();
}

class _CurrencySettingsScreenState extends State<CurrencySettingsScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Currency> _filteredCurrencies = SupportedCurrencies.currencies;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterCurrencies);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterCurrencies() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredCurrencies = SupportedCurrencies.currencies;
      } else {
        _filteredCurrencies = SupportedCurrencies.currencies.where((currency) {
          return currency.code.toLowerCase().contains(query) ||
                 currency.name.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: AppBar(
              backgroundColor: const Color(0xFF1A1A1A).withOpacity(0.8),
              elevation: 0,
              toolbarHeight: 60,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: const Text(
                'Fiat Currency',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              flexibleSpace: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF1F1F1F).withOpacity(0.8),
                      const Color(0xFF151515).withOpacity(0.6),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.white.withOpacity(0.05),
                      width: 1,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: Consumer<CurrencyProvider>(
        builder: (context, currencyProvider, child) {
          return Column(
            children: [
              const SizedBox(height: 60), // Space for app bar
              
              // Search bar
              Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF2A2A2A).withOpacity(0.6),
                        const Color(0xFF1F1F1F).withOpacity(0.4),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.08),
                      width: 1,
                    ),
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search currency...',
                      hintStyle: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: Colors.white.withOpacity(0.4),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
              ),
              
              // Currency list
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 20),
                  itemCount: _filteredCurrencies.length,
                  itemBuilder: (context, index) {
                    final currency = _filteredCurrencies[index];
                    final isSelected = currency == currencyProvider.selectedCurrency;
                    
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: isSelected 
                              ? LinearGradient(
                                  colors: [
                                    Theme.of(context).colorScheme.primary.withOpacity(0.2),
                                    Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : LinearGradient(
                                  colors: [
                                    const Color(0xFF2A2A2A).withOpacity(0.3),
                                    const Color(0xFF1F1F1F).withOpacity(0.2),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected 
                                ? Theme.of(context).colorScheme.primary.withOpacity(0.4)
                                : Colors.white.withOpacity(0.05),
                            width: 1,
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () async {
                              await currencyProvider.setSelectedCurrency(currency);
                              // Fetch latest prices for the new currency
                              await currencyProvider.fetchPrices(forceRefresh: true);
                              if (mounted) {
                                Navigator.of(context).pop();
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  // Flag
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.05),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Center(
                                      child: Text(
                                        currency.flag,
                                        style: const TextStyle(fontSize: 24),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  
                                  // Currency info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          currency.name,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 15,
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            Text(
                                              currency.code,
                                              style: TextStyle(
                                                color: isSelected 
                                                    ? Theme.of(context).colorScheme.primary
                                                    : Colors.white.withOpacity(0.6),
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              currency.symbol,
                                              style: TextStyle(
                                                color: Colors.white.withOpacity(0.4),
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  
                                  // Selected indicator
                                  if (isSelected)
                                    Icon(
                                      Icons.check_circle,
                                      color: Theme.of(context).colorScheme.primary,
                                      size: 24,
                                    ),
                                  
                                  // Price indicator
                                  if (currencyProvider.priceData?.getPrice(currency.code) != null)
                                    Container(
                                      margin: const EdgeInsets.only(left: 8),
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 6,
                                            height: 6,
                                            decoration: const BoxDecoration(
                                              color: Colors.green,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          const Text(
                                            'Live',
                                            style: TextStyle(
                                              color: Colors.green,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}