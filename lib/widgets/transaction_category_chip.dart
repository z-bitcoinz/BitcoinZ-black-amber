import 'package:flutter/material.dart';
import '../models/transaction_category.dart';

/// Small chip widget to display transaction category
class TransactionCategoryChip extends StatelessWidget {
  final TransactionCategory category;
  final bool showIcon;
  final double? fontSize;

  const TransactionCategoryChip({
    super.key,
    required this.category,
    this.showIcon = true,
    this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: category.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: category.color.withOpacity(0.3),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon) ...[
            Icon(
              category.icon,
              size: fontSize != null ? fontSize! + 2 : 12,
              color: category.color,
            ),
            const SizedBox(width: 4),
          ],
          Text(
            category.name,
            style: TextStyle(
              color: category.color,
              fontSize: fontSize ?? 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Future builder widget for async category loading
class AsyncTransactionCategoryChip extends StatelessWidget {
  final Future<TransactionCategory> categoryFuture;
  final bool showIcon;
  final double? fontSize;

  const AsyncTransactionCategoryChip({
    super.key,
    required this.categoryFuture,
    this.showIcon = true,
    this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TransactionCategory>(
      future: categoryFuture,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return TransactionCategoryChip(
            category: snapshot.data!,
            showIcon: showIcon,
            fontSize: fontSize,
          );
        }
        
        // Loading state
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showIcon) ...[
                SizedBox(
                  width: fontSize != null ? fontSize! + 2 : 12,
                  height: fontSize != null ? fontSize! + 2 : 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 1,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(width: 4),
              ],
              Text(
                '...',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: fontSize ?? 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
