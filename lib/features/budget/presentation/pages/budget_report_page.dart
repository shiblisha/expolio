import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/currency/currency_cubit.dart';
import '../../../../core/currency/currency_state.dart';
import '../../../../core/enums/transaction_type.dart';
import '../../../../core/utils/currency_formatter.dart';

import '../../../transactions/domain/entities/transaction_entity.dart';
import '../../../transactions/presentation/bloc/transaction_bloc.dart';
import '../../../transactions/presentation/bloc/transaction_event.dart';
import '../../../transactions/presentation/bloc/transaction_state.dart';

import '../../domain/entities/budget_entity.dart';
import '../bloc/budget_bloc.dart';
import '../bloc/budget_event.dart';
import '../bloc/budget_state.dart';

class BudgetReportPage extends StatefulWidget {
  const BudgetReportPage({super.key});

  @override
  State<BudgetReportPage> createState() => _BudgetReportPageState();
}

class _BudgetReportPageState extends State<BudgetReportPage> {
  DateTime _selectedMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Budget Report',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
      ),
      body: BlocBuilder<BudgetBloc, BudgetState>(
        builder: (context, budgetState) {
          return BlocBuilder<TransactionBloc, TransactionState>(
            builder: (context, transactionState) {
              // ======================================================
              // CURRENT MONTH
              // ======================================================

              final budgets = budgetState.budgets.where((budget) {
                return budget.month.year == _selectedMonth.year &&
                    budget.month.month == _selectedMonth.month;
              }).toList();

              final expenses = transactionState.transactions.where(
                    (transaction) {
                  return transaction.type == TransactionType.expense &&
                      transaction.date.year == _selectedMonth.year &&
                      transaction.date.month == _selectedMonth.month;
                },
              ).toList();

              // ======================================================
              // PREVIOUS MONTH
              // ======================================================

              final previousMonth = DateTime(
                _selectedMonth.year,
                _selectedMonth.month - 1,
              );

              final previousBudgets =
              budgetState.budgets.where((budget) {
                return budget.month.year == previousMonth.year &&
                    budget.month.month == previousMonth.month;
              }).toList();

              final previousExpenses =
              transactionState.transactions.where(
                    (transaction) {
                  return transaction.type == TransactionType.expense &&
                      transaction.date.year == previousMonth.year &&
                      transaction.date.month == previousMonth.month;
                },
              ).toList();

              // ======================================================
              // CURRENT TOTALS
              // ======================================================

              final totalBudget = budgets.fold<double>(
                0,
                    (total, budget) => total + budget.amount,
              );

              final totalSpent = _calculateTotalSpent(
                budgets,
                expenses,
              );

              final remaining = totalBudget - totalSpent;

              final percentage = totalBudget > 0
                  ? totalSpent / totalBudget
                  : 0.0;

              // ======================================================
              // PREVIOUS TOTALS
              // ======================================================

              final previousTotalSpent = _calculateTotalSpent(
                previousBudgets,
                previousExpenses,
              );

              final spendingChange = _calculatePercentageChange(
                previousTotalSpent,
                totalSpent,
              );

              return RefreshIndicator(
                onRefresh: () async {
                  context.read<BudgetBloc>().add(
                    const LoadBudgets(),
                  );

                  context.read<TransactionBloc>().add(
                    const LoadTransactions(),
                  );

                  await Future.delayed(
                    const Duration(milliseconds: 400),
                  );
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(
                    20,
                    12,
                    20,
                    110,
                  ),
                  children: [
                    // ==================================================
                    // MONTH SELECTOR
                    // ==================================================

                    _buildMonthSelector(context),

                    const SizedBox(height: 20),

                    // ==================================================
                    // SUMMARY
                    // ==================================================

                    _buildSummaryCard(
                      context,
                      totalBudget: totalBudget,
                      totalSpent: totalSpent,
                      remaining: remaining,
                      percentage: percentage,
                    ),

                    const SizedBox(height: 16),

                    // ==================================================
                    // PREVIOUS MONTH COMPARISON
                    // ==================================================

                    _buildMonthComparison(
                      context,
                      currentSpent: totalSpent,
                      previousSpent: previousTotalSpent,
                      change: spendingChange,
                      previousMonth: previousMonth,
                    ),

                    const SizedBox(height: 24),

                    // ==================================================
                    // CATEGORY PERFORMANCE HEADER
                    // ==================================================

                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Category Performance',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Text(
                          '${budgets.length} budgets',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                            color: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.color
                                ?.withValues(
                              alpha: 0.55,
                            ),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // ==================================================
                    // CATEGORY CARDS
                    // ==================================================

                    if (budgets.isEmpty)
                      _buildEmptyState(context)
                    else
                      ...budgets.map(
                            (budget) {
                          final spent = _getBudgetSpent(
                            budget,
                            expenses,
                          );

                          return Padding(
                            padding: const EdgeInsets.only(
                              bottom: 12,
                            ),
                            child: _buildCategoryReportCard(
                              context,
                              budget: budget,
                              spent: spent,
                            ),
                          );
                        },
                      ),

                    const SizedBox(height: 18),

                    // ==================================================
                    // INSIGHT
                    // ==================================================

                    _buildReportInsight(
                      context,
                      totalBudget: totalBudget,
                      totalSpent: totalSpent,
                      remaining: remaining,
                      budgets: budgets,
                      expenses: expenses,
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  // ==============================================================
  // MONTH SELECTOR
  // ==============================================================

  Widget _buildMonthSelector(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurface
            : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? AppColors.darkBorder
              : AppColors.lightBorder,
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              setState(() {
                _selectedMonth = DateTime(
                  _selectedMonth.year,
                  _selectedMonth.month - 1,
                );
              });
            },
            icon: const Icon(
              Icons.chevron_left_rounded,
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                DateFormat(
                  'MMMM yyyy',
                ).format(_selectedMonth),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                _selectedMonth = DateTime(
                  _selectedMonth.year,
                  _selectedMonth.month + 1,
                );
              });
            },
            icon: const Icon(
              Icons.chevron_right_rounded,
            ),
          ),
        ],
      ),
    );
  }

  // ==============================================================
  // SUMMARY CARD
  // ==============================================================

  Widget _buildSummaryCard(
      BuildContext context, {
        required double totalBudget,
        required double totalSpent,
        required double remaining,
        required double percentage,
      }) {
    final isOverBudget =
        totalBudget > 0 && totalSpent > totalBudget;

    final progress = percentage.clamp(
      0.0,
      1.0,
    ).toDouble();

    return Container(
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
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Budget Performance',
            style: TextStyle(
              color: Colors.white.withValues(
                alpha: 0.70,
              ),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 7),

          BlocBuilder<CurrencyCubit, CurrencyState>(
            builder: (
                context,
                currencyState,
                ) {
              return Text(
                CurrencyFormatter.formatCompact(
                  totalBudget,
                  currencyState.currency,
                ),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                ),
              );
            },
          ),

          const SizedBox(height: 18),

          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: LinearProgressIndicator(
              minHeight: 9,
              value: progress,
              backgroundColor: Colors.white.withValues(
                alpha: 0.14,
              ),
              color: isOverBudget
                  ? AppColors.expense
                  : Colors.white,
            ),
          ),

          const SizedBox(height: 18),

          Row(
            children: [
              Expanded(
                child: _SummaryValue(
                  title: 'Spent',
                  amount: totalSpent,
                ),
              ),
              Expanded(
                child: _SummaryValue(
                  title: isOverBudget
                      ? 'Over budget'
                      : 'Remaining',
                  amount: remaining.abs(),
                  isNegative: isOverBudget,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==============================================================
  // MONTH COMPARISON
  // ==============================================================

  Widget _buildMonthComparison(
      BuildContext context, {
        required double currentSpent,
        required double previousSpent,
        required double change,
        required DateTime previousMonth,
      }) {
    final theme = Theme.of(context);

    final hasPreviousData = previousSpent > 0;
    final spendingIncreased = currentSpent > previousSpent;
    final spendingDecreased = currentSpent < previousSpent;

    final Color color;

    if (!hasPreviousData) {
      color = AppColors.primary;
    } else if (spendingIncreased) {
      color = AppColors.expense;
    } else if (spendingDecreased) {
      color = AppColors.income;
    } else {
      color = AppColors.primary;
    }

    String title;
    String message;
    IconData icon;

    if (!hasPreviousData) {
      title = 'First month comparison';
      message =
      'There is no spending data from '
          '${DateFormat('MMMM yyyy').format(previousMonth)} '
          'to compare with.';
      icon = Icons.compare_arrows_rounded;
    } else if (spendingIncreased) {
      title = 'Spending increased';
      message =
      'You spent ${change.abs().toStringAsFixed(1)}% more '
          'than ${DateFormat('MMMM').format(previousMonth)}.';
      icon = Icons.trending_up_rounded;
    } else if (spendingDecreased) {
      title = 'Spending decreased';
      message =
      'You spent ${change.abs().toStringAsFixed(1)}% less '
          'than ${DateFormat('MMMM').format(previousMonth)}.';
      icon = Icons.trending_down_rounded;
    } else {
      title = 'Spending stayed the same';
      message =
      'Your spending is the same as '
          '${DateFormat('MMMM yyyy').format(previousMonth)}.';
      icon = Icons.compare_arrows_rounded;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withValues(
          alpha: 0.08,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withValues(
            alpha: 0.16,
          ),
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
                  color: color.withValues(
                    alpha: 0.12,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: color,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      message,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _ComparisonAmount(
                  title: DateFormat(
                    'MMM yyyy',
                  ).format(previousMonth),
                  amount: previousSpent,
                ),
              ),
              Expanded(
                child: _ComparisonAmount(
                  title: DateFormat(
                    'MMM yyyy',
                  ).format(_selectedMonth),
                  amount: currentSpent,
                ),
              ),
            ],
          ),

          if (hasPreviousData) ...[
            const SizedBox(height: 14),

            Row(
              children: [
                Icon(
                  spendingIncreased
                      ? Icons.arrow_upward_rounded
                      : spendingDecreased
                      ? Icons.arrow_downward_rounded
                      : Icons.remove_rounded,
                  size: 16,
                  color: color,
                ),

                const SizedBox(width: 5),

                Text(
                  spendingIncreased
                      ? '${change.abs().toStringAsFixed(1)}% higher than previous month'
                      : spendingDecreased
                      ? '${change.abs().toStringAsFixed(1)}% lower than previous month'
                      : 'No change from previous month',
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ==============================================================
  // CATEGORY REPORT CARD
  // ==============================================================

  Widget _buildCategoryReportCard(
      BuildContext context, {
        required BudgetEntity budget,
        required double spent,
      }) {
    final theme = Theme.of(context);

    final ratio = budget.amount > 0
        ? spent / budget.amount
        : 0.0;

    final progress = ratio.clamp(
      0.0,
      1.0,
    ).toDouble();

    final remaining = budget.amount - spent;

    final isExceeded = ratio >= 1.0;
    final isCritical = ratio >= 0.90;

    final Color indicatorColor;

    if (isExceeded) {
      indicatorColor = AppColors.expense;
    } else if (isCritical) {
      indicatorColor = const Color(0xFFFF8A3D);
    } else {
      indicatorColor = AppColors.primary;
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? AppColors.darkSurface
            : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: indicatorColor.withValues(
            alpha: isExceeded ? 0.25 : 0.12,
          ),
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
                  color: indicatorColor.withValues(
                    alpha: 0.10,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isExceeded
                      ? Icons.warning_amber_rounded
                      : Icons.account_balance_wallet_outlined,
                  color: indicatorColor,
                  size: 21,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      budget.categoryName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      isExceeded
                          ? 'Over budget'
                          : ratio >= 0.90
                          ? 'Almost reached'
                          : ratio >= 0.80
                          ? 'Keep an eye on spending'
                          : 'Within budget',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(
                        color: indicatorColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),

              Text(
                '${(ratio * 100).round()}%',
                style: TextStyle(
                  color: indicatorColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: progress,
              backgroundColor: indicatorColor.withValues(
                alpha: 0.10,
              ),
              color: indicatorColor,
            ),
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: BlocBuilder<
                    CurrencyCubit,
                    CurrencyState>(
                  builder: (
                      context,
                      currencyState,
                      ) {
                    return Text(
                      '${CurrencyFormatter.formatCompact(
                        spent,
                        currencyState.currency,
                      )} spent',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    );
                  },
                ),
              ),

              BlocBuilder<
                  CurrencyCubit,
                  CurrencyState>(
                builder: (
                    context,
                    currencyState,
                    ) {
                  return Text(
                    isExceeded
                        ? '${CurrencyFormatter.formatCompact(
                      remaining.abs(),
                      currencyState.currency,
                    )} over'
                        : '${CurrencyFormatter.formatCompact(
                      remaining,
                      currencyState.currency,
                    )} left',
                    style: TextStyle(
                      color: indicatorColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==============================================================
  // REPORT INSIGHT
  // ==============================================================

  Widget _buildReportInsight(
      BuildContext context, {
        required double totalBudget,
        required double totalSpent,
        required double remaining,
        required List<BudgetEntity> budgets,
        required List<TransactionEntity> expenses,
      }) {
    if (budgets.isEmpty) {
      return const SizedBox.shrink();
    }

    final percentage = totalBudget > 0
        ? (totalSpent / totalBudget) * 100
        : 0.0;

    BudgetEntity? highestBudget;
    double highestSpent = 0;

    for (final budget in budgets) {
      final spent = _getBudgetSpent(
        budget,
        expenses,
      );

      if (spent > highestSpent) {
        highestSpent = spent;
        highestBudget = budget;
      }
    }

    String title;
    String message;
    IconData icon;
    Color color;

    if (totalSpent > totalBudget) {
      title = 'Budget exceeded';

      message =
      'Your spending is '
          '${percentage.toStringAsFixed(0)}% '
          'of the total budget. Review your highest spending categories.';

      icon = Icons.warning_amber_rounded;
      color = AppColors.expense;
    } else if (percentage >= 90) {
      title = 'Very close to your limit';

      message =
      'You have used '
          '${percentage.toStringAsFixed(0)}% '
          'of your total budget. Consider reducing spending for the rest of the month.';

      icon = Icons.notifications_active_outlined;
      color = const Color(0xFFFF8A3D);
    } else if (percentage >= 80) {
      title = 'Keep an eye on spending';

      message =
      'You have used '
          '${percentage.toStringAsFixed(0)}% '
          'of your total budget this month.';

      icon = Icons.visibility_outlined;
      color = AppColors.primary;
    } else {
      title = 'Budget is under control';

      message = highestBudget == null
          ? 'Your spending is currently within your planned budget.'
          : '${highestBudget.categoryName} is your highest spending budget category so far.';

      icon = Icons.check_circle_outline_rounded;
      color = AppColors.income;
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withValues(
          alpha: 0.08,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withValues(
            alpha: 0.16,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(
                alpha: 0.12,
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: color,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  message,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==============================================================
  // EMPTY STATE
  // ==============================================================

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? AppColors.darkSurface
            : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(
                alpha: 0.10,
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.bar_chart_rounded,
              color: AppColors.primary,
              size: 30,
            ),
          ),

          const SizedBox(height: 14),

          Text(
            'No budget data',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 5),

          Text(
            'There are no budgets for '
                '${DateFormat('MMMM yyyy').format(_selectedMonth)}.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.textTheme.bodySmall?.color
                  ?.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }

  // ==============================================================
  // TOTAL SPENT
  // ==============================================================

  double _calculateTotalSpent(
      List<BudgetEntity> budgets,
      List<TransactionEntity> expenses,
      ) {
    return expenses.where((transaction) {
      for (final budget in budgets) {
        if (budget.categoryId.isNotEmpty &&
            transaction.categoryId.isNotEmpty &&
            budget.categoryId ==
                transaction.categoryId) {
          return true;
        }

        if (budget.categoryName
            .trim()
            .toLowerCase() ==
            transaction.categoryName
                .trim()
                .toLowerCase()) {
          return true;
        }
      }

      return false;
    }).fold<double>(
      0,
          (total, transaction) =>
      total + transaction.amount,
    );
  }

  // ==============================================================
  // CATEGORY SPENT
  // ==============================================================

  double _getBudgetSpent(
      BudgetEntity budget,
      List<TransactionEntity> transactions,
      ) {
    return transactions.where((transaction) {
      if (budget.categoryId.isNotEmpty &&
          transaction.categoryId.isNotEmpty &&
          budget.categoryId ==
              transaction.categoryId) {
        return true;
      }

      return budget.categoryName
          .trim()
          .toLowerCase() ==
          transaction.categoryName
              .trim()
              .toLowerCase();
    }).fold<double>(
      0,
          (total, transaction) =>
      total + transaction.amount,
    );
  }

  // ==============================================================
  // PERCENTAGE CHANGE
  // ==============================================================

  double _calculatePercentageChange(
      double previous,
      double current,
      ) {
    if (previous == 0) {
      return current == 0 ? 0 : 100;
    }

    return ((current - previous) / previous) * 100;
  }
}

// ================================================================
// SUMMARY VALUE
// ================================================================

class _SummaryValue extends StatelessWidget {
  final String title;
  final double amount;
  final bool isNegative;

  const _SummaryValue({
    required this.title,
    required this.amount,
    this.isNegative = false,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CurrencyCubit, CurrencyState>(
      builder: (
          context,
          currencyState,
          ) {
        return Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: Colors.white.withValues(
                  alpha: 0.65,
                ),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 5),

            Text(
              CurrencyFormatter.formatCompact(
                amount,
                currencyState.currency,
              ),
              style: TextStyle(
                color: isNegative
                    ? Colors.white
                    : Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        );
      },
    );
  }
}

// ================================================================
// COMPARISON AMOUNT
// ================================================================

class _ComparisonAmount extends StatelessWidget {
  final String title;
  final double amount;

  const _ComparisonAmount({
    required this.title,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CurrencyCubit, CurrencyState>(
      builder: (
          context,
          currencyState,
          ) {
        return Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(
                color: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.color
                    ?.withValues(
                  alpha: 0.55,
                ),
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 4),

            Text(
              CurrencyFormatter.formatCompact(
                amount,
                currencyState.currency,
              ),
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        );
      },
    );
  }
}