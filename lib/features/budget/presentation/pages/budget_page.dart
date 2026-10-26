import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/currency/currency_cubit.dart';
import '../../../../core/currency/currency_state.dart';
import '../../../../core/enums/app_currency.dart';
import '../../../../core/enums/category_type.dart';
import '../../../../core/enums/transaction_type.dart';
import '../../../../core/utils/currency_formatter.dart';

import '../../../categories/domain/entities/category_entity.dart';
import '../../../categories/presentation/bloc/category_bloc.dart';
import '../../../categories/presentation/bloc/category_event.dart';
import '../../../categories/presentation/bloc/category_state.dart';

import '../../../transactions/domain/entities/transaction_entity.dart';
import '../../../transactions/presentation/bloc/transaction_bloc.dart';
import '../../../transactions/presentation/bloc/transaction_event.dart';
import '../../../transactions/presentation/bloc/transaction_state.dart';

import '../../../wallet/domain/entities/wallet_entity.dart';
import '../../../wallet/presentation/bloc/wallet_bloc.dart';
import '../../../wallet/presentation/bloc/wallet_event.dart';

import '../../domain/entities/budget_entity.dart';
import '../bloc/budget_bloc.dart';
import '../bloc/budget_event.dart';
import '../bloc/budget_state.dart';

import 'budget_analytics_page.dart';

class BudgetPage extends StatefulWidget {
  const BudgetPage({super.key});

  @override
  State<BudgetPage> createState() => _BudgetPageState();
}

