import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/currency/currency_cubit.dart';
import '../../../../core/currency/currency_state.dart';
import '../../../../core/enums/app_currency.dart';
import '../../../../core/enums/transaction_type.dart';
import '../../../budget/presentation/bloc/budget_bloc.dart';
import '../../../budget/presentation/bloc/budget_event.dart';
import '../../../budget/presentation/bloc/budget_state.dart';
import '../../../transactions/presentation/bloc/transaction_bloc.dart';
import '../../../transactions/presentation/bloc/transaction_event.dart';
import '../../../transactions/presentation/bloc/transaction_state.dart';
import '../../domain/financial_insights_calculator.dart';

class FinancialInsightsPage extends StatefulWidget {
  const FinancialInsightsPage({super.key});

  @override
  State<FinancialInsightsPage> createState() => _FinancialInsightsPageState();
}

class _FinancialInsightsPageState extends State<FinancialInsightsPage> {
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  final _calculator = const FinancialInsightsCalculator();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reload();
    });
  }

  void _reload() {
    context.read<TransactionBloc>().add(const LoadTransactions());
    context.read<BudgetBloc>().add(const LoadBudgets());
  }

  void _previousMonth() {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month - 1,
      );
    });
  }

  void _nextMonth() {
    final now = DateTime.now();
    final next = DateTime(
      _selectedMonth.year,
      _selectedMonth.month + 1,
    );

    if (next.year > now.year ||
        (next.year == now.year && next.month > now.month)) {
      return;
    }

    setState(() {
      _selectedMonth = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Financial Insights',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
      ),
      body: BlocBuilder<TransactionBloc, TransactionState>(
        builder: (context, transactionState) {
          return BlocBuilder<BudgetBloc, BudgetState>(
            builder: (context, budgetState) {
              final result = _calculator.calculate(
                transactions: transactionState.transactions,
                budgets: budgetState.budgets,
                month: _selectedMonth,
              );

              return RefreshIndicator(
                color: AppColors.primary,
                onRefresh: () async {
                  _reload();
                  await Future.delayed(const Duration(milliseconds: 500));
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
                  children: [
                    _buildMonthSelector(context),
                    const SizedBox(height: 18),
                    if (!result.hasData)
                      _buildEmptyState(context)
                    else ...[
                      _buildHealthCard(context, result),
                      const SizedBox(height: 16),
                      _buildOverview(context, result),
                      const SizedBox(height: 22),
                      _buildInsightsSection(context, result),
                      const SizedBox(height: 22),
                      _buildDetails(context, result),
                    ],
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
            onPressed: _previousMonth,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Expanded(
            child: Text(
              DateFormat('MMMM yyyy').format(_selectedMonth),
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          IconButton(
            onPressed: _nextMonth,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthCard(
    BuildContext context,
    FinancialInsightsResult result,
  ) {
    final theme = Theme.of(context);
    final score = result.healthScore.round();
    final scoreColor = score >= 80
        ? AppColors.income
        : score >= 60
            ? AppColors.primary
            : AppColors.expense;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            scoreColor.withValues(alpha: 0.18),
            theme.brightness == Brightness.dark
                ? AppColors.darkSurface
                : AppColors.lightSurface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: scoreColor.withValues(alpha: 0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: scoreColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.insights_rounded,
                  color: scoreColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Financial health',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _scoreLabel(score),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scoreColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '$score',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: scoreColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: LinearProgressIndicator(
              minHeight: 10,
              value: score / 100,
              backgroundColor: scoreColor.withValues(alpha: 0.10),
              valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Based on saving behavior, spending trend and budget discipline for this month.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.58),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverview(
    BuildContext context,
    FinancialInsightsResult result,
  ) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _metricCard(
                context,
                title: 'Income',
                amount: result.income,
                icon: Icons.south_west_rounded,
                iconColor: AppColors.income,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _metricCard(
                context,
                title: 'Expenses',
                amount: result.expense,
                icon: Icons.north_east_rounded,
                iconColor: AppColors.expense,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _metricCard(
                context,
                title: 'Saved',
                amount: result.savings,
                icon: Icons.savings_rounded,
                iconColor: AppColors.navPurple,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _simpleMetricCard(
                context,
                title: 'Savings rate',
                value: '${result.savingsRate.toStringAsFixed(0)}%',
                icon: Icons.percent_rounded,
                iconColor: AppColors.primary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _metricCard(
    BuildContext context, {
    required String title,
    required double amount,
    required IconData icon,
    required Color iconColor,
  }) {
    final theme = Theme.of(context);
    return _baseCard(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 19),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          BlocBuilder<CurrencyCubit, CurrencyState>(
            builder: (context, currency) {
              final formatter = NumberFormat.currency(
                symbol: '${currency.currency.symbol} ',
                decimalDigits: 2,
              );
              return Text(
                formatter.format(amount),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _simpleMetricCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
  }) {
    final theme = Theme.of(context);
    return _baseCard(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 19),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightsSection(
    BuildContext context,
    FinancialInsightsResult result,
  ) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What your money is telling you',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 12),
        ...result.insights.map(
          (insight) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _insightCard(context, insight),
          ),
        ),
      ],
    );
  }

  Widget _insightCard(BuildContext context, FinancialInsight insight) {
    final theme = Theme.of(context);
    final color = _toneColor(insight.tone);
    final icon = _toneIcon(insight.tone);

    return _baseCard(
      context,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.11),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  insight.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  insight.message,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.62),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetails(
    BuildContext context,
    FinancialInsightsResult result,
  ) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'More details',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 12),
        _detailRow(
          context,
          'Average daily expense',
          _formatAmount(context, result.averageDailyExpense),
          Icons.today_rounded,
        ),
        if (result.topCategory != null)
          _detailRow(
            context,
            'Top spending category',
            '${result.topCategory} • ${_formatAmount(context, result.topCategoryAmount)}',
            Icons.category_rounded,
          ),
        if (result.largestExpenseCategory != null)
          _detailRow(
            context,
            'Largest single expense',
            '${result.largestExpenseCategory} • ${_formatAmount(context, result.largestExpenseAmount)}',
            Icons.receipt_long_rounded,
          ),
        if (result.budgetUtilization != null)
          _detailRow(
            context,
            'Budget used',
            '${result.budgetUtilization!.toStringAsFixed(0)}%',
            Icons.account_balance_rounded,
          ),
      ],
    );
  }

  Widget _detailRow(
    BuildContext context,
    String title,
    String value,
    IconData icon,
  ) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _baseCard(
        context,
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 90),
      child: Column(
        children: [
          Container(
            width: 82,
            height: 82,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.insights_rounded,
              color: AppColors.primary,
              size: 38,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Not enough data yet',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add some income or expenses for this month and your financial insights will appear here.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.58),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _baseCard(
    BuildContext context, {
    required Widget child,
  }) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? AppColors.darkSurface
            : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.brightness == Brightness.dark
              ? AppColors.darkBorder
              : AppColors.lightBorder,
        ),
      ),
      child: child,
    );
  }

  String _formatAmount(BuildContext context, double amount) {
    final currency = context.read<CurrencyCubit>().state.currency.symbol;
    return NumberFormat.currency(
      symbol: '$currency ',
      decimalDigits: 2,
    ).format(amount);
  }

  String _scoreLabel(int score) {
    if (score >= 80) return 'Excellent';
    if (score >= 60) return 'Good';
    if (score >= 40) return 'Needs attention';
    return 'At risk';
  }

  Color _toneColor(InsightTone tone) {
    switch (tone) {
      case InsightTone.positive:
        return AppColors.income;
      case InsightTone.warning:
        return AppColors.expense;
      case InsightTone.neutral:
        return AppColors.primary;
    }
  }

  IconData _toneIcon(InsightTone tone) {
    switch (tone) {
      case InsightTone.positive:
        return Icons.check_circle_outline_rounded;
      case InsightTone.warning:
        return Icons.warning_amber_rounded;
      case InsightTone.neutral:
        return Icons.tips_and_updates_outlined;
    }
  }
}
