
import '../../../../core/enums/transaction_type.dart';
import '../../budget/domain/entities/budget_entity.dart';
import '../../transactions/domain/entities/transaction_entity.dart';

class FinancialInsightsResult {
  final DateTime month;
  final double income;
  final double expense;
  final double savings;
  final double savingsRate;
  final double averageDailyExpense;
  final String? topCategory;
  final double topCategoryAmount;
  final String? largestExpenseCategory;
  final double largestExpenseAmount;
  final double previousMonthExpense;
  final double expenseChangePercent;
  final double? budgetAmount;
  final double? budgetSpent;
  final double? budgetUtilization;
  final double healthScore;
  final List<FinancialInsight> insights;

  const FinancialInsightsResult({
    required this.month,
    required this.income,
    required this.expense,
    required this.savings,
    required this.savingsRate,
    required this.averageDailyExpense,
    required this.topCategory,
    required this.topCategoryAmount,
    required this.largestExpenseCategory,
    required this.largestExpenseAmount,
    required this.previousMonthExpense,
    required this.expenseChangePercent,
    required this.budgetAmount,
    required this.budgetSpent,
    required this.budgetUtilization,
    required this.healthScore,
    required this.insights,
  });

  bool get hasData => income > 0 || expense > 0;
}

class FinancialInsight {
  final String title;
  final String message;
  final InsightTone tone;

  const FinancialInsight({
    required this.title,
    required this.message,
    required this.tone,
  });
}

enum InsightTone {
  positive,
  warning,
  neutral,
}

class FinancialInsightsCalculator {
  const FinancialInsightsCalculator();

  FinancialInsightsResult calculate({
    required List<TransactionEntity> transactions,
    required List<BudgetEntity> budgets,
    required DateTime month,
  }) {
    final monthStart = DateTime(month.year, month.month);
    final nextMonth = DateTime(month.year, month.month + 1);
    final previousMonth = DateTime(month.year, month.month - 1);

    final monthTransactions = transactions.where((transaction) {
      return !transaction.date.isBefore(monthStart) &&
          transaction.date.isBefore(nextMonth);
    }).toList();

    final previousTransactions = transactions.where((transaction) {
      return !transaction.date.isBefore(previousMonth) &&
          transaction.date.isBefore(monthStart);
    }).toList();

    final income = _sumType(monthTransactions, TransactionType.income);
    final expense = _sumType(monthTransactions, TransactionType.expense);
    final savings = income - expense;
    final double savingsRate = income > 0 ? (savings / income) * 100 : 0.0;

    final previousExpense =
        _sumType(previousTransactions, TransactionType.expense);

    final double expenseChangePercent = previousExpense > 0
        ? ((expense - previousExpense) / previousExpense) * 100
        : 0.0;

    final expenses = monthTransactions
        .where((transaction) => transaction.type == TransactionType.expense)
        .toList();

    final categoryTotals = <String, double>{};
    for (final transaction in expenses) {
      final label = transaction.categoryName.trim().isEmpty
          ? 'Uncategorized'
          : transaction.categoryName.trim();
      categoryTotals[label] =
          (categoryTotals[label] ?? 0) + transaction.amount.toDouble();
    }

    String? topCategory;
    double topCategoryAmount = 0;
    for (final entry in categoryTotals.entries) {
      if (entry.value > topCategoryAmount) {
        topCategory = entry.key;
        topCategoryAmount = entry.value;
      }
    }

    String? largestExpenseCategory;
    double largestExpenseAmount = 0;
    for (final transaction in expenses) {
      if (transaction.amount.toDouble() > largestExpenseAmount) {
        largestExpenseAmount = transaction.amount.toDouble();
        largestExpenseCategory = transaction.categoryName.trim().isEmpty
            ? 'Uncategorized'
            : transaction.categoryName.trim();
      }
    }

    final dayCount = _dayCountForAverage(month, monthTransactions);
    final double averageDailyExpense = dayCount > 0 ? expense / dayCount : 0.0;

    final monthBudgets = budgets.where((budget) {
      return budget.month.year == month.year &&
          budget.month.month == month.month;
    }).toList();

    double? budgetAmount;
    double? budgetSpent;
    double? budgetUtilization;

    if (monthBudgets.isNotEmpty) {
      final totalBudget = monthBudgets.fold<double>(
        0,
        (total, budget) => total + budget.amount.toDouble(),
      );

      double totalBudgetSpent = 0;
      for (final transaction in expenses) {
        for (final budget in monthBudgets) {
          if (_budgetMatchesTransaction(budget, transaction)) {
            totalBudgetSpent += transaction.amount.toDouble();
            break;
          }
        }
      }

      budgetAmount = totalBudget;
      budgetSpent = totalBudgetSpent;

      if (totalBudget > 0) {
        budgetUtilization = (totalBudgetSpent / totalBudget) * 100;
      }
    }

    final healthScore = _healthScore(
      savingsRate: savingsRate,
      expenseChangePercent: expenseChangePercent,
      budgetUtilization: budgetUtilization,
      hasIncome: income > 0,
    );

    final insights = _buildInsights(
      income: income,
      expense: expense,
      savings: savings,
      savingsRate: savingsRate,
      topCategory: topCategory,
      topCategoryAmount: topCategoryAmount,
      previousExpense: previousExpense,
      expenseChangePercent: expenseChangePercent,
      budgetUtilization: budgetUtilization,
    );

    return FinancialInsightsResult(
      month: monthStart,
      income: income,
      expense: expense,
      savings: savings,
      savingsRate: savingsRate,
      averageDailyExpense: averageDailyExpense,
      topCategory: topCategory,
      topCategoryAmount: topCategoryAmount,
      largestExpenseCategory: largestExpenseCategory,
      largestExpenseAmount: largestExpenseAmount,
      previousMonthExpense: previousExpense,
      expenseChangePercent: expenseChangePercent,
      budgetAmount: budgetAmount,
      budgetSpent: budgetSpent,
      budgetUtilization: budgetUtilization,
      healthScore: healthScore,
      insights: insights,
    );
  }

