import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/enums/transaction_type.dart';
import '../../../../core/currency/currency_cubit.dart';
import '../../../recurring_transactions/data/recurring_transaction_service.dart';
import '../../../transactions/presentation/bloc/transaction_bloc.dart';
import '../../../transactions/presentation/bloc/transaction_event.dart';
import '../../../wallet/presentation/bloc/wallet_bloc.dart';
import '../../../wallet/presentation/bloc/wallet_event.dart';
import '../../../profile/presentation/pages/management_page.dart';
import '../../../profile/presentation/pages/profile_page.dart';
import '../../../transactions/presentation/pages/add_transaction_page.dart';
import '../../../transactions/presentation/pages/transactions_page.dart';
import '../../../goals/presentation/pages/add_goal_money_page.dart';
import '../widgets/dashboard_page.dart';

class MainShell extends StatefulWidget {
  final VoidCallback onThemeToggle;

  const MainShell({
    super.key,
    required this.onThemeToggle,
  });

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();

    _pages = [
      const DashboardPage(),
      const TransactionsPage(),
      const SizedBox.shrink(),
      const ManagementPage(),
      ProfilePage(
        onThemeToggle: widget.onThemeToggle,
      ),
    ];

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _processRecurringTransactions();
    });
  }

  Future<void> _processRecurringTransactions() async {
    try {
      final created =
      await RecurringTransactionService().processDueTransactions(
        currency: context.read<CurrencyCubit>().state.currency,
      );

      if (!mounted || created == 0) return;

      context.read<TransactionBloc>().add(
        const LoadTransactions(),
      );

      context.read<WalletBloc>().add(
        const LoadWallets(),
      );
    } catch (error) {
      debugPrint(
        'Recurring transaction processing failed: $error',
      );
    }
  }

  // ============================================================
  // NAVIGATION
  // ============================================================

  void _onNavigationTap(int index) {
    // Center + button
    if (index == 2) {
      _showAddTransactionSheet();
      return;
    }

    setState(() {
      _currentIndex = index;
    });
  }

  // ============================================================
  // ADD TRANSACTION SHEET
  // ============================================================

  void _showAddTransactionSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);

        return Container(
          padding: const EdgeInsets.fromLTRB(
            20,
            12,
            20,
            28,
          ),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(30),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: theme.dividerColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),

                const SizedBox(height: 22),

                Text(
                  'Add Transaction',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  'Choose the type of transaction',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.textTheme.bodyMedium?.color
                        ?.withValues(alpha: 0.60),
                  ),
                ),

                const SizedBox(height: 22),

                Row(
                  children: [
                    Expanded(
                      child: _AddOption(
                        icon: Icons.arrow_downward_rounded,
                        title: 'Income',
                        subtitle: 'Money received',
                        color: AppColors.income,
                        onTap: () {
                          Navigator.of(sheetContext).pop();

                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                              const AddTransactionPage(
                                initialType:
                                TransactionType.income,
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(width: 14),

                    Expanded(
                      child: _AddOption(
                        icon: Icons.arrow_upward_rounded,
                        title: 'Expense',
                        subtitle: 'Money spent',
                        color: AppColors.expense,
                        onTap: () {
                          Navigator.of(sheetContext).pop();

                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                              const AddTransactionPage(
                                initialType:
                                TransactionType.expense,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                _AddOption(
                  icon: Icons.savings_rounded,
                  title: 'Add to Goal',
                  subtitle: 'Save money toward a goal',
                  color: AppColors.navPurple,
                  onTap: () {
                    Navigator.of(sheetContext).pop();

                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AddGoalMoneyPage(),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 14),

                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: theme.textTheme.bodyLarge?.color
                            ?.withValues(alpha: 0.65),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),

      extendBody: true,

      bottomNavigationBar:
      _buildBottomNavigationBar(),
    );
  }

  // ============================================================
  // BOTTOM NAVIGATION
  // ============================================================

  Widget _buildBottomNavigationBar() {
    final theme = Theme.of(context);
    final isDark =
        theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.fromLTRB(
        14,
        0,
        14,
        14,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurface
            : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: isDark
              ? AppColors.darkBorder
              : AppColors.lightBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: isDark ? 0.18 : 0.07,
            ),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 72,
          child: Row(
            children: [
              // --------------------------------------------------
              // HOME
              // --------------------------------------------------

              Expanded(
                child: _NavItem(
                  icon: Icons.home_rounded,
                  label: 'Home',
                  selected: _currentIndex == 0,
                  onTap: () =>
                      _onNavigationTap(0),
                ),
              ),

              // --------------------------------------------------
              // TRANSACTIONS
              // --------------------------------------------------

              Expanded(
                child: _NavItem(
                  icon: Icons.receipt_long_rounded,
                  label: 'Transactions',
                  selected: _currentIndex == 1,
                  onTap: () =>
                      _onNavigationTap(1),
                ),
              ),

              // --------------------------------------------------
              // CENTER ADD BUTTON
              // --------------------------------------------------

              SizedBox(
                width: 74,
                child: Center(
                  child: _buildCenterButton(),
                ),
              ),

              // --------------------------------------------------
              // MANAGEMENT
              // --------------------------------------------------

              Expanded(
                child: _NavItem(
                  icon: Icons.tune_rounded,
                  label: 'Manage',
                  selected: _currentIndex == 3,
                  onTap: () =>
                      _onNavigationTap(3),
                ),
              ),

              // --------------------------------------------------
              // PROFILE
              // --------------------------------------------------

              Expanded(
                child: _NavItem(
                  icon: Icons.person_rounded,
                  label: 'Profile',
                  selected: _currentIndex == 4,
                  onTap: () =>
                      _onNavigationTap(4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // CENTER BUTTON
  // ============================================================

  Widget _buildCenterButton() {
    return GestureDetector(
      onTap: () => _onNavigationTap(2),
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          color: AppColors.navPurple,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color:
              AppColors.navPurple.withValues(alpha: 0.32),
              blurRadius: 16,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: const Icon(
          Icons.add_rounded,
          color: Colors.white,
          size: 31,
        ),
      ),
    );
  }
}

// ================================================================
// NAVIGATION ITEM
// ================================================================

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final activeColor =
        AppColors.navActive;

    final inactiveColor =
    theme.brightness == Brightness.dark
        ? AppColors.darkSecondaryText
        : AppColors.lightSecondaryText;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisAlignment:
        MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration:
            const Duration(milliseconds: 180),
            padding:
            const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 5,
            ),
            decoration: BoxDecoration(
              color: selected
                  ? activeColor.withValues(alpha: 0.10)
                  : Colors.transparent,
              borderRadius:
              BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              size: 22,
              color: selected
                  ? activeColor
                  : inactiveColor,
            ),
          ),

          const SizedBox(height: 3),

          Text(
            label,
            maxLines: 1,
            overflow:
            TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9,
              fontWeight: selected
                  ? FontWeight.w800
                  : FontWeight.w600,
              color: selected
                  ? activeColor
                  : inactiveColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// ADD OPTION
// ================================================================

class _AddOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _AddOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius:
        BorderRadius.circular(22),
        child: Container(
          padding:
          const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 20,
          ),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.09),
            borderRadius:
            BorderRadius.circular(22),
            border: Border.all(
              color: color.withValues(alpha: 0.18),
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color:
                  color.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 25,
                ),
              ),

              const SizedBox(height: 12),

              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(
                  color: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.color
                      ?.withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

