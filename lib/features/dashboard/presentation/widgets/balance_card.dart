import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../shared/widgets/currency_text.dart';

class BalanceCard extends StatelessWidget {
  final double balance;
  final double income;
  final double expense;

  const BalanceCard({
    super.key,
    required this.balance,
    required this.income,
    required this.expense,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            AppColors.primaryDark,
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 25,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ----------------------------------------------------------
          // HEADER
          // ----------------------------------------------------------

          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Total Balance',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              const Spacer(),

            //   Container(
            //     width: 36,
            //     height: 36,
            //     decoration: BoxDecoration(
            //       color: Colors.white.withValues(alpha: 0.12),
            //       shape: BoxShape.circle,
            //     ),
            //     child: const Icon(
            //       Icons.more_horiz_rounded,
            //       color: Colors.white,
            //     ),
            //   ),
            ],
          ),

          const SizedBox(height: 18),

          // ----------------------------------------------------------
          // TOTAL BALANCE
          // ----------------------------------------------------------

          CurrencyText(
            balance,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
            ),
          ),

          const SizedBox(height: 22),

          // ----------------------------------------------------------
          // INCOME / EXPENSE
          // ----------------------------------------------------------

          Row(
            children: [
              Expanded(
                child: _AmountItem(
                  icon: Icons.arrow_downward_rounded,
                  title: 'Income',
                  amount: income,
                ),
              ),

              Expanded(
                child: _AmountItem(
                  icon: Icons.arrow_upward_rounded,
                  title: 'Expense',
                  amount: expense,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ====================================================================
// AMOUNT ITEM
// ====================================================================

class _AmountItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final double amount;

  const _AmountItem({
    required this.icon,
    required this.title,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 17,
          ),
        ),

        const SizedBox(width: 9),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.70),
                  fontSize: 12,
                ),
              ),

              const SizedBox(height: 2),

              CurrencyText(
                amount,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}