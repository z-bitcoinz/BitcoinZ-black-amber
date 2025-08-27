import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/currency_provider.dart';

class EnhancedAmountInput extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String hintText;
  final Function(String)? onChanged;
  final bool enabled;

  const EnhancedAmountInput({
    super.key,
    required this.controller,
    this.label = 'Amount',
    this.hintText = '0.00000000',
    this.onChanged,
    this.enabled = true,
  });

  @override
  State<EnhancedAmountInput> createState() => _EnhancedAmountInputState();
}

class _EnhancedAmountInputState extends State<EnhancedAmountInput> {
  bool _isInputInFiat = false;
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _toggleInputMode() {
    setState(() {
      _isInputInFiat = !_isInputInFiat;
      
      // Convert current value when switching modes
      final currentText = widget.controller.text.trim();
      if (currentText.isNotEmpty) {
        final currentValue = double.tryParse(currentText);
        if (currentValue != null && currentValue > 0) {
          final currencyProvider = Provider.of<CurrencyProvider>(context, listen: false);
          
          if (_isInputInFiat) {
            // Converting from BTCZ to fiat
            final fiatValue = currencyProvider.convertBtczToFiat(currentValue);
            if (fiatValue != null) {
              widget.controller.text = fiatValue.toStringAsFixed(2);
            }
          } else {
            // Converting from fiat to BTCZ
            final btczValue = currencyProvider.convertFiatToBtcz(currentValue);
            if (btczValue != null) {
              widget.controller.text = btczValue.toStringAsFixed(8);
            }
          }
        }
      }
    });
    
    // Refocus the input field
    _focusNode.requestFocus();
  }

  String _getEquivalentValue(String inputValue) {
    if (inputValue.isEmpty) return '';
    
    final value = double.tryParse(inputValue);
    if (value == null || value <= 0) return '';
    
    final currencyProvider = Provider.of<CurrencyProvider>(context, listen: false);
    
    if (_isInputInFiat) {
      // Input is in fiat, show BTCZ equivalent
      final btczValue = currencyProvider.convertFiatToBtcz(value);
      if (btczValue != null) {
        return '≈ ${btczValue.toStringAsFixed(8)} BTCZ';
      }
    } else {
      // Input is in BTCZ, show fiat equivalent
      final fiatValue = currencyProvider.convertBtczToFiat(value);
      if (fiatValue != null) {
        return '≈ ${currencyProvider.formatFiatAmount(value)}';
      }
    }
    
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CurrencyProvider>(
      builder: (context, currencyProvider, child) {
        final currentCurrency = currencyProvider.selectedCurrency;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Label with toggle button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                GestureDetector(
                  onTap: widget.enabled ? _toggleInputMode : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6B00).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFFF6B00).withOpacity(0.4),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.swap_horiz,
                          size: 14,
                          color: const Color(0xFFFF6B00),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _isInputInFiat
                              ? '${currentCurrency.code} → BTCZ'
                              : 'BTCZ → ${currentCurrency.code}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFFF6B00),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            // Amount input field
            TextField(
              controller: widget.controller,
              focusNode: _focusNode,
              enabled: widget.enabled,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
              ],
              onChanged: (value) {
                setState(() {}); // Trigger rebuild to update equivalent value
                widget.onChanged?.call(value);
              },
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              decoration: InputDecoration(
                hintText: _isInputInFiat ? '0.00' : widget.hintText,
                suffixIcon: Container(
                  margin: const EdgeInsets.all(8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6B00).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFFF6B00).withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    _isInputInFiat ? currentCurrency.code : 'BTCZ',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFFF6B00),
                    ),
                  ),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
            ),
            
            // Equivalent value display
            const SizedBox(height: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: widget.controller.text.isNotEmpty ? 20 : 0,
              child: widget.controller.text.isNotEmpty
                  ? Text(
                      _getEquivalentValue(widget.controller.text),
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        fontWeight: FontWeight.w500,
                      ),
                    )
                  : null,
            ),
          ],
        );
      },
    );
  }
}
