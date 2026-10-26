import 'dart:typed_data';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/enums/payment_method.dart';
import '../../../../core/enums/transaction_type.dart';
import '../../../../shared/widgets/app_loading_indicator.dart';
import '../../../../shared/widgets/currency_text.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';
import '../../../transactions/presentation/bloc/transaction_bloc.dart';
import '../../../transactions/presentation/bloc/transaction_event.dart';
import '../../../transactions/presentation/bloc/transaction_state.dart';

enum AnalyticsPeriod {
  thisWeek,
  thisMonth,
  lastThreeMonths,
  lastSixMonths,
  lastYear,
  allTime,
  custom,
}

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

enum _ExplorerMode { category, paymentMethod, wallet, largest }

class _AnalyticsPageState extends State<AnalyticsPage> {
  AnalyticsPeriod _selectedPeriod = AnalyticsPeriod.thisMonth;
  DateTimeRange? _customDateRange;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Analytics',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Export report',
            onPressed: () => _showExportSheet(context),
            icon: const Icon(Icons.picture_as_pdf_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: BlocBuilder<TransactionBloc, TransactionState>(
        builder: (context, state) {
          if (state.status == TransactionStatus.loading &&
              state.transactions.isEmpty) {
            return const Center(
              child: AppLoadingIndicator(
                color: AppColors.primary,
              ),
            );
          }

          if (state.status == TransactionStatus.failure &&
              state.transactions.isEmpty) {
            return _buildError(context, state.errorMessage);
          }

          final filteredTransactions = _filterTransactions(
            state.transactions,
          );

          final income = _calculateIncome(filteredTransactions);
          final expense = _calculateExpense(filteredTransactions);
          final netSavings = income - expense;
          final savingsRate = income > 0 ? (netSavings / income) * 100 : 0.0;
          final chartData = _buildTrendData(filteredTransactions);

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async {
              context.read<TransactionBloc>().add(
                const LoadTransactions(),
              );

              await Future.delayed(
                const Duration(milliseconds: 500),
              );
            },
            child: ListView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
              children: [
                _buildPeriodSelector(),

                const SizedBox(height: 12),

                Text(
                  _periodDescription(),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.textTheme.bodySmall?.color?.withValues(
                      alpha: 0.55,
                    ),
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 20),

                _buildOverview(
                  context,
                  income: income,
                  expense: expense,
                  netSavings: netSavings,
                  savingsRate: savingsRate,
                ),

                const SizedBox(height: 16),

                _buildPeriodComparisonCard(
                  context,
                  state.transactions,
                  filteredTransactions,
                ),

                const SizedBox(height: 22),

                _buildChartCard(
                  context,
                  title: 'Income vs Expense',
                  subtitle: _chartSubtitle(),
                  child: chartData.isEmpty
                      ? const _EmptyAnalytics(
                    message: 'No transaction data for this period',
                  )
                      : _buildIncomeExpenseChart(
                    context,
                    chartData,
                  ),
                ),

                const SizedBox(height: 20),

                _buildChartCard(
                  context,
                  title: 'Expense by Category',
                  subtitle: 'Top categories with smaller ones grouped into Other',
                  child: _buildCategoryChart(context, filteredTransactions),
                ),

                const SizedBox(height: 20),

                _buildCategoryInsightsCard(context, filteredTransactions),

                const SizedBox(height: 20),

                _buildCategoryBreakdownCard(context, filteredTransactions),

                const SizedBox(height: 20),

                _buildPaymentMethodCard(context, filteredTransactions),

                const SizedBox(height: 20),

                _buildWalletSpendingCard(context, filteredTransactions),

                const SizedBox(height: 20),

                _buildAnalyticsExplorerCard(context, filteredTransactions),

                const SizedBox(height: 20),

                _buildSmartInsightsCard(
                  context,
                  allTransactions: state.transactions,
                  filteredTransactions: filteredTransactions,
                ),

                const SizedBox(height: 20),

                _buildFinancialInsightsCard(context, filteredTransactions),
              ],
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // PERIOD SELECTOR
  // ============================================================

  Widget _buildPeriodSelector() {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? AppColors.darkSurface
            : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: Row(
          children: [
            _periodButton(
              title: 'This Week',
              period: AnalyticsPeriod.thisWeek,
            ),
            _periodButton(
              title: 'This Month',
              period: AnalyticsPeriod.thisMonth,
            ),
            _periodButton(
              title: '3 Months',
              period: AnalyticsPeriod.lastThreeMonths,
            ),
            _periodButton(
              title: '6 Months',
              period: AnalyticsPeriod.lastSixMonths,
            ),
            _periodButton(
              title: '1 Year',
              period: AnalyticsPeriod.lastYear,
            ),
            _periodButton(
              title: 'All Time',
              period: AnalyticsPeriod.allTime,
            ),
            _customPeriodButton(),
          ],
        ),
      ),
    );
  }

  Widget _periodButton({
    required String title,
    required AnalyticsPeriod period,
  }) {
    final selected = _selectedPeriod == period;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPeriod = period;
          if (period != AnalyticsPeriod.custom) {
            _customDateRange = null;
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected
                ? Colors.white
                : Theme.of(context).textTheme.bodyMedium?.color,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // OVERVIEW
  // ============================================================

  Widget _buildOverview(
      BuildContext context, {
        required double income,
        required double expense,
        required double netSavings,
        required double savingsRate,
      }) {
    final theme = Theme.of(context);
    final savingsColor = netSavings >= 0
        ? AppColors.income
        : AppColors.expense;

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primary,
                AppColors.primaryDark,
              ],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Net Savings',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              CurrencyText(
                netSavings,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                netSavings >= 0
                    ? 'Money left after expenses'
                    : 'Expenses are higher than income',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.60),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: _summaryCard(
                title: 'Income',
                amount: income,
                icon: Icons.arrow_downward_rounded,
                color: AppColors.income,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _summaryCard(
                title: 'Expense',
                amount: expense,
                icon: Icons.arrow_upward_rounded,
                color: AppColors.expense,
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.brightness == Brightness.dark
                ? AppColors.darkSurface
                : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: savingsColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  netSavings >= 0
                      ? Icons.savings_outlined
                      : Icons.trending_down_rounded,
                  color: savingsColor,
                  size: 19,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Savings Rate',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color?.withValues(
                          alpha: 0.60,
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${savingsRate.toStringAsFixed(1)}%',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: savingsColor,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                income > 0
                    ? 'Net savings ÷ income'
                    : 'No income in this period',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.textTheme.bodySmall?.color?.withValues(
                    alpha: 0.50,
                  ),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _summaryCard({
    required String title,
    required double amount,
    required IconData icon,
    required Color color,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? AppColors.darkSurface
            : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: color,
              size: 19,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.textTheme.bodySmall?.color?.withValues(
                      alpha: 0.60,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                CurrencyText(
                  amount,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CHART CARD
  // ============================================================

  Widget _buildChartCard(
      BuildContext context, {
        required String title,
        required String subtitle,
        required Widget child,
      }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? AppColors.darkSurface
            : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
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
                        color: theme.textTheme.bodySmall?.color?.withValues(
                          alpha: 0.55,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _buildLegendItem(
                context,
                label: 'Income',
                color: AppColors.income,
              ),
              const SizedBox(width: 10),
              _buildLegendItem(
                context,
                label: 'Expense',
                color: AppColors.expense,
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildLegendItem(
      BuildContext context, {
        required String label,
        required Color color,
      }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // INCOME VS EXPENSE TREND
  // ============================================================

  Widget _buildIncomeExpenseChart(
      BuildContext context,
      List<_TrendData> data,
      ) {
    final maxValue = _maxChartValue(data);
    final interval = _chartInterval(maxValue);

    final availableWidth = MediaQuery.sizeOf(context).width - 76;
    final chartWidth = math.max(
      availableWidth,
      data.length * 54.0,
    );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: SizedBox(
        width: chartWidth,
        height: 280,
        child: BarChart(
          BarChartData(
            minY: 0,
            maxY: maxValue,
            alignment: BarChartAlignment.spaceAround,
            groupsSpace: data.length <= 7 ? 18 : 10,
            barTouchData: BarTouchData(
              enabled: true,
              handleBuiltInTouches: true,
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => Theme.of(context).brightness == Brightness.dark
                    ? AppColors.darkSurface2
                    : AppColors.lightSurface,
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  final item = data[groupIndex];
                  final isIncome = rodIndex == 0;

                  return BarTooltipItem(
                    '${item.label}\n${isIncome ? 'Income' : 'Expense'}\n',
                    TextStyle(
                      color: isIncome
                          ? AppColors.income
                          : AppColors.expense,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                    children: [
                      TextSpan(
                        text: _formatCurrencyForTooltip(context, rod.toY),
                        style: TextStyle(
                          color: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.color,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: interval,
              getDrawingHorizontalLine: (value) {
                return FlLine(
                  color: Theme.of(context).dividerColor.withValues(
                    alpha: 0.35,
                  ),
                  strokeWidth: 1,
                );
              },
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 45,
                  interval: interval,
                  getTitlesWidget: (value, meta) {
                    return Text(
                      _formatCompact(value),
                      style: TextStyle(
                        fontSize: 9,
                        color: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.color
                            ?.withValues(alpha: 0.55),
                      ),
                    );
                  },
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 32,
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();

                    if (index < 0 || index >= data.length) {
                      return const SizedBox.shrink();
                    }

                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        data[index].label,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.color
                              ?.withValues(alpha: 0.65),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            barGroups: data.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;

              return BarChartGroupData(
                x: index,
                barsSpace: 4,
                barRods: [
                  BarChartRodData(
                    toY: item.income,
                    width: data.length <= 7 ? 11 : 8,
                    color: AppColors.income,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  BarChartRodData(
                    toY: item.expense,
                    width: data.length <= 7 ? 11 : 8,
                    color: AppColors.expense,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // EXISTING CATEGORY ANALYSIS
  // ============================================================

  // ============================================================
  // CATEGORY PIE CHART
  // ============================================================

  Widget _buildCategoryChart(
      BuildContext context,
      List<TransactionEntity> transactions,
      ) {
    final categories = _buildCategorySummaries(transactions);

    if (categories.isEmpty) {
      return const _EmptyAnalytics(message: 'No expense data for this period');
    }

    return Column(
      children: [
        SizedBox(
          height: 230,
          child: PieChart(
            PieChartData(
              centerSpaceRadius: 55,
              sectionsSpace: 3,
              sections: categories.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;

                return PieChartSectionData(
                  value: item.amount,
                  title: item.percentage >= 5
                      ? '${item.percentage.toStringAsFixed(0)}%'
                      : '',
                  radius: 70,
                  titleStyle: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                  color: _categoryColor(index),
                );
              }).toList(),
            ),
          ),
        ),

        const SizedBox(height: 15),

        ...categories.map((item) {
          final index = categories.indexOf(item);

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(
                    color: _categoryColor(index),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    item.name,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '${item.percentage.toStringAsFixed(0)}%',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.color
                        ?.withValues(alpha: 0.55),
                  ),
                ),
                const SizedBox(width: 10),
                CurrencyText(
                  item.amount,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ============================================================
  // CATEGORY INSIGHTS
  // ============================================================

  Widget _buildCategoryInsightsCard(
      BuildContext context,
      List<TransactionEntity> transactions,
      ) {
    final categories = _buildCategorySummaries(transactions);
    final theme = Theme.of(context);

    if (categories.isEmpty) {
      return const SizedBox();
    }

    final top = categories.first;
    final totalExpense = _calculateExpense(transactions);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? AppColors.darkSurface
            : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Category Insights',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: _categoryColor(0).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _categoryIcon(top.name),
                  color: _categoryColor(0),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Highest spending category',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color?.withValues(
                          alpha: 0.55,
                        ),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      top.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${top.percentage.toStringAsFixed(0)}% of total expenses',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color?.withValues(
                          alpha: 0.60,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              CurrencyText(
                top.amount,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(
            height: 1,
            color: theme.dividerColor.withValues(alpha: 0.45),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _categoryMetric(
                  context,
                  label: 'Categories used',
                  value: '${_countExpenseCategories(transactions)}',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _categoryMetric(
                  context,
                  label: 'Top share',
                  value: '${top.percentage.toStringAsFixed(0)}%',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _categoryMetric(
                  context,
                  label: 'Total spent',
                  widget: CurrencyText(
                    totalExpense,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _categoryMetric(
      BuildContext context, {
        required String label,
        String? value,
        Widget? widget,
      }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? AppColors.darkSurface2
            : Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 10,
              color: theme.textTheme.bodySmall?.color?.withValues(
                alpha: 0.55,
              ),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          widget ??
              Text(
                value ?? '-',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
        ],
      ),
    );
  }

  // ============================================================
  // CATEGORY BREAKDOWN
  // ============================================================

  Widget _buildCategoryBreakdownCard(
      BuildContext context,
      List<TransactionEntity> transactions,
      ) {
    final categories = _buildCategorySummaries(transactions);

    if (categories.isEmpty) {
      return const SizedBox();
    }

    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? AppColors.darkSurface
            : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Category Breakdown',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Where your expenses are going',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 18),
          ...categories.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final categoryColor = _categoryColor(index);

            return Padding(
              padding: const EdgeInsets.only(bottom: 15),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: categoryColor.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _categoryIcon(item.name),
                          color: categoryColor,
                          size: 17,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${item.transactionCount} transaction${item.transactionCount == 1 ? '' : 's'}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.textTheme.bodySmall?.color
                                    ?.withValues(alpha: 0.50),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          CurrencyText(
                            item.amount,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${item.percentage.toStringAsFixed(0)}%',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: categoryColor,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      minHeight: 6,
                      value: item.percentage / 100,
                      backgroundColor: categoryColor.withValues(alpha: 0.08),
                      color: categoryColor,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ============================================================
  // PAYMENT METHOD ANALYSIS
  // ============================================================

  Widget _buildPaymentMethodCard(
      BuildContext context,
      List<TransactionEntity> transactions,
      ) {
    final methods = _buildPaymentMethodSummaries(transactions);
    final theme = Theme.of(context);

    if (methods.isEmpty) {
      return const SizedBox();
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? AppColors.darkSurface
            : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Payment Methods',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'How you are spending your money',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 18),
          ...methods.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final methodColor = _paymentMethodColor(index);

            return Padding(
              padding: EdgeInsets.only(
                bottom: index == methods.length - 1 ? 0 : 15,
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: methodColor.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _paymentIcon(item.method),
                          color: methodColor,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _paymentLabel(item.method),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${item.transactionCount} transaction${item.transactionCount == 1 ? '' : 's'}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.textTheme.bodySmall?.color
                                    ?.withValues(alpha: 0.50),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          CurrencyText(
                            item.amount,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${item.percentage.toStringAsFixed(0)}%',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: methodColor,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      minHeight: 6,
                      value: item.percentage / 100,
                      backgroundColor: methodColor.withValues(alpha: 0.08),
                      color: methodColor,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ============================================================
  // WALLET SPENDING ANALYSIS
  // ============================================================

  Widget _buildWalletSpendingCard(
      BuildContext context,
      List<TransactionEntity> transactions,
      ) {
    final wallets = _buildWalletSummaries(transactions);
    final theme = Theme.of(context);

    if (wallets.isEmpty) {
      return const SizedBox();
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? AppColors.darkSurface
            : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Wallet Spending',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Which wallets are used most for expenses',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 18),
          ...wallets.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final walletColor = _walletColor(index);

            return Padding(
              padding: EdgeInsets.only(
                bottom: index == wallets.length - 1 ? 0 : 15,
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: walletColor.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _walletIcon(item.name),
                          color: walletColor,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${item.transactionCount} expense${item.transactionCount == 1 ? '' : 's'}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.textTheme.bodySmall?.color
                                    ?.withValues(alpha: 0.50),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          CurrencyText(
                            item.amount,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${item.percentage.toStringAsFixed(0)}%',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: walletColor,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      minHeight: 6,
                      value: item.percentage / 100,
                      backgroundColor: walletColor.withValues(alpha: 0.08),
                      color: walletColor,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ============================================================
  // INTERACTIVE TRANSACTION EXPLORER
  // ============================================================

  Widget _buildAnalyticsExplorerCard(
      BuildContext context,
      List<TransactionEntity> transactions,
      ) {
    final theme = Theme.of(context);
    final expenseCount = transactions
        .where((transaction) => transaction.type == TransactionType.expense)
        .length;

    if (expenseCount == 0) {
      return const SizedBox();
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? AppColors.darkSurface
            : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Explore Transactions',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Drill down into the transactions behind your analytics',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color?.withValues(
                          alpha: 0.55,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.manage_search_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _analyticsExplorerAction(
                  context,
                  icon: Icons.category_rounded,
                  title: 'Category',
                  subtitle: 'See category expenses',
                  onTap: () => _showTransactionExplorer(
                    context,
                    transactions,
                    _ExplorerMode.category,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _analyticsExplorerAction(
                  context,
                  icon: Icons.payments_rounded,
                  title: 'Payment',
                  subtitle: 'Cash, card, UPI...',
                  onTap: () => _showTransactionExplorer(
                    context,
                    transactions,
                    _ExplorerMode.paymentMethod,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _analyticsExplorerAction(
                  context,
                  icon: Icons.account_balance_wallet_rounded,
                  title: 'Wallet',
                  subtitle: 'See wallet expenses',
                  onTap: () => _showTransactionExplorer(
                    context,
                    transactions,
                    _ExplorerMode.wallet,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _analyticsExplorerAction(
                  context,
                  icon: Icons.trending_up_rounded,
                  title: 'Largest',
                  subtitle: 'Biggest expenses first',
                  onTap: () => _showTransactionExplorer(
                    context,
                    transactions,
                    _ExplorerMode.largest,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _analyticsExplorerAction(
      BuildContext context, {
        required IconData icon,
        required String title,
        required String subtitle,
        required VoidCallback onTap,
      }) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: theme.brightness == Brightness.dark
                ? AppColors.darkSurface2
                : theme.scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.dividerColor.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 10,
                        color: theme.textTheme.bodySmall?.color?.withValues(
                          alpha: 0.52,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 19,
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _explorerGroupIcon(_ExplorerMode mode, String groupName) {
    switch (mode) {
      case _ExplorerMode.category:
        return _categoryIcon(groupName);
      case _ExplorerMode.paymentMethod:
        switch (groupName) {
          case 'Cash':
            return _paymentIcon(PaymentMethod.cash);
          case 'Card':
            return _paymentIcon(PaymentMethod.card);
          case 'Bank':
            return _paymentIcon(PaymentMethod.bank);
          case 'UPI':
            return _paymentIcon(PaymentMethod.upi);
          default:
            return Icons.payments_rounded;
        }
      case _ExplorerMode.wallet:
        return _walletIcon(groupName);
      case _ExplorerMode.largest:
        return Icons.trending_up_rounded;
    }
  }

  Future<void> _showTransactionExplorer(
      BuildContext context,
      List<TransactionEntity> transactions,
      _ExplorerMode mode,
      ) async {
    final expenseTransactions = transactions
        .where((transaction) => transaction.type == TransactionType.expense)
        .toList();

    List<TransactionEntity> displayTransactions = List.of(expenseTransactions);
    String title;
    String subtitle;

    switch (mode) {
      case _ExplorerMode.category:
        title = 'Expenses by Category';
        subtitle = 'Choose a category to inspect its transactions';
        break;
      case _ExplorerMode.paymentMethod:
        title = 'Expenses by Payment Method';
        subtitle = 'Choose a payment method to inspect its transactions';
        break;
      case _ExplorerMode.wallet:
        title = 'Expenses by Wallet';
        subtitle = 'Choose a wallet to inspect its transactions';
        break;
      case _ExplorerMode.largest:
        title = 'Largest Expenses';
        subtitle = 'Your highest-value expenses in this period';
        displayTransactions.sort((a, b) => b.amount.compareTo(a.amount));
        displayTransactions = displayTransactions.take(20).toList();
        break;
    }

    if (mode != _ExplorerMode.largest) {
      final groups = <String, List<TransactionEntity>>{};

      for (final transaction in expenseTransactions) {
        final key = switch (mode) {
          _ExplorerMode.category => transaction.categoryName.trim().isEmpty
              ? 'Uncategorized'
              : transaction.categoryName.trim(),
          _ExplorerMode.paymentMethod => _paymentLabel(transaction.paymentMethod),
          _ExplorerMode.wallet => transaction.walletName.trim().isEmpty
              ? 'Unassigned Wallet'
              : transaction.walletName.trim(),
          _ExplorerMode.largest => '',
        };

        groups.putIfAbsent(key, () => <TransactionEntity>[]).add(transaction);
      }

      if (groups.isEmpty) return;

      final selectedGroup = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        backgroundColor: Theme.of(context).cardColor,
        builder: (sheetContext) {
          final entries = groups.entries.toList()
            ..sort((a, b) {
              final aTotal = a.value.fold<double>(0, (sum, item) => sum + item.amount);
              final bTotal = b.value.fold<double>(0, (sum, item) => sum + item.amount);
              return bTotal.compareTo(aTotal);
            });

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 620),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(
                        color: Theme.of(sheetContext)
                            .textTheme
                            .bodySmall
                            ?.color
                            ?.withValues(alpha: 0.55),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: ListView.separated(
                        itemCount: entries.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, index) {
                          final entry = entries[index];
                          final total = entry.value.fold<double>(
                            0,
                                (sum, item) => sum + item.amount,
                          );

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            tileColor: Theme.of(sheetContext).brightness ==
                                Brightness.dark
                                ? AppColors.darkSurface2
                                : Theme.of(sheetContext)
                                .scaffoldBackgroundColor,
                            leading: Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.10),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _explorerGroupIcon(mode, entry.key),
                                color: AppColors.primary,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              entry.key,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                            subtitle: Text(
                              '${entry.value.length} expense${entry.value.length == 1 ? '' : 's'}',
                            ),
                            trailing: CurrencyText(
                              total,
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                            onTap: () => Navigator.pop(sheetContext, entry.key),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );

      if (!mounted || selectedGroup == null) return;

      displayTransactions = expenseTransactions.where((transaction) {
        switch (mode) {
          case _ExplorerMode.category:
            final name = transaction.categoryName.trim().isEmpty
                ? 'Uncategorized'
                : transaction.categoryName.trim();
            return name == selectedGroup;
          case _ExplorerMode.paymentMethod:
            return _paymentLabel(transaction.paymentMethod) == selectedGroup;
          case _ExplorerMode.wallet:
            final name = transaction.walletName.trim().isEmpty
                ? 'Unassigned Wallet'
                : transaction.walletName.trim();
            return name == selectedGroup;
          case _ExplorerMode.largest:
            return true;
        }
      }).toList();

      displayTransactions.sort((a, b) => b.date.compareTo(a.date));
      title = selectedGroup;
      subtitle = '${displayTransactions.length} matching expense${displayTransactions.length == 1 ? '' : 's'}';
    }

    if (!mounted || displayTransactions.isEmpty) return;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final total = displayTransactions.fold<double>(
          0,
              (sum, transaction) => sum + transaction.amount,
        );

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 690),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.textTheme.bodySmall?.color?.withValues(
                              alpha: 0.55,
                            ),
                          ),
                        ),
                      ),
                      CurrencyText(
                        total,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: ListView.separated(
                      itemCount: displayTransactions.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, index) {
                        final transaction = displayTransactions[index];
                        return _buildExplorerTransactionTile(
                          sheetContext,
                          transaction,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildExplorerTransactionTile(
      BuildContext context,
      TransactionEntity transaction,
      ) {
    final theme = Theme.of(context);
    final date = DateFormat('dd MMM yyyy').format(transaction.date);
    final wallet = transaction.walletName.trim().isEmpty
        ? 'Unassigned Wallet'
        : transaction.walletName.trim();
    final category = transaction.categoryName.trim().isEmpty
        ? 'Uncategorized'
        : transaction.categoryName.trim();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showTransactionDetails(context, transaction),
        child: Ink(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: theme.brightness == Brightness.dark
                ? AppColors.darkSurface2
                : theme.scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.dividerColor.withValues(alpha: 0.30),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.expense.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_downward_rounded,
                  color: AppColors.expense,
                  size: 19,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$date • $wallet • ${_paymentLabel(transaction.paymentMethod)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        color: theme.textTheme.bodySmall?.color?.withValues(
                          alpha: 0.52,
                        ),
                      ),
                    ),
                    if (transaction.description.trim().isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        transaction.description.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              CurrencyText(
                transaction.amount,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: AppColors.expense,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showTransactionDetails(
      BuildContext context,
      TransactionEntity transaction,
      ) async {
    final wallet = transaction.walletName.trim().isEmpty
        ? 'Unassigned Wallet'
        : transaction.walletName.trim();
    final category = transaction.categoryName.trim().isEmpty
        ? 'Uncategorized'
        : transaction.categoryName.trim();

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).cardColor,
      builder: (sheetContext) {
        final sheetTheme = Theme.of(sheetContext);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 26),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.expense.withValues(alpha: 0.10),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_downward_rounded,
                        color: AppColors.expense,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            category,
                            style: sheetTheme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            DateFormat('dd MMM yyyy • hh:mm a').format(transaction.date),
                            style: sheetTheme.textTheme.bodySmall?.copyWith(
                              color: sheetTheme.textTheme.bodySmall?.color?.withValues(
                                alpha: 0.55,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    CurrencyText(
                      transaction.amount,
                      style: sheetTheme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: AppColors.expense,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _transactionDetailRow(
                  sheetContext,
                  Icons.category_rounded,
                  'Category',
                  category,
                ),
                _transactionDetailRow(
                  sheetContext,
                  _paymentIcon(transaction.paymentMethod),
                  'Payment Method',
                  _paymentLabel(transaction.paymentMethod),
                ),
                _transactionDetailRow(
                  sheetContext,
                  Icons.account_balance_wallet_rounded,
                  'Wallet',
                  wallet,
                ),
                _transactionDetailRow(
                  sheetContext,
                  Icons.calendar_today_rounded,
                  'Date',
                  DateFormat('dd MMM yyyy').format(transaction.date),
                ),
                if (transaction.description.trim().isNotEmpty)
                  _transactionDetailRow(
                    sheetContext,
                    Icons.notes_rounded,
                    'Note',
                    transaction.description.trim(),
                  ),
              ],
            ),
          ),
        );
      },
    );

  }

  Widget _transactionDetailRow(
      BuildContext context,
      IconData icon,
      String label,
      String value,
      ) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 19,
            color: theme.iconTheme.color?.withValues(alpha: 0.65),
          ),
          const SizedBox(width: 11),
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.55),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // FINANCIAL INSIGHTS
  // ============================================================

  Widget _buildFinancialInsightsCard(
      BuildContext context,
      List<TransactionEntity> transactions,
      ) {
    final theme = Theme.of(context);
    final expenseTransactions = transactions
        .where((transaction) => transaction.type == TransactionType.expense)
        .toList();

    if (expenseTransactions.isEmpty) {
      return const SizedBox();
    }

    final totalExpense = _calculateExpense(transactions);
    final categories = _buildCategorySummaries(transactions);
    final methods = _buildPaymentMethodSummaries(transactions);
    final wallets = _buildWalletSummaries(transactions);

    final topCategory = categories.isEmpty ? null : categories.first;
    final topMethod = methods.isEmpty ? null : methods.first;
    final topWallet = wallets.isEmpty ? null : wallets.first;

    final averageExpense =
        totalExpense / math.max(1, _distinctExpenseDays(expenseTransactions));

    final mostFrequentCategory = _mostFrequentExpenseCategory(expenseTransactions);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? AppColors.darkSurface
            : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Financial Insights',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'A quick summary of your spending habits',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 16),
          if (topCategory != null)
            _insightRow(
              context,
              icon: Icons.category_rounded,
              title: 'Highest spending category',
              value: topCategory.name,
              trailing: '${topCategory.percentage.toStringAsFixed(0)}%',
            ),
          if (topMethod != null) ...[
            const SizedBox(height: 12),
            _insightRow(
              context,
              icon: _paymentIcon(topMethod.method),
              title: 'Top payment method',
              value: _paymentLabel(topMethod.method),
              trailing: '${topMethod.percentage.toStringAsFixed(0)}%',
            ),
          ],
          if (topWallet != null) ...[
            const SizedBox(height: 12),
            _insightRow(
              context,
              icon: _walletIcon(topWallet.name),
              title: 'Top spending wallet',
              value: topWallet.name,
              trailing: '${topWallet.percentage.toStringAsFixed(0)}%',
            ),
          ],
          const SizedBox(height: 12),
          _insightRow(
            context,
            icon: Icons.speed_rounded,
            title: 'Average daily expense',
            value: 'Based on active expense days',
            trailing: _formatCompactCurrency(averageExpense),
          ),
          const SizedBox(height: 12),
          _insightRow(
            context,
            icon: Icons.receipt_long_rounded,
            title: 'Most frequent category',
            value: mostFrequentCategory,
            trailing: '${expenseTransactions.length} expenses',
          ),
        ],
      ),
    );
  }

  Widget _insightRow(
      BuildContext context, {
        required IconData icon,
        required String title,
        required String value,
        required String trailing,
      }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? AppColors.darkSurface2
            : theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 18,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.55),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            trailing,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PAYMENT METHOD TOTALS
  // ============================================================

  List<_PaymentMethodSummary> _buildPaymentMethodSummaries(
      List<TransactionEntity> transactions,
      ) {
    final amounts = <PaymentMethod, double>{};
    final counts = <PaymentMethod, int>{};

    for (final transaction in transactions) {
      if (transaction.type != TransactionType.expense) {
        continue;
      }

      amounts.update(
        transaction.paymentMethod,
            (value) => value + transaction.amount,
        ifAbsent: () => transaction.amount,
      );
      counts.update(
        transaction.paymentMethod,
            (value) => value + 1,
        ifAbsent: () => 1,
      );
    }

    final methods = amounts.keys.toList()
      ..sort((a, b) => amounts[b]!.compareTo(amounts[a]!));

    if (methods.isEmpty) {
      return const [];
    }

    final total = amounts.values.fold<double>(
      0,
          (sum, amount) => sum + amount,
    );

    return methods.map((method) {
      final amount = amounts[method]!;
      return _PaymentMethodSummary(
        method: method,
        amount: amount,
        transactionCount: counts[method]!,
        percentage: total == 0 ? 0 : (amount / total) * 100,
      );
    }).toList();
  }

  Color _paymentMethodColor(int index) {
    const colors = [
      AppColors.primary,
      AppColors.income,
      AppColors.expense,
      Color(0xFF6B3DF5),
    ];

    return colors[index % colors.length];
  }

  IconData _paymentIcon(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.cash:
        return Icons.payments_rounded;
      case PaymentMethod.card:
        return Icons.credit_card_rounded;
      case PaymentMethod.bank:
        return Icons.account_balance_rounded;
      case PaymentMethod.upi:
        return Icons.qr_code_rounded;
    }
  }

  String _paymentLabel(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.cash:
        return 'Cash';
      case PaymentMethod.card:
        return 'Card';
      case PaymentMethod.bank:
        return 'Bank';
      case PaymentMethod.upi:
        return 'UPI';
    }
  }

  // ============================================================
  // WALLET TOTALS
  // ============================================================

  List<_WalletSummary> _buildWalletSummaries(
      List<TransactionEntity> transactions,
      ) {
    final amounts = <String, double>{};
    final counts = <String, int>{};

    for (final transaction in transactions) {
      if (transaction.type != TransactionType.expense) {
        continue;
      }

      final walletName = transaction.walletName.trim().isEmpty
          ? 'Unassigned Wallet'
          : transaction.walletName.trim();

      amounts.update(
        walletName,
            (value) => value + transaction.amount,
        ifAbsent: () => transaction.amount,
      );
      counts.update(
        walletName,
            (value) => value + 1,
        ifAbsent: () => 1,
      );
    }

    final names = amounts.keys.toList()
      ..sort((a, b) => amounts[b]!.compareTo(amounts[a]!));

    if (names.isEmpty) {
      return const [];
    }

    final total = amounts.values.fold<double>(
      0,
          (sum, amount) => sum + amount,
    );

    return names.map((name) {
      final amount = amounts[name]!;
      return _WalletSummary(
        name: name,
        amount: amount,
        transactionCount: counts[name]!,
        percentage: total == 0 ? 0 : (amount / total) * 100,
      );
    }).toList();
  }

  Color _walletColor(int index) {
    const colors = [
      AppColors.primary,
      Color(0xFF6B3DF5),
      AppColors.income,
      AppColors.expense,
      Color(0xFFFFA726),
      Color(0xFF42A5F5),
    ];

    return colors[index % colors.length];
  }

  IconData _walletIcon(String walletName) {
    switch (walletName.toLowerCase()) {
      case 'cash':
        return Icons.payments_rounded;
      case 'bank':
      case 'bank account':
        return Icons.account_balance_rounded;
      case 'upi':
        return Icons.qr_code_rounded;
      case 'card':
      case 'credit card':
      case 'debit card':
        return Icons.credit_card_rounded;
      case 'savings':
        return Icons.savings_rounded;
      default:
        return Icons.account_balance_wallet_rounded;
    }
  }

  // ============================================================
  // INSIGHT HELPERS
  // ============================================================

  int _distinctExpenseDays(List<TransactionEntity> transactions) {
    final days = <String>{};

    for (final transaction in transactions) {
      days.add(
        '${transaction.date.year}-${transaction.date.month}-${transaction.date.day}',
      );
    }

    return days.length;
  }

  String _mostFrequentExpenseCategory(
      List<TransactionEntity> transactions,
      ) {
    final counts = <String, int>{};

    for (final transaction in transactions) {
      final category = transaction.categoryName.trim().isEmpty
          ? 'Uncategorized'
          : transaction.categoryName.trim();
      counts.update(
        category,
            (value) => value + 1,
        ifAbsent: () => 1,
      );
    }

    if (counts.isEmpty) {
      return 'None';
    }

    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  String _formatCompactCurrency(double value) {
    return NumberFormat.compactCurrency(
      decimalDigits: 1,
      symbol: '',
    ).format(value).trim();
  }

  // ============================================================
  // CATEGORY TOTALS
  // ============================================================

  Map<String, double> _buildCategoryTotals(
      List<TransactionEntity> transactions,
      ) {
    final totals = <String, double>{};

    for (final transaction in transactions) {
      if (transaction.type != TransactionType.expense) {
        continue;
      }

      final categoryName = transaction.categoryName.trim().isEmpty
          ? 'Uncategorized'
          : transaction.categoryName.trim();

      totals.update(
        categoryName,
            (value) => value + transaction.amount,
        ifAbsent: () => transaction.amount,
      );
    }

    return totals;
  }

  int _countExpenseCategories(List<TransactionEntity> transactions) {
    final names = <String>{};

    for (final transaction in transactions) {
      if (transaction.type != TransactionType.expense) {
        continue;
      }

      names.add(
        transaction.categoryName.trim().isEmpty
            ? 'Uncategorized'
            : transaction.categoryName.trim(),
      );
    }

    return names.length;
  }

  List<_CategorySummary> _buildCategorySummaries(
      List<TransactionEntity> transactions,
      ) {
    final amounts = <String, double>{};
    final counts = <String, int>{};

    for (final transaction in transactions) {
      if (transaction.type != TransactionType.expense) {
        continue;
      }

      final categoryName = transaction.categoryName.trim().isEmpty
          ? 'Uncategorized'
          : transaction.categoryName.trim();

      amounts.update(
        categoryName,
            (value) => value + transaction.amount,
        ifAbsent: () => transaction.amount,
      );
      counts.update(
        categoryName,
            (value) => value + 1,
        ifAbsent: () => 1,
      );
    }

    final sortedNames = amounts.keys.toList()
      ..sort((a, b) => amounts[b]!.compareTo(amounts[a]!));

    if (sortedNames.isEmpty) {
      return const [];
    }

    final totalExpense = amounts.values.fold<double>(
      0,
          (total, amount) => total + amount,
    );

    final visibleNames = sortedNames.take(5).toList();
    final result = <_CategorySummary>[];

    for (final name in visibleNames) {
      result.add(
        _CategorySummary(
          name: name,
          amount: amounts[name]!,
          transactionCount: counts[name]!,
          percentage: totalExpense == 0
              ? 0
              : (amounts[name]! / totalExpense) * 100,
        ),
      );
    }

    if (sortedNames.length > visibleNames.length) {
      double otherAmount = 0;
      int otherCount = 0;

      for (final name in sortedNames.skip(visibleNames.length)) {
        otherAmount += amounts[name]!;
        otherCount += counts[name]!;
      }

      result.add(
        _CategorySummary(
          name: 'Other',
          amount: otherAmount,
          transactionCount: otherCount,
          percentage: totalExpense == 0
              ? 0
              : (otherAmount / totalExpense) * 100,
        ),
      );
    }

    return result;
  }

  Color _categoryColor(int index) {
    const colors = [
      AppColors.primary,
      AppColors.income,
      AppColors.expense,
      Color(0xFF6B3DF5),
      Color(0xFFFFA726),
      Color(0xFF42A5F5),
    ];

    return colors[index % colors.length];
  }

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

  // ============================================================
  // FILTERING
  // ============================================================

  List<TransactionEntity> _filterTransactions(
      List<TransactionEntity> transactions,
      ) {
    final now = DateTime.now();

    switch (_selectedPeriod) {
      case AnalyticsPeriod.thisWeek:
        final start = _startOfWeek(now);
        final end = start.add(const Duration(days: 7));

        return transactions.where((transaction) {
          return !transaction.date.isBefore(start) &&
              transaction.date.isBefore(end);
        }).toList();

      case AnalyticsPeriod.thisMonth:
        final start = DateTime(now.year, now.month, 1);
        final end = DateTime(now.year, now.month + 1, 1);

        return transactions.where((transaction) {
          return !transaction.date.isBefore(start) &&
              transaction.date.isBefore(end);
        }).toList();

      case AnalyticsPeriod.lastThreeMonths:
        final start = DateTime(now.year, now.month - 2, 1);
        final end = DateTime(now.year, now.month + 1, 1);

        return transactions.where((transaction) {
          return !transaction.date.isBefore(start) &&
              transaction.date.isBefore(end);
        }).toList();

      case AnalyticsPeriod.lastSixMonths:
        final start = DateTime(now.year, now.month - 5, 1);
        final end = DateTime(now.year, now.month + 1, 1);

        return transactions.where((transaction) {
          return !transaction.date.isBefore(start) &&
              transaction.date.isBefore(end);
        }).toList();

      case AnalyticsPeriod.lastYear:
        final start = DateTime(now.year, now.month - 11, 1);
        final end = DateTime(now.year, now.month + 1, 1);

        return transactions.where((transaction) {
          return !transaction.date.isBefore(start) &&
              transaction.date.isBefore(end);
        }).toList();

      case AnalyticsPeriod.allTime:
        return transactions.toList();

      case AnalyticsPeriod.custom:
        final range = _customDateRange;
        if (range == null) {
          return const [];
        }

        final start = DateTime(
          range.start.year,
          range.start.month,
          range.start.day,
        );
        final endExclusive = DateTime(
          range.end.year,
          range.end.month,
          range.end.day,
        ).add(const Duration(days: 1));

        return transactions.where((transaction) {
          return !transaction.date.isBefore(start) &&
              transaction.date.isBefore(endExclusive);
        }).toList();
    }
  }

  DateTime _startOfWeek(DateTime date) {
    final dayOffset = date.weekday - DateTime.monday;
    return DateTime(
      date.year,
      date.month,
      date.day,
    ).subtract(Duration(days: dayOffset));
  }

  // ============================================================
  // CALCULATIONS
  // ============================================================

  double _calculateIncome(List<TransactionEntity> transactions) {
    return transactions
        .where((transaction) => transaction.type == TransactionType.income)
        .fold<double>(0, (total, transaction) => total + transaction.amount);
  }

  double _calculateExpense(List<TransactionEntity> transactions) {
    return transactions
        .where((transaction) => transaction.type == TransactionType.expense)
        .fold<double>(0, (total, transaction) => total + transaction.amount);
  }

  // ============================================================
  // TREND DATA
  // ============================================================

  List<_TrendData> _buildTrendData(
      List<TransactionEntity> transactions,
      ) {
    switch (_selectedPeriod) {
      case AnalyticsPeriod.thisWeek:
        return _buildDailyData(
          transactions,
          DateTimeRange(
            start: _startOfWeek(DateTime.now()),
            end: _startOfWeek(DateTime.now()).add(const Duration(days: 6)),
          ),
        );

      case AnalyticsPeriod.thisMonth:
        final now = DateTime.now();
        final start = DateTime(now.year, now.month, 1);
        final days = DateTime(now.year, now.month + 1, 0).day;

        return _buildDailyData(
          transactions,
          DateTimeRange(
            start: start,
            end: start.add(Duration(days: days - 1)),
          ),
        );

      case AnalyticsPeriod.lastThreeMonths:
        return _buildMonthlyTrendData(transactions, 3);

      case AnalyticsPeriod.lastSixMonths:
        return _buildMonthlyTrendData(transactions, 6);

      case AnalyticsPeriod.lastYear:
        return _buildMonthlyTrendData(transactions, 12);

      case AnalyticsPeriod.allTime:
        return _buildAllTimeMonthlyTrendData(transactions);

      case AnalyticsPeriod.custom:
        final range = _customDateRange;
        if (range == null) {
          return const [];
        }
        final dayCount = DateTime(
          range.end.year,
          range.end.month,
          range.end.day,
        )
            .difference(DateTime(
          range.start.year,
          range.start.month,
          range.start.day,
        ))
            .inDays +
            1;

        if (dayCount <= 31) {
          return _buildCustomDailyData(transactions, range);
        }

        return _buildCustomMonthlyData(transactions, range);
    }
  }

  List<_TrendData> _buildDailyData(
      List<TransactionEntity> transactions,
      DateTimeRange range,
      ) {
    final start = DateTime(
      range.start.year,
      range.start.month,
      range.start.day,
    );
    final end = DateTime(
      range.end.year,
      range.end.month,
      range.end.day,
    );

    final dayCount = end.difference(start).inDays + 1;
    final result = <_TrendData>[];

    for (int index = 0; index < dayCount; index++) {
      final date = start.add(Duration(days: index));
      double income = 0;
      double expense = 0;

      for (final transaction in transactions) {
        final sameDay = transaction.date.year == date.year &&
            transaction.date.month == date.month &&
            transaction.date.day == date.day;

        if (!sameDay) {
          continue;
        }

        if (transaction.type == TransactionType.income) {
          income += transaction.amount;
        } else if (transaction.type == TransactionType.expense) {
          expense += transaction.amount;
        }
      }

      result.add(
        _TrendData(
          label: _selectedPeriod == AnalyticsPeriod.thisWeek
              ? DateFormat('EEE').format(date)
              : DateFormat('d').format(date),
          income: income,
          expense: expense,
        ),
      );
    }

    return result;
  }

  List<_TrendData> _buildCustomDailyData(
      List<TransactionEntity> transactions,
      DateTimeRange range,
      ) {
    final start = DateTime(
      range.start.year,
      range.start.month,
      range.start.day,
    );
    final end = DateTime(
      range.end.year,
      range.end.month,
      range.end.day,
    );
    final dayCount = end.difference(start).inDays + 1;
    final result = <_TrendData>[];

    for (int index = 0; index < dayCount; index++) {
      final date = start.add(Duration(days: index));
      double income = 0;
      double expense = 0;

      for (final transaction in transactions) {
        if (transaction.date.year != date.year ||
            transaction.date.month != date.month ||
            transaction.date.day != date.day) {
          continue;
        }

        if (transaction.type == TransactionType.income) {
          income += transaction.amount;
        } else if (transaction.type == TransactionType.expense) {
          expense += transaction.amount;
        }
      }

      result.add(
        _TrendData(
          label: DateFormat('d MMM').format(date),
          income: income,
          expense: expense,
        ),
      );
    }

    return result;
  }

  List<_TrendData> _buildCustomMonthlyData(
      List<TransactionEntity> transactions,
      DateTimeRange range,
      ) {
    final firstMonth = DateTime(
      range.start.year,
      range.start.month,
      1,
    );
    final lastMonth = DateTime(
      range.end.year,
      range.end.month,
      1,
    );

    final monthCount = ((lastMonth.year - firstMonth.year) * 12) +
        lastMonth.month -
        firstMonth.month +
        1;

    final result = <_TrendData>[];

    for (int index = 0; index < monthCount; index++) {
      final month = DateTime(
        firstMonth.year,
        firstMonth.month + index,
        1,
      );

      double income = 0;
      double expense = 0;

      for (final transaction in transactions) {
        if (transaction.date.year != month.year ||
            transaction.date.month != month.month) {
          continue;
        }

        if (transaction.type == TransactionType.income) {
          income += transaction.amount;
        } else if (transaction.type == TransactionType.expense) {
          expense += transaction.amount;
        }
      }

      result.add(
        _TrendData(
          label: DateFormat('MMM yy').format(month),
          income: income,
          expense: expense,
        ),
      );
    }

    return result;
  }

  List<_TrendData> _buildMonthlyTrendData(
      List<TransactionEntity> transactions,
      int monthCount,
      ) {
    final now = DateTime.now();
    final result = <_TrendData>[];

    for (int index = monthCount - 1; index >= 0; index--) {
      final month = DateTime(
        now.year,
        now.month - index,
        1,
      );

      result.add(
        _monthlyTrendForDate(
          transactions,
          month,
        ),
      );
    }

    return result;
  }

  List<_TrendData> _buildAllTimeMonthlyTrendData(
      List<TransactionEntity> transactions,
      ) {
    if (transactions.isEmpty) {
      return const [];
    }

    DateTime firstDate = transactions.first.date;

    for (final transaction in transactions) {
      if (transaction.date.isBefore(firstDate)) {
        firstDate = transaction.date;
      }
    }

    final now = DateTime.now();
    final firstMonth = DateTime(firstDate.year, firstDate.month, 1);
    final currentMonth = DateTime(now.year, now.month, 1);

    final monthCount = ((currentMonth.year - firstMonth.year) * 12) +
        currentMonth.month -
        firstMonth.month +
        1;

    final result = <_TrendData>[];

    for (int index = monthCount - 1; index >= 0; index--) {
      final month = DateTime(
        currentMonth.year,
        currentMonth.month - index,
        1,
      );

      result.add(
        _monthlyTrendForDate(
          transactions,
          month,
        ),
      );
    }

    return result;
  }

  _TrendData _monthlyTrendForDate(
      List<TransactionEntity> transactions,
      DateTime month,
      ) {
    double income = 0;
    double expense = 0;

    for (final transaction in transactions) {
      if (transaction.date.year != month.year ||
          transaction.date.month != month.month) {
        continue;
      }

      if (transaction.type == TransactionType.income) {
        income += transaction.amount;
      } else if (transaction.type == TransactionType.expense) {
        expense += transaction.amount;
      }
    }

    return _TrendData(
      label: DateFormat('MMM').format(month),
      income: income,
      expense: expense,
    );
  }

  // ============================================================
  // CHART HELPERS
  // ============================================================

  double _maxChartValue(List<_TrendData> data) {
    if (data.isEmpty) {
      return 100;
    }

    double maxValue = 100;

    for (final item in data) {
      maxValue = math.max(maxValue, item.income);
      maxValue = math.max(maxValue, item.expense);
    }

    return maxValue * 1.20;
  }

  double _chartInterval(double maxValue) {
    if (maxValue <= 500) {
      return 100;
    }

    if (maxValue <= 2000) {
      return 500;
    }

    if (maxValue <= 10000) {
      return 2000;
    }

    final raw = maxValue / 4;
    final magnitude = math.pow(10, raw.toStringAsFixed(0).length - 1).toDouble();
    final normalized = raw / magnitude;

    if (normalized <= 1) {
      return magnitude;
    }

    if (normalized <= 2) {
      return 2 * magnitude;
    }

    if (normalized <= 5) {
      return 5 * magnitude;
    }

    return 10 * magnitude;
  }

  String _formatCompact(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }

    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }

    return value.toStringAsFixed(0);
  }

  String _formatCurrencyForTooltip(
      BuildContext context,
      double value,
      ) {
    // Keep tooltip formatting compact and currency-aware without adding
    // another dependency or duplicating CurrencyCubit state handling here.
    final formatted = NumberFormat.compactCurrency(
      decimalDigits: 1,
      symbol: '',
    ).format(value);

    return formatted.trim();
  }

  // ============================================================
  // PAGE TEXT
  // ============================================================

  String _periodDescription() {
    final now = DateTime.now();

    switch (_selectedPeriod) {
      case AnalyticsPeriod.thisWeek:
        final start = _startOfWeek(now);
        final end = start.add(const Duration(days: 6));
        return '${DateFormat('d MMM').format(start)} – ${DateFormat('d MMM yyyy').format(end)}';

      case AnalyticsPeriod.thisMonth:
        return DateFormat('MMMM yyyy').format(now);

      case AnalyticsPeriod.lastThreeMonths:
        final start = DateTime(now.year, now.month - 2, 1);
        return '${DateFormat('MMM yyyy').format(start)} – ${DateFormat('MMM yyyy').format(now)}';

      case AnalyticsPeriod.lastSixMonths:
        final start = DateTime(now.year, now.month - 5, 1);
        return '${DateFormat('MMM yyyy').format(start)} – ${DateFormat('MMM yyyy').format(now)}';

      case AnalyticsPeriod.lastYear:
        final start = DateTime(now.year, now.month - 11, 1);
        return '${DateFormat('MMM yyyy').format(start)} – ${DateFormat('MMM yyyy').format(now)}';

      case AnalyticsPeriod.allTime:
        return 'Complete transaction history';

      case AnalyticsPeriod.custom:
        final range = _customDateRange;
        if (range == null) {
          return 'Choose a custom date range';
        }
        return '${DateFormat('d MMM').format(range.start)} – ${DateFormat('d MMM yyyy').format(range.end)}';
    }
  }

  String _chartSubtitle() {
    switch (_selectedPeriod) {
      case AnalyticsPeriod.thisWeek:
        return 'Daily activity';
      case AnalyticsPeriod.thisMonth:
        return 'Daily activity';
      case AnalyticsPeriod.lastThreeMonths:
      case AnalyticsPeriod.lastSixMonths:
      case AnalyticsPeriod.lastYear:
      case AnalyticsPeriod.allTime:
        return 'Monthly activity';
      case AnalyticsPeriod.custom:
        final range = _customDateRange;
        if (range == null) {
          return 'Custom activity';
        }
        final days = range.end.difference(range.start).inDays + 1;
        return days <= 31 ? 'Daily activity' : 'Monthly activity';
    }
  }

  Widget _customPeriodButton() {
    final selected = _selectedPeriod == AnalyticsPeriod.custom;
    final title = _customDateRange == null
        ? 'Custom'
        : '${DateFormat('d MMM').format(_customDateRange!.start)} – ${DateFormat('d MMM').format(_customDateRange!.end)}';

    return GestureDetector(
      onTap: _selectCustomDateRange,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.date_range_rounded,
              size: 15,
              color: selected
                  ? Colors.white
                  : Theme.of(context).textTheme.bodyMedium?.color,
            ),
            const SizedBox(width: 5),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected
                    ? Colors.white
                    : Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectCustomDateRange() async {
    final now = DateTime.now();
    final initialStart = _customDateRange?.start ??
        DateTime(now.year, now.month, now.day).subtract(
          const Duration(days: 29),
        );
    final initialEnd = _customDateRange?.end ??
        DateTime(now.year, now.month, now.day);

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1, now.month, now.day),
      initialDateRange: DateTimeRange(
        start: initialStart.isBefore(DateTime(2000))
            ? DateTime(2000)
            : initialStart,
        end: initialEnd,
      ),
      helpText: 'Select analytics period',
      saveText: 'Apply',
    );

    if (!mounted || picked == null) {
      return;
    }

    setState(() {
      _customDateRange = DateTimeRange(
        start: DateTime(
          picked.start.year,
          picked.start.month,
          picked.start.day,
        ),
        end: DateTime(
          picked.end.year,
          picked.end.month,
          picked.end.day,
        ),
      );
      _selectedPeriod = AnalyticsPeriod.custom;
    });
  }

  // ============================================================
  // PERIOD COMPARISON
  // ============================================================

  Widget _buildPeriodComparisonCard(
      BuildContext context,
      List<TransactionEntity> allTransactions,
      List<TransactionEntity> currentTransactions,
      ) {
    final comparison = _buildComparisonData(allTransactions);

    if (comparison == null) {
      return _buildChartCard(
        context,
        title: 'Period Comparison',
        subtitle: 'Choose a fixed period to compare with the previous one',
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: _EmptyAnalytics(
            message: 'Comparison is available for fixed periods only',
          ),
        ),
      );
    }

    if (currentTransactions.isEmpty && comparison.previousTransactions.isEmpty) {
      return _buildChartCard(
        context,
        title: 'Period Comparison',
        subtitle: 'Current period vs previous period',
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: _EmptyAnalytics(
            message: 'No transaction data to compare',
          ),
        ),
      );
    }

    final currentIncome = _calculateIncome(currentTransactions);
    final currentExpense = _calculateExpense(currentTransactions);
    final previousIncome = _calculateIncome(comparison.previousTransactions);
    final previousExpense = _calculateExpense(comparison.previousTransactions);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
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
                  color: AppColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.compare_arrows_rounded,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Period Comparison',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      comparison.subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.color
                            ?.withValues(alpha: 0.6),
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
                child: _comparisonMetric(
                  context,
                  label: 'Income',
                  current: currentIncome,
                  previous: previousIncome,
                  positiveIsUp: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _comparisonMetric(
                  context,
                  label: 'Expense',
                  current: currentExpense,
                  previous: previousExpense,
                  positiveIsUp: false,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _comparisonMetric(
            context,
            label: 'Net Savings',
            current: currentIncome - currentExpense,
            previous: previousIncome - previousExpense,
            positiveIsUp: true,
          ),
        ],
      ),
    );
  }

  Widget _comparisonMetric(
      BuildContext context, {
        required String label,
        required double current,
        required double previous,
        required bool positiveIsUp,
      }) {
    final change = _percentageChange(current, previous);
    final hasPrevious = previous != 0;
    final improved = positiveIsUp ? change >= 0 : change <= 0;
    final neutral = !hasPrevious || change.abs() < 0.01;
    final icon = change >= 0
        ? Icons.trending_up_rounded
        : Icons.trending_down_rounded;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.darkSurface
            : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.color
                  ?.withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(height: 6),
          CurrencyText(
            current,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                neutral ? Icons.remove_rounded : icon,
                size: 15,
                color: neutral
                    ? Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.color
                    ?.withValues(alpha: 0.5)
                    : (improved ? AppColors.income : AppColors.expense),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  !hasPrevious
                      ? 'No previous data'
                      : '${change.abs().toStringAsFixed(1)}% vs previous',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: neutral
                        ? Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.color
                        ?.withValues(alpha: 0.55)
                        : (improved ? AppColors.income : AppColors.expense),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  double _percentageChange(double current, double previous) {
    if (previous == 0) {
      if (current == 0) return 0;
      return current > 0 ? 100 : -100;
    }

    return ((current - previous) / previous) * 100;
  }

  _ComparisonData? _buildComparisonData(
      List<TransactionEntity> allTransactions,
      ) {
    final now = DateTime.now();
    DateTime currentStart;
    DateTime currentEndExclusive;

    switch (_selectedPeriod) {
      case AnalyticsPeriod.thisWeek:
        currentStart = _startOfWeek(now);
        currentEndExclusive = currentStart.add(const Duration(days: 7));
        break;
      case AnalyticsPeriod.thisMonth:
        currentStart = DateTime(now.year, now.month, 1);
        currentEndExclusive = DateTime(now.year, now.month + 1, 1);
        break;
      case AnalyticsPeriod.lastThreeMonths:
        currentStart = DateTime(now.year, now.month - 2, 1);
        currentEndExclusive = DateTime(now.year, now.month + 1, 1);
        break;
      case AnalyticsPeriod.lastSixMonths:
        currentStart = DateTime(now.year, now.month - 5, 1);
        currentEndExclusive = DateTime(now.year, now.month + 1, 1);
        break;
      case AnalyticsPeriod.lastYear:
        currentStart = DateTime(now.year, now.month - 11, 1);
        currentEndExclusive = DateTime(now.year, now.month + 1, 1);
        break;
      case AnalyticsPeriod.custom:
        final range = _customDateRange;
        if (range == null) return null;
        currentStart = DateTime(
          range.start.year,
          range.start.month,
          range.start.day,
        );
        currentEndExclusive = DateTime(
          range.end.year,
          range.end.month,
          range.end.day,
        ).add(const Duration(days: 1));
        break;
      case AnalyticsPeriod.allTime:
        return null;
    }

    final duration = currentEndExclusive.difference(currentStart);
    final previousEndExclusive = currentStart;
    final previousStart = currentStart.subtract(duration);

    final previousTransactions = allTransactions.where((transaction) {
      return !transaction.date.isBefore(previousStart) &&
          transaction.date.isBefore(previousEndExclusive);
    }).toList();

    return _ComparisonData(
      previousTransactions: previousTransactions,
      subtitle:
      '${DateFormat('d MMM').format(previousStart)} – ${DateFormat('d MMM yyyy').format(currentStart.subtract(const Duration(days: 1)))} vs current',
    );
  }


  // ============================================================
  // SMART INSIGHTS
  // ============================================================

  Widget _buildSmartInsightsCard(
      BuildContext context, {
        required List<TransactionEntity> allTransactions,
        required List<TransactionEntity> filteredTransactions,
      }) {
    final theme = Theme.of(context);
    final insights = _buildSmartInsightItems(
      allTransactions: allTransactions,
      filteredTransactions: filteredTransactions,
    );

    if (insights.isEmpty) {
      return const SizedBox();
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? AppColors.darkSurface
            : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(22),
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
                  color: AppColors.primary.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Smart Insights',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Useful signals from your selected period',
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
          const SizedBox(height: 16),
          ...insights.map(
                (item) => Padding(
              padding: EdgeInsets.only(
                bottom: item == insights.last ? 0 : 10,
              ),
              child: _smartInsightTile(context, item),
            ),
          ),
        ],
      ),
    );
  }

  Widget _smartInsightTile(
      BuildContext context,
      _SmartInsight item,
      ) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? AppColors.darkSurface2
            : theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(item.icon, color: item.color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.textTheme.bodySmall?.color?.withValues(
                      alpha: 0.55,
                    ),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<_SmartInsight> _buildSmartInsightItems({
    required List<TransactionEntity> allTransactions,
    required List<TransactionEntity> filteredTransactions,
  }) {
    final items = <_SmartInsight>[];
    final expenseTransactions = filteredTransactions
        .where((t) => t.type == TransactionType.expense)
        .toList();
    final incomeTransactions = filteredTransactions
        .where((t) => t.type == TransactionType.income)
        .toList();

    if (expenseTransactions.isEmpty && incomeTransactions.isEmpty) {
      return items;
    }

    final income = _calculateIncome(filteredTransactions);
    final expense = _calculateExpense(filteredTransactions);
    final net = income - expense;

    // 1. Savings health.
    if (income > 0) {
      final rate = (net / income) * 100;
      if (rate >= 30) {
        items.add(
          const _SmartInsight(
            icon: Icons.savings_rounded,
            color: AppColors.income,
            title: 'Savings health',
            message: 'Strong savings rate — you kept at least 30% of income.',
          ),
        );
      } else if (rate >= 10) {
        items.add(
          const _SmartInsight(
            icon: Icons.trending_up_rounded,
            color: AppColors.primary,
            title: 'Savings health',
            message: 'You are saving money, but there is room to improve.',
          ),
        );
      } else if (rate >= 0) {
        items.add(
          const _SmartInsight(
            icon: Icons.info_outline_rounded,
            color: AppColors.primary,
            title: 'Savings health',
            message: 'Your savings are positive but currently below 10% of income.',
          ),
        );
      } else {
        items.add(
          const _SmartInsight(
            icon: Icons.warning_amber_rounded,
            color: AppColors.expense,
            title: 'Savings health',
            message: 'Expenses are currently higher than income.',
          ),
        );
      }
    }

    // 2. Spending concentration.
    final categories = _buildCategorySummaries(filteredTransactions);
    if (categories.isNotEmpty && expense > 0) {
      final top = categories.first;
      if (top.percentage >= 40) {
        items.add(
          _SmartInsight(
            icon: Icons.donut_large_rounded,
            color: AppColors.expense,
            title: 'Spending concentration',
            message:
            '${top.name} accounts for ${top.percentage.toStringAsFixed(0)}% of your expenses.',
          ),
        );
      } else {
        items.add(
          _SmartInsight(
            icon: Icons.pie_chart_outline_rounded,
            color: AppColors.primary,
            title: 'Spending pattern',
            message:
            'Your largest category is ${top.name} at ${top.percentage.toStringAsFixed(0)}% of expenses.',
          ),
        );
      }
    }

    // 3. Largest single expense.
    if (expenseTransactions.isNotEmpty) {
      final largest = expenseTransactions.reduce(
            (a, b) => a.amount >= b.amount ? a : b,
      );
      final category = largest.categoryName.trim().isEmpty
          ? 'Uncategorized'
          : largest.categoryName.trim();

      items.add(
        _SmartInsight(
          icon: Icons.receipt_long_rounded,
          color: AppColors.expense,
          title: 'Largest single expense',
          message:
          '${_formatCompactCurrency(largest.amount)} on $category',
        ),
      );
    }

    // 4. Busiest spending day.
    final dailyTotals = <DateTime, double>{};
    for (final transaction in expenseTransactions) {
      final key = DateTime(
        transaction.date.year,
        transaction.date.month,
        transaction.date.day,
      );
      dailyTotals[key] = (dailyTotals[key] ?? 0) + transaction.amount;
    }
    if (dailyTotals.length >= 2) {
      final busiest = dailyTotals.entries.reduce(
            (a, b) => a.value >= b.value ? a : b,
      );
      items.add(
        _SmartInsight(
          icon: Icons.calendar_today_rounded,
          color: AppColors.primary,
          title: 'Highest-spend day',
          message:
          '${DateFormat('d MMM yyyy').format(busiest.key)} — ${_formatCompactCurrency(busiest.value)}',
        ),
      );
    }

    // 5. Activity level.
    final activeDays = _distinctExpenseDays(expenseTransactions);
    if (activeDays > 0) {
      final averagePerActiveDay = expense / activeDays;
      items.add(
        _SmartInsight(
          icon: Icons.speed_rounded,
          color: AppColors.primary,
          title: 'Active-day spending',
          message:
          'Average ${_formatCompactCurrency(averagePerActiveDay)} on each day you spent money.',
        ),
      );
    }

    // 6. Current-period volume compared with the previous period.
    final comparison = _buildComparisonData(allTransactions);
    if (comparison != null) {
      final previousExpense = _calculateExpense(comparison.previousTransactions);
      if (previousExpense > 0) {
        final change = _percentageChange(expense, previousExpense);
        final improved = change <= 0;
        items.add(
          _SmartInsight(
            icon: improved
                ? Icons.arrow_downward_rounded
                : Icons.arrow_upward_rounded,
            color: improved ? AppColors.income : AppColors.expense,
            title: 'Expense trend',
            message:
            '${change.abs().toStringAsFixed(0)}% ${change >= 0 ? 'higher' : 'lower'} than the previous period.',
          ),
        );
      }
    }

    return items.take(6).toList();
  }

  // ============================================================
  // EXPORT / SHARE REPORT
  // ============================================================

  Future<void> _showExportSheet(BuildContext context) async {
    final bloc = context.read<TransactionBloc>();
    final allTransactions = List<TransactionEntity>.from(bloc.state.transactions);
    final filteredTransactions = _filterTransactions(allTransactions);

    if (filteredTransactions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('There is no transaction data to export for this period.'),
        ),
      );
      return;
    }

    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).cardColor,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Export Analytics Report',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _periodDescription(),
                  style: Theme.of(sheetContext).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.share_rounded),
                  title: const Text('Share PDF'),
                  subtitle: const Text('Send the report to another app'),
                  onTap: () => Navigator.pop(sheetContext, 'share'),
                ),
                ListTile(
                  leading: const Icon(Icons.print_rounded),
                  title: const Text('Print / Save PDF'),
                  subtitle: const Text('Open the system print dialog'),
                  onTap: () => Navigator.pop(sheetContext, 'print'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || action == null) return;

    try {
      final bytes = await _buildAnalyticsPdf(
        filteredTransactions,
      );

      if (action == 'share') {
        await Printing.sharePdf(
          bytes: bytes,
          filename: 'moneyflow_analytics_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf',
        );
      } else {
        await Printing.layoutPdf(
          onLayout: (_) async => bytes,
          name: 'MoneyFlow Analytics Report',
          format: PdfPageFormat.a4,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not export report: $e'),
        ),
      );
    }
  }

  Future<Uint8List> _buildAnalyticsPdf(
      List<TransactionEntity> transactions,
      ) async {
    final document = pw.Document();
    final theme = pw.ThemeData.withFont(
      base: pw.Font.helvetica(),
      bold: pw.Font.helveticaBold(),
    );

    final income = _calculateIncome(transactions);
    final expense = _calculateExpense(transactions);
    final net = income - expense;
    final rate = income > 0 ? (net / income) * 100 : 0.0;
    final categories = _buildCategorySummaries(transactions);
    final methods = _buildPaymentMethodSummaries(transactions);
    final wallets = _buildWalletSummaries(transactions);
    final insights = _buildSmartInsightItems(
      allTransactions: transactions,
      filteredTransactions: transactions,
    );

    String amount(double value) => value.toStringAsFixed(2);

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        theme: theme,
        header: (_) => pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 10),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(color: PdfColors.grey300),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'MoneyFlow',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                'Analytics Report',
                style: const pw.TextStyle(fontSize: 11),
              ),
            ],
          ),
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(
              fontSize: 9,
              color: PdfColors.grey600,
            ),
          ),
        ),
        build: (_) => [
          pw.SizedBox(height: 12),
          pw.Text(
            _periodDescription(),
            style: pw.TextStyle(
              fontSize: 11,
              color: PdfColors.grey700,
            ),
          ),
          pw.SizedBox(height: 16),
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(12),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Net Savings',
                  style: pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey700,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  amount(net),
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Savings rate: ${rate.toStringAsFixed(1)}%',
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 14),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            columnWidths: {
              0: const pw.FlexColumnWidth(),
              1: const pw.FlexColumnWidth(),
            },
            children: [
              _pdfSummaryRow('Income', amount(income), 'Expense', amount(expense)),
              _pdfSummaryRow('Transactions', '${transactions.length}', 'Active days', '${_distinctExpenseDays(transactions.where((t) => t.type == TransactionType.expense).toList())}'),
            ],
          ),
          pw.SizedBox(height: 22),
          _pdfSectionTitle('Top Expense Categories'),
          pw.SizedBox(height: 8),
          ...categories.take(8).map(
                (item) => _pdfMetricRow(
              item.name,
              amount(item.amount),
              '${item.percentage.toStringAsFixed(0)}%',
            ),
          ),
          pw.SizedBox(height: 18),
          _pdfSectionTitle('Payment Methods'),
          pw.SizedBox(height: 8),
          ...methods.map(
                (item) => _pdfMetricRow(
              _paymentLabel(item.method),
              amount(item.amount),
              '${item.percentage.toStringAsFixed(0)}%',
            ),
          ),
          if (wallets.isNotEmpty) ...[
            pw.SizedBox(height: 18),
            _pdfSectionTitle('Wallet Spending'),
            pw.SizedBox(height: 8),
            ...wallets.take(8).map(
                  (item) => _pdfMetricRow(
                item.name,
                amount(item.amount),
                '${item.percentage.toStringAsFixed(0)}%',
              ),
            ),
          ],
          if (insights.isNotEmpty) ...[
            pw.SizedBox(height: 18),
            _pdfSectionTitle('Smart Insights'),
            pw.SizedBox(height: 8),
            ...insights.map(
                  (item) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 7),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                      width: 5,
                      height: 5,
                      margin: const pw.EdgeInsets.only(top: 5, right: 7),
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.teal,
                        shape: pw.BoxShape.circle,
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Text(
                        '${item.title}: ${item.message}',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          pw.SizedBox(height: 22),
          pw.Text(
            'Generated ${DateFormat('d MMM yyyy, h:mm a').format(DateTime.now())}',
            style: const pw.TextStyle(
              fontSize: 9,
              color: PdfColors.grey600,
            ),
          ),
        ],
      ),
    );

    final bytes = await document.save();
    return Uint8List.fromList(bytes);
  }

  pw.TableRow _pdfSummaryRow(
      String labelA,
      String valueA,
      String labelB,
      String valueB,
      ) {
    pw.Widget cell(String label, String value) {
      return pw.Padding(
        padding: const pw.EdgeInsets.all(8),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              label,
              style: const pw.TextStyle(
                fontSize: 8,
                color: PdfColors.grey600,
              ),
            ),
            pw.SizedBox(height: 3),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    return pw.TableRow(
      children: [
        cell(labelA, valueA),
        cell(labelB, valueB),
      ],
    );
  }

  pw.Widget _pdfSectionTitle(String title) {
    return pw.Text(
      title,
      style: pw.TextStyle(
        fontSize: 13,
        fontWeight: pw.FontWeight.bold,
      ),
    );
  }

  pw.Widget _pdfMetricRow(
      String title,
      String amount,
      String percentage,
      ) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.grey200),
        ),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Text(
              title,
              style: const pw.TextStyle(fontSize: 10),
            ),
          ),
          pw.SizedBox(width: 10),
          pw.Text(
            percentage,
            style: const pw.TextStyle(
              fontSize: 9,
              color: PdfColors.grey600,
            ),
          ),
          pw.SizedBox(width: 12),
          pw.Text(
            amount,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ERROR
  // ============================================================

  Widget _buildError(
      BuildContext context,
      String? message,
      ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: AppColors.expense,
              size: 50,
            ),
            const SizedBox(height: 16),
            const Text(
              'Could not load analytics',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message ?? 'Something went wrong.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: () {
                context.read<TransactionBloc>().add(
                  const LoadTransactions(),
                );
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}


class _SmartInsight {
  final IconData icon;
  final Color color;
  final String title;
  final String message;

  const _SmartInsight({
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
  });
}

// ================================================================
// CATEGORY SUMMARY DATA
// ================================================================

class _CategorySummary {
  final String name;
  final double amount;
  final int transactionCount;
  final double percentage;

  const _CategorySummary({
    required this.name,
    required this.amount,
    required this.transactionCount,
    required this.percentage,
  });
}

// ================================================================
// PAYMENT METHOD SUMMARY
// ================================================================

class _PaymentMethodSummary {
  final PaymentMethod method;
  final double amount;
  final int transactionCount;
  final double percentage;

  const _PaymentMethodSummary({
    required this.method,
    required this.amount,
    required this.transactionCount,
    required this.percentage,
  });
}

// ================================================================
// WALLET SUMMARY
// ================================================================

class _WalletSummary {
  final String name;
  final double amount;
  final int transactionCount;
  final double percentage;

  const _WalletSummary({
    required this.name,
    required this.amount,
    required this.transactionCount,
    required this.percentage,
  });
}

// ================================================================
// PERIOD COMPARISON DATA
// ================================================================

class _ComparisonData {
  final List<TransactionEntity> previousTransactions;
  final String subtitle;

  const _ComparisonData({
    required this.previousTransactions,
    required this.subtitle,
  });
}

// ================================================================
// TREND DATA
// ================================================================

class _TrendData {
  final String label;
  final double income;
  final double expense;

  const _TrendData({
    required this.label,
    required this.income,
    required this.expense,
  });
}

// ================================================================
// EMPTY ANALYTICS
// ================================================================

class _EmptyAnalytics extends StatelessWidget {
  final String message;

  const _EmptyAnalytics({required this.message});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 180,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bar_chart_rounded,
              size: 42,
              color: AppColors.primary.withValues(alpha: 0.45),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).textTheme.bodyMedium?.color
                    ?.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