  double _sumType(
    List<TransactionEntity> transactions,
    TransactionType type,
  ) {
    return transactions
        .where((transaction) => transaction.type == type)
        .fold<double>(0, (total, transaction) => total + transaction.amount.toDouble());
  }

  bool _budgetMatchesTransaction(
    BudgetEntity budget,
    TransactionEntity transaction,
  ) {
    if (budget.categoryId.isNotEmpty && transaction.categoryId.isNotEmpty) {
      if (budget.categoryId == transaction.categoryId) {
        return true;
      }
    }

    return budget.categoryName.trim().toLowerCase() ==
        transaction.categoryName.trim().toLowerCase();
  }

  int _dayCountForAverage(
    DateTime month,
    List<TransactionEntity> transactions,
  ) {
    final now = DateTime.now();
    final monthStart = DateTime(month.year, month.month);
    final fullMonthDays = DateTime(month.year, month.month + 1)
        .difference(monthStart)
        .inDays;

    if (month.year == now.year && month.month == now.month) {
      final currentDay = now.day.clamp(1, fullMonthDays);
      return currentDay;
    }

    if (transactions.isNotEmpty) {
      return fullMonthDays;
    }

    return 0;
  }

  double _healthScore({
    required double savingsRate,
    required double expenseChangePercent,
    required double? budgetUtilization,
    required bool hasIncome,
  }) {
    if (!hasIncome) {
      return 0;
    }

    double score = 50;

    // Savings behavior: up to +25 / down to -25.
    if (savingsRate >= 30) {
      score += 25;
    } else if (savingsRate >= 20) {
      score += 18;
    } else if (savingsRate >= 10) {
      score += 10;
    } else if (savingsRate >= 0) {
      score += 2;
    } else {
      score -= 20;
    }

    // Budget discipline: up to +15 / down to -15.
    if (budgetUtilization != null) {
      if (budgetUtilization <= 80) {
        score += 15;
      } else if (budgetUtilization <= 90) {
        score += 8;
      } else if (budgetUtilization <= 100) {
        score += 2;
      } else {
        score -= 15;
      }
    }

    // Expense trend: up to +10 / down to -10.
    if (expenseChangePercent <= -10) {
      score += 10;
    } else if (expenseChangePercent <= 0) {
      score += 6;
    } else if (expenseChangePercent <= 10) {
      score += 2;
    } else if (expenseChangePercent <= 25) {
      score -= 5;
    } else {
      score -= 10;
    }

    return score.clamp(0, 100).toDouble();
  }