class _BudgetPageState extends State<BudgetPage> {
  DateTime _selectedMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
  );

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BudgetBloc>().add(
        const LoadBudgets(),
      );

      context.read<CategoryBloc>().add(
        const LoadCategories(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Budget',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Budget analytics',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const BudgetAnalyticsPage(),
                ),
              );
            },
            icon: const Icon(
              Icons.insights_rounded,
            ),
          ),
          IconButton(
            tooltip: 'Carry forward previous month budgets',
            onPressed: () {
              _copyPreviousMonthBudgets(context);
            },
            icon: const Icon(
              Icons.history_rounded,
            ),
          ),
          IconButton(
            onPressed: () {
              _showBudgetDialog(context);
            },
            icon: const Icon(
              Icons.add_rounded,
            ),
          ),
        ],
      ),
      body: BlocBuilder<BudgetBloc, BudgetState>(
        builder: (context, budgetState) {
          return BlocBuilder<TransactionBloc, TransactionState>(
            builder: (context, transactionState) {
              final budgets = budgetState.budgets
                  .where(
                    (budget) =>
                budget.month.year ==
                    _selectedMonth.year &&
                    budget.month.month ==
                        _selectedMonth.month,
              )
                  .toList();

              final expenses = transactionState.transactions
                  .where(
                    (transaction) =>
                transaction.type ==
                    TransactionType.expense &&
                    transaction.date.year ==
                        _selectedMonth.year &&
                    transaction.date.month ==
                        _selectedMonth.month,
              )
                  .toList();

              final totalBudget = budgets.fold<double>(
                0,
                    (total, budget) =>
                total + budget.amount,
              );

              final totalSpent = expenses
                  .where(
                    (transaction) {
                  for (final budget in budgets) {
                    if (budget.categoryId.isNotEmpty &&
                        transaction.categoryId.isNotEmpty &&
                        budget.categoryId ==
                            transaction.categoryId) {
                      return true;
                    }

                    if (transaction.categoryName
                        .trim()
                        .toLowerCase() ==
                        budget.categoryName
                            .trim()
                            .toLowerCase()) {
                      return true;
                    }
                  }

                  return false;
                },
              )
                  .fold<double>(
                0,
                    (total, transaction) =>
                total + transaction.amount,
              );

              final remaining =
                  totalBudget - totalSpent;

              return RefreshIndicator(
                onRefresh: () async {
                  context.read<BudgetBloc>().add(
                    const LoadBudgets(),
                  );

                  context.read<CategoryBloc>().add(
                    const LoadCategories(),
                  );

                  context.read<TransactionBloc>().add(
                    const LoadTransactions(),
                  );

                  context.read<WalletBloc>().add(
                    const LoadWallets(),
                  );

                  await Future.delayed(
                    const Duration(
                      milliseconds: 400,
                    ),
                  );
                },
                child: ListView(
                  physics:
                  const AlwaysScrollableScrollPhysics(
                    parent:
                    BouncingScrollPhysics(),
                  ),
                  padding:
                  const EdgeInsets.fromLTRB(
                    20,
                    8,
                    20,
                    110,
                  ),
                  children: [
                    _buildOverview(
                      context,
                      totalBudget: totalBudget,
                      totalSpent: totalSpent,
                      remaining: remaining,
                    ),

                    const SizedBox(height: 20),

                    _buildMonthSelector(
                      context,
                    ),

                    const SizedBox(height: 24),

                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            DateFormat(
                              'MMMM yyyy',
                            ).format(
                              _selectedMonth,
                            ),
                            style: Theme.of(
                              context,
                            )
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                              fontWeight:
                              FontWeight.w800,
                            ),
                          ),
                        ),
                        Text(
                          '${budgets.length} budgets',
                          style: Theme.of(
                            context,
                          )
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                            color: Theme.of(
                              context,
                            )
                                .textTheme
                                .bodySmall
                                ?.color
                                ?.withValues(
                              alpha: 0.55,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    if (budgetState.status ==
                        BudgetStatus.loading &&
                        budgets.isEmpty)
                      const Padding(
                        padding:
                        EdgeInsets.symmetric(
                          vertical: 40,
                        ),
                        child: Center(
                          child:
                          CircularProgressIndicator(),
                        ),
                      )
                    else if (budgets.isEmpty)
                      _buildEmpty(context)
                    else
                      ...budgets.map(
                            (budget) {
                          final spent =
                          _getBudgetSpent(
                            budget,
                            expenses,
                          );

                          final category =
                          _findCategory(
                            context,
                            budget.categoryId,
                            budget.categoryName,
                          );

                          return Padding(
                            padding:
                            const EdgeInsets
                                .only(
                              bottom: 12,
                            ),
                            child: _BudgetCard(
                              budget: budget,
                              spent: spent,
                              category: category,
                              onEdit: () {
                                _showBudgetDialog(
                                  context,
                                  existingBudget:
                                  budget,
                                );
                              },
                              onDelete: () {
                                _confirmDelete(
                                  context,
                                  budget,
                                );
                              },
                            ),
                          );
                        },
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

  // ============================================================
  // FIND CATEGORY
  // ============================================================

  CategoryEntity? _findCategory(
      BuildContext context,
      String categoryId,
      String categoryName,
      ) {
    final categories =
        context.read<CategoryBloc>().state.categories;

    // First try the actual Firebase category ID.
    for (final category in categories) {
      if (category.id == categoryId) {
        return category;
      }
    }

    // Fallback for older records.
    for (final category in categories) {
      if (category.name
          .trim()
          .toLowerCase() ==
          categoryName.trim().toLowerCase()) {
        return category;
      }
    }

    return null;
  }

  // ============================================================
  // MONTH SELECTOR
  // ============================================================

  Widget _buildMonthSelector(
      BuildContext context,
      ) {
    final theme =
    Theme.of(context);

    final isDark =
        theme.brightness ==
            Brightness.dark;

    return Container(
      padding:
      const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 6,
      ),
      decoration:
      BoxDecoration(
        color: isDark
            ? AppColors.darkSurface
            : AppColors.lightSurface,
        borderRadius:
        BorderRadius.circular(18),
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
                _selectedMonth =
                    DateTime(
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
                ).format(
                  _selectedMonth,
                ),
                style:
                const TextStyle(
                  fontWeight:
                  FontWeight.w800,
                ),
              ),
            ),
          ),

          IconButton(
            onPressed: () {
              setState(() {
                _selectedMonth =
                    DateTime(
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

  // ============================================================
  // OVERVIEW
  // ============================================================

  Widget _buildOverview(
      BuildContext context, {
        required double totalBudget,
        required double totalSpent,
        required double remaining,
      }) {
    final progress = totalBudget > 0
        ? (totalSpent / totalBudget)
        .clamp(
      0.0,
      1.0,
    )
        .toDouble()
        : 0.0;

    return Container(
      padding:
      const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient:
        const LinearGradient(
          begin:
          Alignment.topLeft,
          end:
          Alignment.bottomRight,
          colors: [
            AppColors.primary,
            AppColors.primaryDark,
          ],
        ),
        borderRadius:
        BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Text(
            'Monthly Budget',
            style: TextStyle(
              color: Colors.white
                  .withValues(
                alpha: 0.70,
              ),
              fontSize: 13,
              fontWeight:
              FontWeight.w600,
            ),
          ),

          const SizedBox(height: 7),

          BlocBuilder<
              CurrencyCubit,
              CurrencyState>(
            builder:
                (
                context,
                currencyState,
                ) {
              return Text(
                CurrencyFormatter
                    .formatCompact(
                  totalBudget,
                  currencyState
                      .currency,
                ),
                style:
                const TextStyle(
                  color:
                  Colors.white,
                  fontSize: 30,
                  fontWeight:
                  FontWeight.w800,
                ),
              );
            },
          ),

          const SizedBox(height: 20),

          ClipRRect(
            borderRadius:
            BorderRadius.circular(
              10,
            ),
            child:
            LinearProgressIndicator(
              minHeight: 8,
              value: progress,
              backgroundColor:
              Colors.white
                  .withValues(
                alpha: 0.14,
              ),
              color: Colors.white,
            ),
          ),

          const SizedBox(height: 18),

          Row(
            children: [
              Expanded(
                child: _OverviewItem(
                  title: 'Spent',
                  amount: totalSpent,
                ),
              ),
              Expanded(
                child: _OverviewItem(
                  title: 'Remaining',
                  amount: remaining,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // EMPTY
  // ============================================================

  Widget _buildEmpty(
      BuildContext context,
      ) {
    final theme =
    Theme.of(context);

    return Container(
      padding:
      const EdgeInsets.all(30),
      decoration:
      BoxDecoration(
        color: theme.brightness ==
            Brightness.dark
            ? AppColors.darkSurface
            : AppColors.lightSurface,
        borderRadius:
        BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration:
            BoxDecoration(
              color:
              AppColors.primary
                  .withValues(
                alpha: 0.10,
              ),
              shape:
              BoxShape.circle,
            ),
            child: const Icon(
              Icons
                  .account_balance_wallet_rounded,
              color:
              AppColors.primary,
              size: 32,
            ),
          ),

          const SizedBox(height: 16),

          Text(
            'No budgets yet',
            style: theme.textTheme
                .titleMedium
                ?.copyWith(
              fontWeight:
              FontWeight.w800,
            ),
          ),

          const SizedBox(height: 7),

          Text(
            'Create a budget using one of your expense categories.',
            textAlign:
            TextAlign.center,
            style: theme.textTheme
                .bodySmall
                ?.copyWith(
              color: theme
                  .textTheme
                  .bodySmall
                  ?.color
                  ?.withValues(
                alpha: 0.55,
              ),
            ),
          ),

          const SizedBox(height: 18),

          ElevatedButton.icon(
            onPressed: () {
              _showBudgetDialog(
                context,
              );
            },
            icon: const Icon(
              Icons.add_rounded,
            ),
            label: const Text(
              'Create Budget',
            ),
          ),

          const SizedBox(height: 10),

          OutlinedButton.icon(
            onPressed: () {
              _copyPreviousMonthBudgets(context);
            },
            icon: const Icon(
              Icons.history_rounded,
            ),
            label: const Text(
              'Carry Forward Previous Month',
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CATEGORY SPENDING
  // ============================================================

  double _getBudgetSpent(
      BudgetEntity budget,
      List<TransactionEntity>
      transactions,
      ) {
    return transactions
        .where(
          (transaction) {
        if (budget
            .categoryId
            .isNotEmpty &&
            transaction
                .categoryId
                .isNotEmpty &&
            budget.categoryId ==
                transaction
                    .categoryId) {
          return true;
        }

        return transaction
            .categoryName
            .trim()
            .toLowerCase() ==
            budget.categoryName
                .trim()
                .toLowerCase();
      },
    )
        .fold<double>(
      0,
          (
          total,
          transaction,
          ) =>
      total +
          transaction.amount,
    );
  }

  // ============================================================
  // DUPLICATE CHECK
  // ============================================================

  bool _hasDuplicateBudget({
    required List<BudgetEntity>
    budgets,
    required String categoryId,
    required String categoryName,
    String? editingBudgetId,
  }) {
    for (final budget in budgets) {
      // Ignore the budget currently being edited.
      if (editingBudgetId != null &&
          budget.id ==
              editingBudgetId) {
        continue;
      }

      // Category ID match.
      if (categoryId.isNotEmpty &&
          budget.categoryId.isNotEmpty &&
          budget.categoryId ==
              categoryId) {
        return true;
      }

      // Category name fallback.
      if (budget.categoryName
          .trim()
          .toLowerCase() ==
          categoryName
              .trim()
              .toLowerCase()) {
        return true;
      }
    }

    return false;
  }

  // ============================================================
  // CURRENT AVAILABLE BALANCE
  // ============================================================

  double _calculateAvailableBalance(
      List<WalletEntity> wallets,
      List<TransactionEntity>
      transactions,
      ) {
    final balances =
    <String, double>{};

    // Start with initial wallet balances.
    for (final wallet in wallets) {
      balances[wallet.id] =
          wallet.initialBalance;
    }

    // Apply all transactions.
    for (final transaction
    in transactions) {
      switch (transaction.type) {
      // ------------------------------------------------------
      // INCOME
      // ------------------------------------------------------

        case TransactionType.income:
          final walletId =
              transaction.walletId;

          if (walletId != null &&
              walletId.isNotEmpty &&
              balances
                  .containsKey(
                  walletId)) {
            balances[walletId] =
                (balances[walletId] ??
                    0) +
                    transaction.amount;
          }
          break;

      // ------------------------------------------------------
      // EXPENSE
      // ------------------------------------------------------

        case TransactionType.expense:
          final walletId =
              transaction.walletId;

          if (walletId != null &&
              walletId.isNotEmpty &&
              balances
                  .containsKey(
                  walletId)) {
            balances[walletId] =
                (balances[walletId] ??
                    0) -
                    transaction.amount;
          }
          break;

      // ------------------------------------------------------
      // TRANSFER
      // ------------------------------------------------------

        case TransactionType
            .transfer:
          final fromWalletId =
              transaction
                  .fromWalletId;

          final toWalletId =
              transaction
                  .toWalletId;

          if (fromWalletId != null &&
              fromWalletId
                  .isNotEmpty &&
              balances.containsKey(
                fromWalletId,
              )) {
            balances[
            fromWalletId] =
                (balances[
                fromWalletId] ??
                    0) -
                    transaction
                        .amount;
          }

          if (toWalletId != null &&
              toWalletId
                  .isNotEmpty &&
              balances.containsKey(
                toWalletId,
              )) {
            balances[toWalletId] =
                (balances[toWalletId] ??
                    0) +
                    transaction
                        .amount;
          }
          break;
      }
    }

    return balances.values
        .fold<double>(
      0,
          (total, value) =>
      total + value,
    );
  }

  // ============================================================
  // ADD / EDIT BUDGET
  // ============================================================

  void _showBudgetDialog(
      BuildContext context, {
        BudgetEntity? existingBudget,
      }) {
    final monthBudgets =
    context
        .read<BudgetBloc>()
        .state
        .budgets
        .where(
          (budget) =>
      budget.month.year ==
          _selectedMonth
              .year &&
          budget.month.month ==
              _selectedMonth
                  .month,
    )
        .toList();

    showDialog<void>(
      context: context,
      builder: (_) {
        return _BudgetEditorDialog(
          existingBudget:
          existingBudget,
          selectedMonth:
          _selectedMonth,
          existingBudgets:
          monthBudgets,
        );
      },
    );
  }

  // ============================================================
  // CARRY FORWARD PREVIOUS MONTH BUDGETS
  // ============================================================

  Future<void> _copyPreviousMonthBudgets(
      BuildContext context,
      ) async {
    final budgetState = context.read<BudgetBloc>().state;

    final previousMonth = DateTime(
      _selectedMonth.year,
      _selectedMonth.month - 1,
    );

    final previousBudgets = budgetState.budgets
        .where(
          (budget) =>
      budget.month.year == previousMonth.year &&
          budget.month.month == previousMonth.month,
    )
        .toList();

    if (previousBudgets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No budgets found for ${DateFormat('MMMM yyyy').format(previousMonth)}.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final currentBudgets = budgetState.budgets
        .where(
          (budget) =>
      budget.month.year == _selectedMonth.year &&
          budget.month.month == _selectedMonth.month,
    )
        .toList();

    final budgetsToCopy = <BudgetEntity>[];

    for (final previousBudget in previousBudgets) {
      final alreadyExists = currentBudgets.any((currentBudget) {
        if (previousBudget.categoryId.isNotEmpty &&
            currentBudget.categoryId.isNotEmpty &&
            previousBudget.categoryId == currentBudget.categoryId) {
          return true;
        }

        return previousBudget.categoryName.trim().toLowerCase() ==
            currentBudget.categoryName.trim().toLowerCase();
      });

      if (!alreadyExists) {
        budgetsToCopy.add(previousBudget);
      }
    }

    if (budgetsToCopy.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'All budgets from ${DateFormat('MMMM yyyy').format(previousMonth)} '
                'already exist for ${DateFormat('MMMM yyyy').format(_selectedMonth)}.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final currency = context.read<CurrencyCubit>().state.currency;

    final shouldCopy = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text(
            'Carry Forward Budgets?',
            style: TextStyle(
              fontWeight: FontWeight.w800,
            ),
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Copy ${budgetsToCopy.length} budget${budgetsToCopy.length == 1 ? '' : 's'} from '
                        '${DateFormat('MMMM yyyy').format(previousMonth)} to '
                        '${DateFormat('MMMM yyyy').format(_selectedMonth)}?',
                    style: const TextStyle(height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  ...budgetsToCopy.map(
                        (budget) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.account_balance_wallet_outlined,
                              color: AppColors.primary,
                              size: 19,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              budget.categoryName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            CurrencyFormatter.formatCompact(
                              budget.amount,
                              currency,
                            ),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              child: const Text('Carry Forward'),
            ),
          ],
        );
      },
    );

    if (shouldCopy != true || !context.mounted) {
      return;
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User is not authenticated'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final bloc = context.read<BudgetBloc>();
    final targetMonth = DateTime(
      _selectedMonth.year,
      _selectedMonth.month,
    );

    for (final previousBudget in budgetsToCopy) {
      final copiedBudget = BudgetEntity(
        id: '',
        userId: user.uid,
        categoryId: previousBudget.categoryId,
        categoryName: previousBudget.categoryName,
        amount: previousBudget.amount,
        month: targetMonth,
        createdAt: DateTime.now(),
      );

      bloc.add(AddBudgetEvent(copiedBudget));
    }

    final skippedCount = previousBudgets.length - budgetsToCopy.length;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Copied ${budgetsToCopy.length} budget${budgetsToCopy.length == 1 ? '' : 's'} '
              'to ${DateFormat('MMMM yyyy').format(targetMonth)}'
              '${skippedCount > 0 ? ' • $skippedCount already existed' : ''}.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ============================================================
  // DELETE
  // ============================================================

  Future<void> _confirmDelete(
      BuildContext context,
      BudgetEntity budget,
      ) async {
    final confirmed =
    await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Delete Budget?',
            style:
            TextStyle(
              fontWeight:
              FontWeight.w800,
            ),
          ),
          content: Text(
            'Delete the budget for "${budget.categoryName}"?',
          ),
          shape:
          RoundedRectangleBorder(
            borderRadius:
            BorderRadius.circular(
              22,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child:
              const Text(
                'Cancel',
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              style:
              ElevatedButton
                  .styleFrom(
                backgroundColor:
                AppColors
                    .expense,
                foregroundColor:
                Colors.white,
                elevation: 0,
              ),
              child:
              const Text(
                'Delete',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true ||
        !context.mounted) {
      return;
    }

    context
        .read<BudgetBloc>()
        .add(
      DeleteBudgetEvent(
        budget.id,
      ),
    );
  }
}

// ============================================================
// BUDGET EDITOR
// ============================================================

class _BudgetEditorDialog
    extends StatefulWidget {
  final BudgetEntity? existingBudget;
  final DateTime selectedMonth;
  final List<BudgetEntity>
  existingBudgets;

  const _BudgetEditorDialog({
    required this.existingBudget,
    required this.selectedMonth,
    required this.existingBudgets,
  });

  @override
  State<
      _BudgetEditorDialog>createState() =>
      _BudgetEditorDialogState();
}

class _BudgetEditorDialogState
    extends State<
        _BudgetEditorDialog> {
  late final
  TextEditingController
  _amountController;

  String? _selectedCategoryId;
  String? _selectedCategoryName;

  @override
  void initState() {
    super.initState();

    _amountController =
        TextEditingController(
          text: widget.existingBudget
              ?.amount
              .toString() ??
              '',
        );

    _selectedCategoryId =
        widget.existingBudget
            ?.categoryId;

    _selectedCategoryName =
        widget.existingBudget
            ?.categoryName;
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(
      BuildContext context,
      ) {
    final theme =
    Theme.of(context);

    final isDark =
        theme.brightness ==
            Brightness.dark;

    final isEditing =
        widget.existingBudget !=
            null;

    return AlertDialog(
      title: Text(
        isEditing
            ? 'Edit Budget'
            : 'Create Budget',
        style:
        const TextStyle(
          fontWeight:
          FontWeight.w800,
        ),
      ),
      shape:
      RoundedRectangleBorder(
        borderRadius:
        BorderRadius.circular(
          24,
        ),
      ),
      content:
      ConstrainedBox(
        constraints:
        const BoxConstraints(
          maxWidth: 430,
        ),
        child:
        SingleChildScrollView(
          child: BlocBuilder<
              CategoryBloc,
              CategoryState>(
            builder: (
                context,
                categoryState,
                ) {
              final allExpenseCategories = categoryState.categories
                  .where((category) => category.type == CategoryType.expense)
                  .toList();

              final selectedMonth = DateTime(
                widget.selectedMonth.year,
                widget.selectedMonth.month,
              );

              final categories = allExpenseCategories.where((category) {
                final hasBudget = widget.existingBudgets.any((budget) {
                  // Ignore the budget currently being edited.
                  if (widget.existingBudget != null &&
                      budget.id == widget.existingBudget!.id) {
                    return false;
                  }

                  // Check month.
                  final sameMonth =
                      budget.month.year == selectedMonth.year &&
                          budget.month.month == selectedMonth.month;

                  if (!sameMonth) {
                    return false;
                  }

                  // Match by category ID.
                  if (budget.categoryId.isNotEmpty &&
                      category.id.isNotEmpty &&
                      budget.categoryId == category.id) {
                    return true;
                  }

                  // Fallback for older budgets.
                  return budget.categoryName.trim().toLowerCase() ==
                      category.name.trim().toLowerCase();
                });

                return !hasBudget;
              }).toList();

              // ------------------------------------------------
              // FIND EXISTING CATEGORY
              // ------------------------------------------------

              CategoryEntity?
              existingCategory;

              for (final category
              in categories) {
                if (category.id ==
                    _selectedCategoryId) {
                  existingCategory =
                      category;
                  break;
                }
              }

              // Fallback to name.
              if (existingCategory ==
                  null &&
                  _selectedCategoryName !=
                      null) {
                for (final category
                in categories) {
                  if (category.name
                      .trim()
                      .toLowerCase() ==
                      _selectedCategoryName!
                          .trim()
                          .toLowerCase()) {
                    existingCategory =
                        category;
                    break;
                  }
                }
              }

              final validSelectedId =
                  existingCategory
                      ?.id;

              return Column(
                mainAxisSize:
                MainAxisSize.min,
                crossAxisAlignment:
                CrossAxisAlignment
                    .start,
                children: [
                  // ==================================================
                  // CATEGORY
                  // ==================================================

                  const Text(
                    'Category',
                    style:
                    TextStyle(
                      fontWeight:
                      FontWeight.w700,
                    ),
                  ),

                  const SizedBox(
                    height: 8,
                  ),

                  if (categoryState
                      .status ==
                      CategoryStatus
                          .loading &&
                      categories.isEmpty)
                    Container(
                      height: 56,
                      alignment:
                      Alignment.center,
                      decoration:
                      BoxDecoration(
                        color: isDark
                            ? AppColors
                            .darkSurface
                            : AppColors
                            .lightSurface,
                        borderRadius:
                        BorderRadius
                            .circular(
                          14,
                        ),
                      ),
                      child:
                      const SizedBox(
                        width: 22,
                        height: 22,
                        child:
                        CircularProgressIndicator(
                          strokeWidth:
                          2.5,
                        ),
                      ),
                    )
                  else if (categories.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.expense.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        allExpenseCategories.isEmpty
                            ? 'No expense categories found. Create one from Manage → Categories.'
                            : 'All expense categories already have a budget for '
                            '${DateFormat('MMMM yyyy').format(selectedMonth)}.',
                        style: const TextStyle(fontSize: 13),
                      ),
                    )
                  else
                    DropdownButtonFormField<
                        String>(
                      isExpanded: true,
                      initialValue:
                      validSelectedId,
                      decoration:
                      InputDecoration(
                        prefixIcon:
                        const Icon(
                          Icons
                              .category_rounded,
                        ),
                        filled:
                        true,
                        fillColor: isDark
                            ? AppColors
                            .darkSurface
                            : AppColors
                            .lightSurface,
                        border:
                        OutlineInputBorder(
                          borderRadius:
                          BorderRadius
                              .circular(
                            14,
                          ),
                          borderSide:
                          BorderSide
                              .none,
                        ),
                      ),
                      hint:
                      const Text(
                        'Select expense category',
                      ),
                      items:
                      categories.map(
                            (
                            category,
                            ) {
                          final categoryColor =
                          Color(
                            category
                                .colorValue,
                          );

                          final categoryIcon =
                          IconData(
                            category
                                .iconCodePoint,
                            fontFamily:
                            'MaterialIcons',
                          );

                          return DropdownMenuItem<
                              String>(
                            value:
                            category.id,
                            child: Row(
                              children: [
                                Container(
                                  width: 30,
                                  height: 30,
                                  decoration:
                                  BoxDecoration(
                                    color: categoryColor
                                        .withValues(
                                      alpha: 0.12,
                                    ),
                                    shape:
                                    BoxShape.circle,
                                  ),
                                  child:
                                  Icon(
                                    categoryIcon,
                                    size: 16,
                                    color:
                                    categoryColor,
                                  ),
                                ),
                                const SizedBox(
                                  width: 10,
                                ),
                                Expanded(
                                  child:
                                  Text(
                                    category
                                        .name,
                                    maxLines:
                                    1,
                                    overflow:
                                    TextOverflow
                                        .ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ).toList(),
                      onChanged:
                          (value) {
                        if (value ==
                            null) {
                          return;
                        }

                        CategoryEntity?
                        selectedCategory;

                        for (final item
                        in categories) {
                          if (item.id ==
                              value) {
                            selectedCategory =
                                item;
                            break;
                          }
                        }

                        if (selectedCategory ==
                            null) {
                          return;
                        }

                        setState(() {
                          _selectedCategoryId =
                              selectedCategory!
                                  .id;

                          _selectedCategoryName =
                              selectedCategory!
                                  .name;
                        });
                      },
                    ),

                  const SizedBox(
                    height: 18,
                  ),

                  // ==================================================
                  // AMOUNT
                  // ==================================================

                  const Text(
                    'Budget Amount',
                    style:
                    TextStyle(
                      fontWeight:
                      FontWeight.w700,
                    ),
                  ),

                  const SizedBox(
                    height: 8,
                  ),

                  BlocBuilder<
                      CurrencyCubit,
                      CurrencyState>(
                    builder: (
                        context,
                        currencyState,
                        ) {
                      return TextField(
                        controller:
                        _amountController,
                        keyboardType:
                        const TextInputType
                            .numberWithOptions(
                          decimal: true,
                        ),
                        decoration:
                        InputDecoration(
                          prefixText:
                          '${currencyState.currency.symbol} ',
                          hintText:
                          '0.00',
                          filled: true,
                          fillColor:
                          isDark
                              ? AppColors
                              .darkSurface
                              : AppColors
                              .lightSurface,
                          border:
                          OutlineInputBorder(
                            borderRadius:
                            BorderRadius
                                .circular(
                              14,
                            ),
                            borderSide:
                            BorderSide
                                .none,
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(
                    height: 12,
                  ),

                  Text(
                    'Budget month: ${DateFormat('MMMM yyyy').format(widget.selectedMonth)}',
                    style: theme
                        .textTheme
                        .bodySmall
                        ?.copyWith(
                      color: theme
                          .textTheme
                          .bodySmall
                          ?.color
                          ?.withValues(
                        alpha: 0.55,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(
              context,
            );
          },
          child:
          const Text(
            'Cancel',
          ),
        ),
        ElevatedButton(
          onPressed: _save,
          style:
          ElevatedButton
              .styleFrom(
            backgroundColor:
            AppColors.primary,
            foregroundColor:
            Colors.white,
            elevation: 0,
          ),
          child: Text(
            isEditing
                ? 'Update'
                : 'Create',
          ),
        ),
      ],
    );
  }

  // ============================================================
  // DUPLICATE CHECK
  // ============================================================

  bool _hasDuplicateBudget() {
    if (_selectedCategoryId ==
        null ||
        _selectedCategoryName ==
            null) {
      return false;
    }

    for (final budget
    in widget.existingBudgets) {
      // Ignore currently edited budget.
      if (widget.existingBudget !=
          null &&
          budget.id ==
              widget.existingBudget!
                  .id) {
        continue;
      }

      if (_selectedCategoryId!
          .isNotEmpty &&
          budget.categoryId
              .isNotEmpty &&
          budget.categoryId ==
              _selectedCategoryId) {
        return true;
      }

      if (budget.categoryName
          .trim()
          .toLowerCase() ==
          _selectedCategoryName!
              .trim()
              .toLowerCase()) {
        return true;
      }
    }

    return false;
  }

  // ============================================================
  // CURRENT AVAILABLE BALANCE
  // ============================================================

  double _calculateAvailableBalance() {
    final walletState =
        context.read<WalletBloc>().state;

    final transactionState =
        context
            .read<TransactionBloc>()
            .state;

    final balances =
    <String, double>{};

    for (final wallet
    in walletState.wallets) {
      balances[wallet.id] =
          wallet.initialBalance;
    }

    for (final transaction
    in transactionState
        .transactions) {
      switch (transaction.type) {
        case TransactionType.income:
          final walletId =
              transaction.walletId;

          if (walletId != null &&
              walletId.isNotEmpty &&
              balances
                  .containsKey(
                  walletId)) {
            balances[walletId] =
                (balances[walletId] ??
                    0) +
                    transaction.amount;
          }
          break;

        case TransactionType.expense:
          final walletId =
              transaction.walletId;

          if (walletId != null &&
              walletId.isNotEmpty &&
              balances
                  .containsKey(
                  walletId)) {
            balances[walletId] =
                (balances[walletId] ??
                    0) -
                    transaction.amount;
          }
          break;

        case TransactionType
            .transfer:
          final fromWalletId =
              transaction
                  .fromWalletId;

          final toWalletId =
              transaction
                  .toWalletId;

          if (fromWalletId != null &&
              fromWalletId
                  .isNotEmpty &&
              balances.containsKey(
                fromWalletId,
              )) {
            balances[
            fromWalletId] =
                (balances[
                fromWalletId] ??
                    0) -
                    transaction.amount;
          }

          if (toWalletId != null &&
              toWalletId
                  .isNotEmpty &&
              balances.containsKey(
                toWalletId,
              )) {
            balances[toWalletId] =
                (balances[toWalletId] ??
                    0) +
                    transaction.amount;
          }

          break;
      }
    }

    return balances.values
        .fold<double>(
      0,
          (total, value) =>
      total + value,
    );
  }

  // ============================================================
  // SAVE
  // ============================================================

  Future<void> _save() async {
    final amount =
    double.tryParse(
      _amountController.text
          .trim(),
    );

    // ----------------------------------------------------------
    // AMOUNT VALIDATION
    // ----------------------------------------------------------

    if (amount == null ||
        amount <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content: Text(
            'Enter a valid budget amount',
          ),
          behavior:
          SnackBarBehavior
              .floating,
        ),
      );
      return;
    }

    // ----------------------------------------------------------
    // CATEGORY VALIDATION
    // ----------------------------------------------------------

    if (_selectedCategoryId ==
        null ||
        _selectedCategoryName ==
            null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select an expense category',
          ),
          behavior:
          SnackBarBehavior
              .floating,
        ),
      );
      return;
    }

    // ----------------------------------------------------------
    // USER VALIDATION
    // ----------------------------------------------------------

    final user =
        FirebaseAuth.instance
            .currentUser;

    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content: Text(
            'User is not authenticated',
          ),
        ),
      );
      return;
    }

    final existing =
        widget.existingBudget;

    // ----------------------------------------------------------
    // DUPLICATE BUDGET CHECK
    // ----------------------------------------------------------

    if (_hasDuplicateBudget()) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(
            '${_selectedCategoryName!} already has a budget for '
                '${DateFormat('MMMM yyyy').format(widget.selectedMonth)}.',
          ),
          behavior:
          SnackBarBehavior
              .floating,
        ),
      );
      return;
    }

    // ----------------------------------------------------------
    // BALANCE CHECK
    // ----------------------------------------------------------

    final availableBalance =
    _calculateAvailableBalance();

    if (amount >
        availableBalance) {
      final shouldContinue =
      await showDialog<bool>(
        context: context,
        builder:
            (dialogContext) {
          return AlertDialog(
            title: const Text(
              'Budget is higher than balance',
              style:
              TextStyle(
                fontWeight:
                FontWeight.w800,
              ),
            ),
            content: Text(
              'Your current available balance is '
                  '${CurrencyFormatter.formatCompact(
                availableBalance,
                context
                    .read<CurrencyCubit>()
                    .state
                    .currency,
              )}, but this budget is '
                  '${CurrencyFormatter.formatCompact(
                amount,
                context
                    .read<CurrencyCubit>()
                    .state
                    .currency,
              )}.\n\n'
                  'You can still create this budget because your balance may increase later.',
            ),
            shape:
            RoundedRectangleBorder(
              borderRadius:
              BorderRadius.circular(
                22,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(
                    dialogContext,
                    false,
                  );
                },
                child:
                const Text(
                  'Cancel',
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(
                    dialogContext,
                    true,
                  );
                },
                style:
                ElevatedButton
                    .styleFrom(
                  backgroundColor:
                  AppColors
                      .primary,
                  foregroundColor:
                  Colors.white,
                  elevation: 0,
                ),
                child:
                const Text(
                  'Continue',
                ),
              ),
            ],
          );
        },
      );

      if (shouldContinue !=
          true) {
        return;
      }
    }

    // ----------------------------------------------------------
    // CREATE BUDGET
    // ----------------------------------------------------------

    final budget =
    BudgetEntity(
      id: existing?.id ?? '',
      userId: user.uid,
      categoryId:
      _selectedCategoryId!,
      categoryName:
      _selectedCategoryName!,
      amount: amount,
      month: DateTime(
        widget.selectedMonth
            .year,
        widget.selectedMonth
            .month,
      ),
      createdAt:
      existing?.createdAt ??
          DateTime.now(),
    );

    // ----------------------------------------------------------
    // SAVE
    // ----------------------------------------------------------

    final bloc =
    context.read<BudgetBloc>();

    if (existing != null) {
      bloc.add(
        UpdateBudgetEvent(
          budget,
        ),
      );
    } else {
      bloc.add(
        AddBudgetEvent(
          budget,
        ),
      );
    }

    Navigator.pop(
      context,
    );
  }
}

// ============================================================
// BUDGET ALERT LEVEL
// ============================================================

enum _BudgetAlertLevel {
  normal,
  warning,
  critical,
  exceeded,
}

// ============================================================
// BUDGET ALERT LEVEL
// ============================================================

_BudgetAlertLevel _budgetAlertLevel(
    double spent,
    double budget,
    ) {
  if (budget <= 0) {
    return _BudgetAlertLevel
        .normal;
  }

  final percentage =
      spent / budget;

  if (percentage >= 1.0) {
    return _BudgetAlertLevel
        .exceeded;
  }

  if (percentage >= 0.90) {
    return _BudgetAlertLevel
        .critical;
  }

  if (percentage >= 0.80) {
    return _BudgetAlertLevel
        .warning;
  }

  return _BudgetAlertLevel
      .normal;
}

// ============================================================
// BUDGET ALERT LABEL
// ============================================================

String _budgetAlertLabel(
    _BudgetAlertLevel level,
    ) {
  switch (level) {
    case _BudgetAlertLevel.normal:
      return 'On track';

    case _BudgetAlertLevel.warning:
      return '80% used';

    case _BudgetAlertLevel.critical:
      return '90% used';

    case _BudgetAlertLevel.exceeded:
      return 'Over budget';
  }
}

// ============================================================
// BUDGET ALERT COLOR
// ============================================================

Color _budgetAlertColor(
    _BudgetAlertLevel level,
    Color fallback,
    ) {
  switch (level) {
    case _BudgetAlertLevel.normal:
      return fallback;

    case _BudgetAlertLevel.warning:
      return AppColors.primary;

    case _BudgetAlertLevel.critical:
    case _BudgetAlertLevel.exceeded:
      return AppColors.expense;
  }
}

// ============================================================
// BUDGET ALERT MESSAGE
// ============================================================

Widget _buildBudgetAlertMessage(
    BuildContext context,
    _BudgetAlertLevel level,
    ) {
  if (level ==
      _BudgetAlertLevel.normal) {return const SizedBox.shrink();
  }

  final theme =
  Theme.of(context);

  final String text;

  switch (level) {
    case _BudgetAlertLevel.warning:
      text =
      'You have used 80% of this budget. Keep an eye on your remaining amount.';
      break;

    case _BudgetAlertLevel.critical:
      text =
      'You have used 90% of this budget. Only a small amount is left.';
      break;

    case _BudgetAlertLevel.exceeded:
      text =
      'This budget has been exceeded. Review your recent spending.';
      break;

    case _BudgetAlertLevel.normal:
      text = '';
      break;
  }

  final color =
  _budgetAlertColor(
    level,
    AppColors.primary,
  );

  return Container(
    width:
    double.infinity,
    margin:
    const EdgeInsets.only(
      top: 12,
    ),
    padding:
    const EdgeInsets.symmetric(
      horizontal: 12,
      vertical: 10,
    ),
    decoration:
    BoxDecoration(
      color: color.withValues(
        alpha: 0.09,
      ),
      borderRadius:
      BorderRadius.circular(
        12,
      ),
      border: Border.all(
        color: color.withValues(
          alpha: 0.18,
        ),
      ),
    ),
    child: Row(
      crossAxisAlignment:
      CrossAxisAlignment
          .start,
      children: [
        Icon(
          level ==
              _BudgetAlertLevel
                  .exceeded
              ? Icons.warning_rounded
              : Icons
              .notifications_active_rounded,
          size: 18,
          color: color,
        ),

        const SizedBox(
          width: 9,
        ),

        Expanded(
          child: Text(
            text,
            style: theme
                .textTheme
                .bodySmall
                ?.copyWith(
              color: color,
              fontWeight:
              FontWeight.w700,
              height: 1.35,
            ),
          ),
        ),
      ],
    ),
  );
}

// ============================================================
// BUDGET CARD
// ============================================================

class _BudgetCard
    extends StatelessWidget {
  final BudgetEntity budget;
  final double spent;
  final CategoryEntity? category;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _BudgetCard({
    required this.budget,
    required this.spent,
    required this.category,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    final theme =
    Theme.of(context);

    final isDark =
        theme.brightness ==
            Brightness.dark;

    final remaining =
        budget.amount - spent;

    final progress =
    budget.amount > 0
        ? (spent /
        budget.amount)
        .clamp(
      0.0,
      1.0,
    )
        .toDouble()
        : 0.0;

    final alertLevel =
    _budgetAlertLevel(
      spent,
      budget.amount,
    );

    final alertColor =
    _budgetAlertColor(
      alertLevel,
      category != null
          ? Color(
        category!
            .colorValue,
      )
          : _fallbackColor(
        budget.categoryName,
      ),
    );

    // ----------------------------------------------------------
    // CATEGORY COLOR
    // ----------------------------------------------------------

    final categoryColor =
    category != null
        ? Color(
      category!
          .colorValue,
    )
        : _fallbackColor(
      budget.categoryName,
    );

    // ----------------------------------------------------------
    // CATEGORY ICON
    // ----------------------------------------------------------

    final categoryIcon =
    category != null
        ? IconData(
      category!
          .iconCodePoint,
      fontFamily:
      'MaterialIcons',
    )
        : _fallbackIcon(
      budget.categoryName,
    );

    return Material(
      color:
      Colors.transparent,
      child: Ink(
        padding:
        const EdgeInsets.all(
          18,
        ),
        decoration:
        BoxDecoration(
          color: isDark
              ? AppColors
              .darkSurface
              : AppColors
              .lightSurface,
          borderRadius:
          BorderRadius.circular(
            22,
          ),
          border: Border.all(
            color: isDark
                ? AppColors
                .darkBorder
                : AppColors
                .lightBorder,
          ),
        ),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment
              .start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration:
                  BoxDecoration(
                    color:
                    categoryColor
                        .withValues(
                      alpha: 0.12,
                    ),
                    shape:
                    BoxShape.circle,
                  ),
                  child: Icon(
                    categoryIcon,
                    color:
                    categoryColor,
                    size: 23,
                  ),
                ),

                const SizedBox(
                  width: 12,
                ),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                    children: [
                      Text(
                        budget
                            .categoryName,
                        maxLines: 1,
                        overflow:
                        TextOverflow
                            .ellipsis,
                        style: theme
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                          fontWeight:
                          FontWeight
                              .w800,
                        ),
                      ),

                      const SizedBox(
                        height: 4,
                      ),

                      Row(
                        children: [
                          Flexible(
                            child:
                            Text(
                              'Monthly budget',
                              style: theme
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                color: theme
                                    .textTheme
                                    .bodySmall
                                    ?.color
                                    ?.withValues(
                                  alpha:
                                  0.55,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(
                            width: 8,
                          ),

                          Container(
                            padding:
                            const EdgeInsets
                                .symmetric(
                              horizontal:
                              8,
                              vertical:
                              3,
                            ),
                            decoration:
                            BoxDecoration(
                              color:
                              alertColor.withValues(
                                alpha:
                                0.10,
                              ),
                              borderRadius:
                              BorderRadius
                                  .circular(
                                8,
                              ),
                            ),
                            child:
                            Text(
                              _budgetAlertLabel(
                                alertLevel,
                              ),
                              style:
                              TextStyle(
                                color:
                                alertColor,
                                fontSize:
                                10,
                                fontWeight:
                                FontWeight
                                    .w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                PopupMenuButton<
                    String>(
                  onSelected:
                      (value) {
                    if (value ==
                        'edit') {
                      onEdit();
                    } else if (value ==
                        'delete') {
                      onDelete();
                    }
                  },
                  itemBuilder:
                      (_) => const [
                    PopupMenuItem<
                        String>(
                      value:
                      'edit',
                      child: Row(
                        children: [
                          Icon(
                            Icons
                                .edit_rounded,
                            size: 20,
                          ),
                          SizedBox(
                            width: 10,
                          ),
                          Text(
                            'Edit',
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem<
                        String>(
                      value:
                      'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons
                                .delete_outline_rounded,
                            size: 20,
                          ),
                          SizedBox(
                            width: 10,
                          ),
                          Text(
                            'Delete',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(
              height: 18,
            ),

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
                        CurrencyFormatter
                            .formatCompact(
                          spent,
                          currencyState
                              .currency,
                        ),
                        style: theme
                            .textTheme
                            .titleLarge
                            ?.copyWith(
                          fontWeight:
                          FontWeight
                              .w800,
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
                      'of ${CurrencyFormatter.formatCompact(
                        budget.amount,
                        currencyState
                            .currency,
                      )}',
                      style: theme
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                        color: theme
                            .textTheme
                            .bodySmall
                            ?.color
                            ?.withValues(
                          alpha:
                          0.55,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(
              height: 12,
            ),

            ClipRRect(
              borderRadius:
              BorderRadius.circular(
                10,
              ),
              child:
              LinearProgressIndicator(
                minHeight: 8,
                value: progress,
                backgroundColor:
                categoryColor
                    .withValues(
                  alpha: 0.10,
                ),
                color: alertLevel ==
                    _BudgetAlertLevel
                        .normal
                    ? categoryColor
                    : alertColor,
              ),
            ),

            const SizedBox(
              height: 12,
            ),

            Row(
              children: [
                Expanded(
                  child: Text(
                    alertLevel ==
                        _BudgetAlertLevel
                            .exceeded
                        ? 'Over budget'
                        : 'Remaining',
                    style: theme
                        .textTheme
                        .bodySmall
                        ?.copyWith(
                      color: alertLevel ==
                          _BudgetAlertLevel
                              .exceeded
                          ? AppColors
                          .expense
                          : theme
                          .textTheme
                          .bodySmall
                          ?.color
                          ?.withValues(
                        alpha:
                        0.6,
                      ),
                      fontWeight:
                      FontWeight
                          .w700,
                    ),
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
                      CurrencyFormatter
                          .formatCompact(
                        remaining.abs(),
                        currencyState
                            .currency,
                      ),
                      style:
                      TextStyle(
                        color: alertLevel ==
                            _BudgetAlertLevel
                                .exceeded
                            ? AppColors
                            .expense
                            : AppColors
                            .income,
                        fontWeight:
                        FontWeight
                            .w800,
                      ),
                    );
                  },
                ),
              ],
            ),

            _buildBudgetAlertMessage(
              context,
              alertLevel,
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // FALLBACK ICON
  // ============================================================

  IconData _fallbackIcon(
      String category,
      ) {
    switch (
    category
        .toLowerCase()) {
      case 'food':
        return Icons
            .restaurant_rounded;

      case 'shopping':
        return Icons
            .shopping_bag_rounded;

      case 'transport':
        return Icons
            .directions_car_rounded;

      case 'bills':
        return Icons
            .receipt_long_rounded;

      case 'health':
        return Icons
            .medical_services_rounded;

      case 'entertainment':
        return Icons.movie_rounded;

      case 'education':
        return Icons
            .school_rounded;

      case 'home':
        return Icons.home_rounded;

      default:
        return Icons
            .category_rounded;
    }
  }

  // ============================================================
  // FALLBACK COLOR
  // ============================================================

  Color _fallbackColor(
      String category,
      ) {
    switch (
    category
        .toLowerCase()) {
      case 'food':
        return const Color(
          0xFFFF7043,
        );

      case 'shopping':
        return AppColors
            .navPurple;

      case 'transport':
        return AppColors
            .navActive;

      case 'bills':
        return AppColors
            .expense;

      case 'health':
        return AppColors
            .income;

      case 'entertainment':
        return const Color(
          0xFF9B59B6,
        );

      case 'education':
        return const Color(
          0xFF3498DB,
        );

      case 'home':
        return const Color(
          0xFF607D8B,
        );

      default:
        return AppColors
            .primary;
    }
  }
}

// ============================================================
// OVERVIEW ITEM
// ============================================================

class _OverviewItem
    extends StatelessWidget {
  final String title;
  final double amount;

  const _OverviewItem({
    required this.title,
    required this.amount,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return BlocBuilder<
        CurrencyCubit,
        CurrencyState>(
      builder: (
          context,
          currencyState,
          ) {
        return Column(
          crossAxisAlignment:
          CrossAxisAlignment
              .start,
          children: [
            Text(
              title,
              style:
              TextStyle(
                color: Colors
                    .white
                    .withValues(
                  alpha: 0.65,
                ),
                fontSize: 12,
                fontWeight:
                FontWeight.w600,
              ),
            ),

            const SizedBox(
              height: 5,
            ),

            Text(
              CurrencyFormatter
                  .formatCompact(
                amount.abs(),
                currencyState
                    .currency,
              ),
              style:
              const TextStyle(
                color:
                Colors.white,
                fontSize: 16,
                fontWeight:
                FontWeight.w800,
              ),
            ),
          ],
        );
      },
    );
  }
}
