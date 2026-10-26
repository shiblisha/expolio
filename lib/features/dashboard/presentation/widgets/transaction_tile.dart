import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../shared/widgets/currency_text.dart';

class TransactionData {
  final String title;
  final String subtitle;
  final double amount;
  final bool isIncome;
  final bool isTransfer;
  final IconData icon;
  final String date;

  const TransactionData({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.isIncome,
    this.isTransfer = false,
    required this.icon,
    required this.date,
  });
}

class TransactionTile extends StatelessWidget {
  final TransactionData transaction;

  const TransactionTile({
    super.key,
    required this.transaction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final accentColor = transaction.isTransfer
        ? AppColors.primary
        : transaction.isIncome
        ? AppColors.income
        : AppColors.expense;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? AppColors.darkSurface
            : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          // ----------------------------------------------------------
          // ICON
          // ----------------------------------------------------------

          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              transaction.icon,
              color: accentColor,
              size: 21,
            ),
          ),

          const SizedBox(width: 12),

          // ----------------------------------------------------------
          // DETAILS
          // ----------------------------------------------------------

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  transaction.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.textTheme.bodySmall?.color
                        ?.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          // ----------------------------------------------------------
          // AMOUNT + DATE
          // ----------------------------------------------------------

          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    transaction.isTransfer
                        ? '↔ '
                        : transaction.isIncome
                        ? '+ '
                        : '- ',
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),

                  CurrencyText(
                    transaction.amount,
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 4),

              Text(
                transaction.date,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 10,
                  color: theme.textTheme.bodySmall?.color
                      ?.withValues(alpha: 0.45),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}