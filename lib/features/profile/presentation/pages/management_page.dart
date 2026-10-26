import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../backup_restore/presentation/pages/backup_restore_page.dart';
import '../../../bills/presentation/pages/bills_page.dart';
import '../../../budget/presentation/pages/budget_page.dart';
import '../../../categories/presentation/page/categories_page.dart';
import '../../../financial_insights/presentation/pages/financial_insights_page.dart';
import '../../../goals/presentation/pages/goals_page.dart';
import '../../../recurring_transactions/presentation/pages/recurring_transactions_page.dart';
import '../../../wallet/presentation/pages/wallet_page.dart';

class ManagementPage extends StatelessWidget {
  const ManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Manage',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
        children: [
          Text(
            'Manage your money',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Keep wallets, budgets, bills, categories and goals organized in one place.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.58),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 22),

          _buildSectionTitle(
            context,
            'Money Management',
            Icons.account_balance_wallet_outlined,
          ),
          const SizedBox(height: 12),

          _ManagementTile(
            icon: Icons.account_balance_wallet_rounded,
            title: 'Wallets',
            subtitle: 'Manage cash, bank, UPI, cards and savings',
            accentColor: AppColors.primary,
            onTap: () => _open(context, const WalletPage()),
          ),
          const SizedBox(height: 12),

          _ManagementTile(
            icon: Icons.account_balance_rounded,
            title: 'Budgets',
            subtitle: 'Set monthly spending limits and track progress',
            accentColor: AppColors.navActive,
            onTap: () => _open(context, const BudgetPage()),
          ),
          const SizedBox(height: 12),
          _ManagementTile(
            icon: Icons.insights_rounded,
            title: 'Financial Insights',
            subtitle: 'See your spending patterns and personalized financial insights',
            accentColor: AppColors.navPurple,
            onTap: () => _open(context, const FinancialInsightsPage()),
          ),
          const SizedBox(height: 12),
          _ManagementTile(
            icon: Icons.receipt_long_rounded,
            title: 'Bills',
            subtitle: 'Track upcoming, overdue and paid bills',
            accentColor: AppColors.expense,
            onTap: () => _open(context, const BillsPage()),
          ),
          const SizedBox(height: 12),

          _ManagementTile(
            icon: Icons.category_rounded,
            title: 'Categories',
            subtitle: 'Organize your income and expense categories',
            accentColor: const Color(0xFFFF8A3D),
            onTap: () => _open(context, const CategoriesPage()),
          ),
          const SizedBox(height: 12),

          // NEW: Recurring Transactions
          _ManagementTile(
            icon: Icons.autorenew_rounded,
            title: 'Recurring Transactions',
            subtitle: 'Manage automatic income and expenses',
            accentColor: AppColors.navPurple,
            onTap: () => _open(context, const RecurringTransactionsPage()),
          ),

          const SizedBox(height: 24),
          _ManagementTile(
            icon: Icons.backup_rounded,
            title: 'Backup & Restore',
            subtitle: 'Protect your MoneyFlow data and restore it anytime',
            accentColor: AppColors.primary,
            onTap: () => _open(
              context,
              const BackupRestorePage(),
            ),
          ),
          const SizedBox(height: 12),

          _buildSectionTitle(context, 'Planning', Icons.flag_outlined),
          const SizedBox(height: 12),

          _SavingsGoalsTile(onTap: () => _open(context, const GoalsPage())),

          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.navPurple.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.tune_rounded,
                    color: AppColors.navPurple,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Everything in one place',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Use Manage whenever you need to update your financial setup.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.textTheme.bodySmall?.color?.withValues(
                            alpha: 0.55,
                          ),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title, IconData icon) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 19, color: AppColors.primary),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  void _open(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }
}

class _ManagementTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accentColor;
  final VoidCallback onTap;

  const _ManagementTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: accentColor, size: 25),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color?.withValues(
                          alpha: 0.55,
                        ),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.textTheme.bodyMedium?.color?.withValues(
                  alpha: 0.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SavingsGoalsTile extends StatelessWidget {
  final VoidCallback onTap;

  const _SavingsGoalsTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    const accent = AppColors.navPurple;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                accent.withValues(alpha: isDark ? 0.24 : 0.12),
                AppColors.primary.withValues(alpha: isDark ? 0.16 : 0.07),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: accent.withValues(alpha: 0.18)),
          ),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.flag_rounded, color: accent, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Savings Goals',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Create goals, add money and track your saving progress',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color?.withValues(
                          alpha: 0.58,
                        ),
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Open Goals',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: accent,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          size: 16,
                          color: accent,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
