import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/enums/transaction_type.dart';
import '../../../../shared/widgets/currency_text.dart';
import '../../../transactions/presentation/pages/transactions_page.dart';
import '../../../wallet/presentation/bloc/wallet_bloc.dart';
import '../../../wallet/domain/entities/wallet_entity.dart';
import '../../../wallet/presentation/bloc/wallet_state.dart';
import '../../../analytics/presentation/pages/analytics_page.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';
import '../../../transactions/presentation/bloc/transaction_bloc.dart';
import '../../../transactions/presentation/bloc/transaction_state.dart';
import '../widgets/balance_card.dart';
import '../widgets/section_header.dart';
import '../widgets/transaction_tile.dart';
import '../../../budget/domain/entities/budget_entity.dart';
import '../../../budget/presentation/bloc/budget_bloc.dart';
import '../../../budget/presentation/bloc/budget_state.dart';
import '../../../budget/presentation/pages/budget_page.dart';
import '../../../goals/presentation/widgets/savings_goals_dashboard_card.dart';

import 'package:firebase_auth/firebase_auth.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WalletBloc, WalletState>(
      builder: (context, walletState) {
        return BlocBuilder<TransactionBloc, TransactionState>(
          builder: (context, state) {
            final transactions = state.transactions;

            // ---------------------------------------------------------
            // CALCULATE TOTAL INCOME
            // ---------------------------------------------------------

            final income = transactions
                .where(
                  (transaction) => transaction.type == TransactionType.income,
                )
                .fold<double>(
                  0,
                  (total, transaction) => total + transaction.amount,
                );

            // ---------------------------------------------------------
            // CALCULATE TOTAL EXPENSE
            // ---------------------------------------------------------

            final expense = transactions
                .where(
                  (transaction) => transaction.type == TransactionType.expense,
                )
                .fold<double>(
                  0,
                  (total, transaction) => total + transaction.amount,
                );

            // ---------------------------------------------------------
            // CALCULATE COMBINED WALLET BALANCE
            // ---------------------------------------------------------

            // The dashboard balance is based on all wallet initial
            // balances plus income/expense/transfer transactions.
            // When no wallet exists yet, keep the previous
            // income - expense calculation as a fallback.
            final walletBalances = _calculateWalletBalances(
              walletState.wallets,
              transactions,
            );

            final combinedWalletBalance = walletBalances.values.fold<double>(
              0,
              (total, value) => total + value,
            );

            final balance = walletState.wallets.isEmpty
                ? income - expense
                : combinedWalletBalance;

            // ---------------------------------------------------------
            // GET RECENT TRANSACTIONS
            // ---------------------------------------------------------

            final recentTransactions = transactions.take(5).toList();

            return Scaffold(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,

              body: SafeArea(
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),

                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),

                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          // -------------------------------------------------
                          // HEADER
                          // -------------------------------------------------

                          _buildHeader(context),

                          const SizedBox(height: 22),

                          // -------------------------------------------------
                          // BALANCE CARD
                          // -------------------------------------------------
                          BalanceCard(
                            balance: balance,
                            income: income,
                            expense: expense,
                          ),

                          const SizedBox(height: 18),

                          _buildBudgetAlerts(context, transactions),

                          // -------------------------------------------------
                          // SAVINGS GOALS
                          // -------------------------------------------------
                          const SavingsGoalsDashboardCard(),

                          const SizedBox(height: 30),

                          // -------------------------------------------------
                          // TRANSACTIONS HISTORY
                          // -------------------------------------------------
                          SectionHeader(
                            title: 'Transactions History',
                            actionText: 'See All',
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const TransactionsPage(),
                                ),
                              );
                            },
                          ),

                          const SizedBox(height: 12),

                          // -------------------------------------------------
                          // TRANSACTION LIST
                          // -------------------------------------------------
                          if (recentTransactions.isEmpty)
                            _buildEmptyTransactions(context)
                          else
                            ...recentTransactions.map((transaction) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: TransactionTile(
                                  transaction: _convertTransaction(transaction),
                                ),
                              );
                            }),

                          const SizedBox(height: 10),

                          // -------------------------------------------------
                          // SPENDING OVERVIEW
                          // -------------------------------------------------
                          _buildSpendingSummary(
                            context,
                            income: income,
                            expense: expense,
                            balance: balance,
                          ),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ==============================================================
  // WALLET BALANCE CALCULATION
  // ==============================================================

  Map<String, double> _calculateWalletBalances(
    List<WalletEntity> wallets,
    List<TransactionEntity> transactions,
  ) {
    final balances = <String, double>{};

    for (final wallet in wallets) {
      balances[wallet.id] = wallet.initialBalance;
    }

    for (final transaction in transactions) {
      switch (transaction.type) {
        case TransactionType.income:
          final walletId = transaction.walletId;

          if (walletId != null &&
              walletId.isNotEmpty &&
              balances.containsKey(walletId)) {
            balances[walletId] = (balances[walletId] ?? 0) + transaction.amount;
          }
          break;

        case TransactionType.expense:
          final walletId = transaction.walletId;

          if (walletId != null &&
              walletId.isNotEmpty &&
              balances.containsKey(walletId)) {
            balances[walletId] = (balances[walletId] ?? 0) - transaction.amount;
          }
          break;

        case TransactionType.transfer:
          final fromWalletId = transaction.fromWalletId;
          final toWalletId = transaction.toWalletId;

          if (fromWalletId != null &&
              fromWalletId.isNotEmpty &&
              balances.containsKey(fromWalletId)) {
            balances[fromWalletId] =
                (balances[fromWalletId] ?? 0) - transaction.amount;
          }

          if (toWalletId != null &&
              toWalletId.isNotEmpty &&
              balances.containsKey(toWalletId)) {
            balances[toWalletId] =
                (balances[toWalletId] ?? 0) + transaction.amount;
          }
          break;
      }
    }

    return balances;
  }

  // ==============================================================
  // HEADER
  // ==============================================================

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);

    final user = FirebaseAuth.instance.currentUser;

    final displayName = user?.displayName?.trim() ?? '';

    final emailName = user?.email?.split('@').first.trim() ?? '';

    final name = displayName.isNotEmpty
        ? displayName
        : emailName.isNotEmpty
        ? emailName
        : 'User';

    final initials = _getInitials(name);

    return Row(
      children: [
        // Profile avatar
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          child: user?.photoURL != null && user!.photoURL!.isNotEmpty
              ? ClipOval(
                  child: Image.network(
                    user.photoURL!,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) {
                      return Center(
                        child: Text(
                          initials,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      );
                    },
                  ),
                )
              : Center(
                  child: Text(
                    initials,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
        ),

        const SizedBox(width: 12),

        // User information
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _greeting(),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.textTheme.bodyMedium?.color?.withValues(
                    alpha: 0.60,
                  ),
                ),
              ),

              const SizedBox(height: 3),

              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),

        // Notification
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: theme.brightness == Brightness.dark
                ? AppColors.darkSurface
                : AppColors.lightSurface,
            shape: BoxShape.circle,
          ),
          child: Stack(
            children: [
              const Center(child: Icon(Icons.notifications_none_rounded)),

              Positioned(
                top: 10,
                right: 11,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: AppColors.expense,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _getInitials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) {
      return 'U';
    }

    if (parts.length == 1) {
      final value = parts.first;
      return value.length >= 2
          ? value.substring(0, 2).toUpperCase()
          : value.toUpperCase();
    }

    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
  // ==============================================================
  // GREETING
  // ==============================================================

  String _greeting() {
    final hour = DateTime.now().hour;

    if (hour < 12) {
      return 'Good morning 👋';
    }

    if (hour < 17) {
      return 'Good afternoon 👋';
    }

    return 'Good evening 👋';
  }

  // ==============================================================
  // CONVERT TRANSACTION ENTITY TO UI DATA
  // ==============================================================

  TransactionData _convertTransaction(TransactionEntity transaction) {
    final isIncome = transaction.type == TransactionType.income;

    final isTransfer = transaction.type == TransactionType.transfer;

    // Savings goal contributions are stored as transfers so the
    // source wallet balance decreases correctly.
    final isGoalContribution =
        isTransfer && transaction.categoryId == 'savings_goal';

    if (isGoalContribution) {
      return TransactionData(
        title: 'Savings Goal',
        subtitle: transaction.fromWalletName.isEmpty
            ? 'Goal contribution'
            : 'From ${transaction.fromWalletName}',
        amount: transaction.amount,
        isIncome: false,
        isTransfer: true,
        icon: Icons.savings_rounded,
        date: DateFormat('dd MMM, hh:mm a').format(transaction.date),
      );
    }

    if (isTransfer) {
      return TransactionData(
        title: 'Transfer',
        subtitle: '${transaction.fromWalletName} → ${transaction.toWalletName}',
        amount: transaction.amount,
        isIncome: false,
        isTransfer: true,
        icon: Icons.swap_vert_rounded,
        date: DateFormat('dd MMM, hh:mm a').format(transaction.date),
      );
    }

    return TransactionData(
      title: transaction.categoryName,
      subtitle: transaction.description.isEmpty
          ? _paymentMethodLabel(transaction.paymentMethod.name)
          : transaction.description,
      amount: transaction.amount,
      isIncome: isIncome,
      isTransfer: false,
      icon: _categoryIcon(transaction.categoryName),
      date: DateFormat('dd MMM, hh:mm a').format(transaction.date),
    );
  }

  // ==============================================================
  // CATEGORY ICON
  // ==============================================================

  IconData _categoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'food':
        return Icons.restaurant_rounded;

      case 'shopping':
        return Icons.shopping_bag_rounded;

      case 'transport':
        return Icons.directions_car_rounded;

      case 'bills':
        return Icons.receipt_long_rounded;

      case 'health':
        return Icons.favorite_rounded;

      case 'entertainment':
        return Icons.movie_rounded;

      case 'salary':
        return Icons.account_balance_wallet_rounded;

      case 'freelance':
        return Icons.work_rounded;

      default:
        return Icons.payments_rounded;
    }
  }

  // ==============================================================
  // PAYMENT METHOD LABEL
  // ==============================================================

  String _paymentMethodLabel(String value) {
    switch (value) {
      case 'cash':
        return 'Cash';

      case 'card':
        return 'Card';

      case 'bank':
        return 'Bank';

      case 'upi':
        return 'UPI';

      default:
        return 'Transaction';
    }
  }

  // ==============================================================
  // EMPTY TRANSACTIONS
  // ==============================================================

  Widget _buildEmptyTransactions(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? AppColors.darkSurface
            : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              color: AppColors.primary,
              size: 28,
            ),
          ),

          const SizedBox(height: 14),

          Text(
            'No transactions yet',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 5),

          Text(
            'Add your first income or expense using the + button.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }

  // ==============================================================
  // BUDGET ALERTS
  // ==============================================================

  Widget _buildBudgetAlerts(
    BuildContext context,
    List<TransactionEntity> transactions,
  ) {
    return BlocBuilder<BudgetBloc, BudgetState>(
      builder: (context, budgetState) {
        final now = DateTime.now();

        final budgets = budgetState.budgets.where((budget) {
          return budget.month.year == now.year &&
              budget.month.month == now.month;
        }).toList();

        if (budgets.isEmpty) {
          return const SizedBox.shrink();
        }

        final alerts = <_BudgetAlertData>[];

        for (final budget in budgets) {
          final spent = _getBudgetSpentForDashboard(budget, transactions, now);

          if (budget.amount <= 0) {
            continue;
          }

          final ratio = spent / budget.amount;

          if (ratio >= 0.80) {
            alerts.add(
              _BudgetAlertData(budget: budget, spent: spent, ratio: ratio),
            );
          }
        }

        if (alerts.isEmpty) {
          return _buildBudgetStatusCard(context);
        }

        alerts.sort((a, b) => b.ratio.compareTo(a.ratio));

        final visibleAlerts = alerts.take(3).toList();
        final hiddenCount = alerts.length - visibleAlerts.length;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const BudgetPage()));
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.darkSurface
                  : AppColors.lightSurface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: _budgetAlertColor(alerts.first.ratio)
                    .withValues(alpha: 0.20),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: _budgetAlertColor(alerts.first.ratio)
                            .withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        alerts.first.ratio >= 1.0
                            ? Icons.warning_amber_rounded
                            : Icons.notifications_active_outlined,
                        color: _budgetAlertColor(alerts.first.ratio),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            alerts.first.ratio >= 1.0
                                ? 'Budget exceeded'
                                : 'Budget alert',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            alerts.first.ratio >= 1.0
                                ? 'You are over one or more monthly budgets.'
                                : 'You are getting close to your monthly budget limit.',
                            style: Theme.of(context).textTheme.bodySmall
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
                  ],
                ),

                const SizedBox(height: 16),

                ...visibleAlerts.map(
                  (alert) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildBudgetAlertRow(context, alert),
                  ),
                ),

                if (hiddenCount > 0) ...[
                  const SizedBox(height: 2),
                  Text(
                    '+$hiddenCount more budget alert${hiddenCount == 1 ? '' : 's'}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBudgetStatusCard(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const BudgetPage(),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.income.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.income.withValues(alpha: 0.18)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.income.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_outline_rounded,
                color: AppColors.income,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Budgets are on track',
                    style: Theme.of(context).textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'No budget has reached 80% this month.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).textTheme.bodySmall?.color
                          ?.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetAlertRow(BuildContext context, _BudgetAlertData alert) {
    final color = _budgetAlertColor(alert.ratio);
    final percent = (alert.ratio * 100).round();
    final remaining = alert.budget.amount - alert.spent;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            alert.ratio >= 1.0
                ? Icons.error_outline_rounded
                : Icons.account_balance_wallet_outlined,
            color: color,
            size: 20,
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      alert.budget.categoryName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$percent%',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: LinearProgressIndicator(
                  minHeight: 7,
                  value: alert.ratio.clamp(0.0, 1.0).toDouble(),
                  backgroundColor: color.withValues(alpha: 0.10),
                  color: color,
                ),
              ),
              const SizedBox(height: 5),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    alert.ratio >= 1.0 ? 'Over budget by ' : '',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: color, fontWeight: FontWeight.w700),
                  ),
                  CurrencyText(
                    alert.ratio >= 1.0 ? remaining.abs() : remaining,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  if (alert.ratio < 1.0) ...[
                    const SizedBox(width: 4),
                    Text(
                      'remaining',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: color, fontWeight: FontWeight.w700),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  double _getBudgetSpentForDashboard(
    BudgetEntity budget,
    List<TransactionEntity> transactions,
    DateTime month,
  ) {
    return transactions
        .where((transaction) {
          if (transaction.type != TransactionType.expense) {
            return false;
          }

          if (transaction.date.year != month.year ||
              transaction.date.month != month.month) {
            return false;
          }

          if (budget.categoryId.isNotEmpty &&
              transaction.categoryId.isNotEmpty &&
              transaction.categoryId == budget.categoryId) {
            return true;
          }

          return transaction.categoryName.trim().toLowerCase() ==
              budget.categoryName.trim().toLowerCase();
        })
        .fold<double>(0, (total, transaction) => total + transaction.amount);
  }

  Color _budgetAlertColor(double ratio) {
    if (ratio >= 1.0) {
      return AppColors.expense;
    }

    if (ratio >= 0.90) {
      return const Color(0xFFFF8A3D);
    }

    return const Color(0xFFF2C94C);
  }

  // ==============================================================
  // SPENDING OVERVIEW
  // ==============================================================

  Widget _buildSpendingSummary(
    BuildContext context, {
    required double income,
    required double expense,
    required double balance,
  }) {
    final theme = Theme.of(context);

    final percentage = income > 0 ? (expense / income).clamp(0.0, 1.0) : 0.0;

    final remaining = balance;

    return GestureDetector(
      onTap: () {
        Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const AnalyticsPage()));
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.brightness == Brightness.dark
              ? AppColors.darkSurface
              : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.insights_rounded,
                    color: AppColors.primary,
                  ),
                ),

                const SizedBox(width: 13),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Spending Overview',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),

                      const SizedBox(height: 3),

                      Text(
                        'Based on your transactions',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.textTheme.bodySmall?.color?.withValues(
                            alpha: 0.55,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 22),

            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: LinearProgressIndicator(
                minHeight: 9,
                value: percentage,
                backgroundColor: AppColors.expense.withValues(alpha: 0.10),
                color: AppColors.expense,
              ),
            ),

            const SizedBox(height: 15),

            // Bottom information
            Row(
              children: [
                Expanded(
                  child: Text(
                    expense == 0
                        ? 'No expenses yet'
                        : '${(percentage * 100).toStringAsFixed(0)}% of income spent',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CurrencyText(
                      remaining,
                      style: TextStyle(
                        color: remaining >= 0
                            ? AppColors.income
                            : AppColors.expense,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'balance',
                      style: TextStyle(
                        color: remaining >= 0
                            ? AppColors.income
                            : AppColors.expense,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BudgetAlertData {
  final BudgetEntity budget;
  final double spent;
  final double ratio;

  const _BudgetAlertData({
    required this.budget,
    required this.spent,
    required this.ratio,
  });
}
