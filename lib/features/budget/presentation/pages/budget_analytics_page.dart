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

class BudgetAnalyticsPage extends StatefulWidget {
  const BudgetAnalyticsPage({super.key});

  @override
  State<BudgetAnalyticsPage> createState() => _BudgetAnalyticsPageState();
}

class _BudgetAnalyticsPageState extends State<BudgetAnalyticsPage> {
  DateTime _selectedMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
  );

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BudgetBloc>().add(const LoadBudgets());
      context.read<TransactionBloc>().add(const LoadTransactions());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Budget Analytics',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
      ),
      body: BlocBuilder<BudgetBloc, BudgetState>(
        builder: (context, budgetState) {
          return BlocBuilder<TransactionBloc, TransactionState>(
            builder: (context, transactionState) {
              final monthBudgets = _budgetsForMonth(
                budgetState.budgets,
                _selectedMonth,
              );

              final monthExpenses = _expensesForMonth(
                transactionState.transactions,
                _selectedMonth,
              );

              final totalBudget = monthBudgets.fold<double>(
                0,
                    (sum, budget) => sum + budget.amount,
              );

              final totalSpent = _totalBudgetedSpending(
                monthBudgets,
                monthExpenses,
              );

              final remaining = totalBudget - totalSpent;
              final utilization = totalBudget > 0
                  ? totalSpent / totalBudget
                  : 0.0;

              return RefreshIndicator(
                onRefresh: () async {
                  context.read<BudgetBloc>().add(const LoadBudgets());
                  context
                      .read<TransactionBloc>()
                      .add(const LoadTransactions());
                  await Future.delayed(const Duration(milliseconds: 350));
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 110),
                  children: [
                    _buildMonthSelector(context),
                    const SizedBox(height: 20),
                    _buildSummaryCard(
                      context,
                      totalBudget: totalBudget,
                      totalSpent: totalSpent,
                      remaining: remaining,
                      utilization: utilization,
                    ),
                    const SizedBox(height: 20),
                    _buildCategoryPerformance(
                      context,
                      budgets: monthBudgets,
                      expenses: monthExpenses,
                    ),
                    const SizedBox(height: 20),
                    _buildTopCategory(
                      context,
                      budgets: monthBudgets,
                      expenses: monthExpenses,
                    ),
                    const SizedBox(height: 20),
                    _buildMonthlyTrend(
                      context,
                      budgets: budgetState.budgets,
                      transactions: transactionState.transactions,
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

  Widget _buildMonthSelector(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? AppColors.darkSurface
            : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.brightness == Brightness.dark
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
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Expanded(
            child: Center(
              child: Text(
                DateFormat('MMMM yyyy').format(_selectedMonth),
                style: const TextStyle(fontWeight: FontWeight.w800),
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
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
      BuildContext context, {
        required double totalBudget,
        required double totalSpent,
        required double remaining,
        required double utilization,
      }) {
    final theme = Theme.of(context);
    final overBudget = remaining < 0;
    final progress = utilization.clamp(0.0, 1.0).toDouble();

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
              color: Colors.white.withValues(alpha: 0.70),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            DateFormat('MMMM yyyy').format(_selectedMonth),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 23,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              minHeight: 9,
              value: progress,
              backgroundColor: Colors.white.withValues(alpha: 0.16),
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _summaryValue(
                  context,
                  label: 'Budget',
                  amount: totalBudget,
                ),
              ),
              Expanded(
                child: _summaryValue(
                  context,
                  label: 'Spent',
                  amount: totalSpent,
                ),
              ),
              Expanded(
                child: _summaryValue(
                  context,
                  label: overBudget ? 'Over' : 'Remaining',
                  amount: remaining.abs(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            totalBudget <= 0
                ? 'No budget created for this month.'
                : overBudget
                ? '${_formatPercent(utilization)} of the budget has been used.'
                : '${_formatPercent(utilization)} of the budget has been used.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.78),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryValue(
      BuildContext context, {
        required String label,
        required double amount,
      }) {
    return BlocBuilder<CurrencyCubit, CurrencyState>(
      builder: (context, state) {
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.64),
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                CurrencyFormatter.formatCompact(amount, state.currency),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCategoryPerformance(
      BuildContext context, {
        required List<BudgetEntity> budgets,
        required List<TransactionEntity> expenses,
      }) {
    final theme = Theme.of(context);

    if (budgets.isEmpty) {
      return _emptyCard(
        context,
        icon: Icons.pie_chart_outline_rounded,
        title: 'No category budgets',
        message: 'Create budgets to see category performance here.',
      );
    }

    final rows = budgets
        .map(
          (budget) => _CategoryMetric(
        name: budget.categoryName,
        budget: budget.amount,
        spent: _spentForBudget(budget, expenses),
      ),
    )
        .toList()
      ..sort((a, b) => b.ratio.compareTo(a.ratio));

    return _sectionCard(
      context,
      title: 'Category Performance',
      subtitle: 'Budget usage by category',
      child: Column(
        children: rows.map((row) {
          final ratio = row.ratio;
          final color = ratio >= 1.0
              ? AppColors.expense
              : ratio >= 0.90
              ? const Color(0xFFFF8A3D)
              : AppColors.primary;

          return Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        row.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatPercent(ratio),
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: LinearProgressIndicator(
                    minHeight: 8,
                    value: ratio.clamp(0.0, 1.0).toDouble(),
                    backgroundColor: color.withValues(alpha: 0.10),
                    color: color,
                  ),
                ),
                const SizedBox(height: 6),
                BlocBuilder<CurrencyCubit, CurrencyState>(
                  builder: (context, state) {
                    return Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${CurrencyFormatter.formatCompact(row.spent, state.currency)} spent',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.textTheme.bodySmall?.color
                                  ?.withValues(alpha: 0.58),
                            ),
                          ),
                        ),
                        Text(
                          'of ${CurrencyFormatter.formatCompact(row.budget, state.currency)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.textTheme.bodySmall?.color
                                ?.withValues(alpha: 0.58),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTopCategory(
      BuildContext context, {
        required List<BudgetEntity> budgets,
        required List<TransactionEntity> expenses,
      }) {
    if (budgets.isEmpty) {
      return const SizedBox.shrink();
    }

    final metrics = budgets
        .map(
          (budget) => _CategoryMetric(
        name: budget.categoryName,
        budget: budget.amount,
        spent: _spentForBudget(budget, expenses),
      ),
    )
        .toList();

    metrics.sort((a, b) => b.spent.compareTo(a.spent));
    final top = metrics.first;

    return _sectionCard(
      context,
      title: 'Top Budgeted Spending',
      subtitle: 'Highest spending category this month',
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.expense.withValues(alpha: 0.11),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.trending_up_rounded,
              color: AppColors.expense,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  top.name,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                BlocBuilder<CurrencyCubit, CurrencyState>(
                  builder: (context, state) {
                    return Text(
                      CurrencyFormatter.formatCompact(
                        top.spent,
                        state.currency,
                      ),
                      style: TextStyle(
                        color: AppColors.expense,
                        fontWeight: FontWeight.w800,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          Text(
            _formatPercent(top.ratio),
            style: TextStyle(
              color: top.ratio >= 1.0 ? AppColors.expense : AppColors.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyTrend(
      BuildContext context, {
        required List<BudgetEntity> budgets,
        required List<TransactionEntity> transactions,
      }) {
    final points = <_MonthlyPoint>[];

    for (int offset = 5; offset >= 0; offset--) {
      final month = DateTime(
        _selectedMonth.year,
        _selectedMonth.month - offset,
      );

      final monthBudgets = _budgetsForMonth(budgets, month);
      final monthExpenses = _expensesForMonth(transactions, month);

      final budgetTotal = monthBudgets.fold<double>(
        0,
            (sum, budget) => sum + budget.amount,
      );

      final spent = _totalBudgetedSpending(monthBudgets, monthExpenses);

      points.add(
        _MonthlyPoint(
          month: month,
          budget: budgetTotal,
          spent: spent,
        ),
      );
    }

    final maxValue = points.fold<double>(
      0,
          (max, point) => [max, point.budget, point.spent].reduce(
            (a, b) => a > b ? a : b,
      ),
    );

    if (maxValue <= 0) {
      return _emptyCard(
        context,
        icon: Icons.show_chart_rounded,
        title: 'No trend data',
        message: 'Create budgets and add expenses to build a monthly trend.',
      );
    }

    return _sectionCard(
      context,
      title: '6-Month Trend',
      subtitle: 'Budget vs budgeted spending',
      child: Column(
        children: [
          SizedBox(
            height: 180,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: points.map((point) {
                final budgetHeight = 118 * (point.budget / maxValue);
                final spentHeight = 118 * (point.spent / maxValue);

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        SizedBox(
                          height: 125,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _trendBar(
                                height: budgetHeight,
                                color: AppColors.primary.withValues(alpha: 0.28),
                              ),
                              const SizedBox(width: 4),
                              _trendBar(
                                height: spentHeight,
                                color: AppColors.expense,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          DateFormat('MMM').format(point.month),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legendDot(AppColors.primary.withValues(alpha: 0.35), 'Budget'),
              const SizedBox(width: 18),
              _legendDot(AppColors.expense, 'Spent'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _trendBar({required double height, required Color color}) {
    return Container(
      width: 9,
      height: height.clamp(2.0, 118.0),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }

  Widget _legendDot(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _sectionCard(
      BuildContext context, {
        required String title,
        required String subtitle,
        required Widget child,
      }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? AppColors.darkSurface
            : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: theme.brightness == Brightness.dark
              ? AppColors.darkBorder
              : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }

  Widget _emptyCard(
      BuildContext context, {
        required IconData icon,
        required String title,
        required String message,
      }) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? AppColors.darkSurface
            : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 13),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.58),
            ),
          ),
        ],
      ),
    );
  }

  List<BudgetEntity> _budgetsForMonth(
      List<BudgetEntity> budgets,
      DateTime month,
      ) {
    return budgets
        .where(
          (budget) =>
      budget.month.year == month.year &&
          budget.month.month == month.month,
    )
        .toList();
  }

  List<TransactionEntity> _expensesForMonth(
      List<TransactionEntity> transactions,
      DateTime month,
      ) {
    return transactions
        .where(
          (transaction) =>
      transaction.type == TransactionType.expense &&
          transaction.date.year == month.year &&
          transaction.date.month == month.month,
    )
        .toList();
  }

  double _totalBudgetedSpending(
      List<BudgetEntity> budgets,
      List<TransactionEntity> expenses,
      ) {
    return budgets.fold<double>(
      0,
          (sum, budget) => sum + _spentForBudget(budget, expenses),
    );
  }

  double _spentForBudget(
      BudgetEntity budget,
      List<TransactionEntity> expenses,
      ) {
    return expenses
        .where(
          (transaction) {
        if (budget.categoryId.isNotEmpty &&
            transaction.categoryId.isNotEmpty &&
            budget.categoryId == transaction.categoryId) {
          return true;
        }

        return transaction.categoryName.trim().toLowerCase() ==
            budget.categoryName.trim().toLowerCase();
      },
    )
        .fold<double>(0, (sum, transaction) => sum + transaction.amount);
  }

  String _formatPercent(double ratio) {
    return '${(ratio * 100).round()}%';
  }
}

class _CategoryMetric {
  final String name;
  final double budget;
  final double spent;

  const _CategoryMetric({
    required this.name,
    required this.budget,
    required this.spent,
  });

  double get ratio => budget > 0 ? spent / budget : 0;
}

class _MonthlyPoint {
  final DateTime month;
  final double budget;
  final double spent;

  const _MonthlyPoint({
    required this.month,
    required this.budget,
    required this.spent,
  });
}