  List<FinancialInsight> _buildInsights({
    required double income,
    required double expense,
    required double savings,
    required double savingsRate,
    required String? topCategory,
    required double topCategoryAmount,
    required double previousExpense,
    required double expenseChangePercent,
    required double? budgetUtilization,
  }) {
    final result = <FinancialInsight>[];

    if (income <= 0 && expense <= 0) {
      result.add(
        const FinancialInsight(
          title: 'Start tracking',
          message:
              'Add a few income and expense entries to unlock useful financial patterns.',
          tone: InsightTone.neutral,
        ),
      );
      return result;
    }

    if (savings < 0) {
      result.add(
        const FinancialInsight(
          title: 'Spending is above income',
          message:
              'Your expenses are higher than your income for this month. Review your largest categories first.',
          tone: InsightTone.warning,
        ),
      );
    } else if (savingsRate >= 20) {
      result.add(
        FinancialInsight(
          title: 'Strong saving rate',
          message:
              'You are keeping ${savingsRate.toStringAsFixed(0)}% of your income after expenses. That is a healthy amount to keep building.',
          tone: InsightTone.positive,
        ),
      );
    } else {
      result.add(
        FinancialInsight(
          title: 'Room to save more',
          message:
              'Your current saving rate is ${savingsRate.toStringAsFixed(0)}%. Look for one recurring expense category you can reduce.',
          tone: InsightTone.neutral,
        ),
      );
    }

    if (previousExpense > 0) {
      if (expenseChangePercent <= -10) {
        result.add(
          FinancialInsight(
            title: 'Spending is down',
            message:
                'Your expenses are ${expenseChangePercent.abs().toStringAsFixed(0)}% lower than the previous month.',
            tone: InsightTone.positive,
          ),
        );
      } else if (expenseChangePercent >= 15) {
        result.add(
          FinancialInsight(
            title: 'Spending increased',
            message:
                'Your expenses are ${expenseChangePercent.toStringAsFixed(0)}% higher than the previous month. Check what changed in your top category.',
            tone: InsightTone.warning,
          ),
        );
      }
    }

    if (topCategory != null && topCategoryAmount > 0 && expense > 0) {
      final share = (topCategoryAmount / expense) * 100;
      result.add(
        FinancialInsight(
          title: 'Top spending category',
          message:
              '$topCategory uses ${share.toStringAsFixed(0)}% of your monthly expenses. This is the first category to review when you want to cut spending.',
          tone: share >= 40 ? InsightTone.warning : InsightTone.neutral,
        ),
      );
    }

    if (budgetUtilization != null) {
      if (budgetUtilization <= 80) {
        result.add(
          FinancialInsight(
            title: 'Budget is on track',
            message:
                'You have used ${budgetUtilization.toStringAsFixed(0)}% of your planned budget.',
            tone: InsightTone.positive,
          ),
        );
      } else if (budgetUtilization <= 100) {
        result.add(
          FinancialInsight(
            title: 'Budget needs attention',
            message:
                'You have used ${budgetUtilization.toStringAsFixed(0)}% of your planned budget. Keep an eye on the remaining days.',
            tone: InsightTone.neutral,
          ),
        );
      } else {
        result.add(
          FinancialInsight(
            title: 'Budget exceeded',
            message:
                'You have used ${budgetUtilization.toStringAsFixed(0)}% of your planned budget. Consider tightening spending for the rest of the month.',
            tone: InsightTone.warning,
          ),
        );
      }
    } else {
      result.add(
        const FinancialInsight(
          title: 'Set a budget',
          message:
              'Monthly budgets make these insights more useful because you can compare actual spending against a target.',
          tone: InsightTone.neutral,
        ),
      );
    }

    return result.take(5).toList();
  }
}
