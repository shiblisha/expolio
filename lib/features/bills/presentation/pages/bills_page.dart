import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/currency/currency_cubit.dart';
import '../../../../core/currency/currency_state.dart';
import '../../../../core/enums/app_currency.dart';
import '../../../../shared/widgets/app_loading_indicator.dart';
import '../../../../shared/widgets/currency_text.dart';
import '../../../wallet/presentation/bloc/wallet_bloc.dart';
import '../../../wallet/presentation/bloc/wallet_state.dart';
import '../../domain/entities/bill_entity.dart';
import '../bloc/bill_bloc.dart';
import '../bloc/bill_event.dart';
import '../bloc/bill_state.dart';

class BillsPage extends StatelessWidget {
  const BillsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Bills',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () {
              _showBillDialog(context);
            },
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: BlocBuilder<BillBloc, BillState>(
        builder: (context, state) {
          if (state.status == BillStatus.loading && state.bills.isEmpty) {
            return const Center(
              child: AppLoadingIndicator(color: AppColors.primary),
            );
          }

          if (state.status == BillStatus.failure && state.bills.isEmpty) {
            return _buildError(context, state.errorMessage);
          }

          final bills = state.bills;

          final now = DateTime.now();

          final upcomingBills = bills
              .where(
                (bill) =>
            !bill.isPaid &&
                !bill.dueDate.isBefore(
                  DateTime(now.year, now.month, now.day),
                ),
          )
              .toList();

          final overdueBills = bills
              .where(
                (bill) =>
            !bill.isPaid &&
                bill.dueDate.isBefore(
                  DateTime(now.year, now.month, now.day),
                ),
          )
              .toList();

          final paidBills = bills.where((bill) => bill.isPaid).toList();

          upcomingBills.sort((a, b) => a.dueDate.compareTo(b.dueDate));

          overdueBills.sort((a, b) => a.dueDate.compareTo(b.dueDate));

          paidBills.sort((a, b) {
            final aDate = a.paidAt ?? a.createdAt;
            final bDate = b.paidAt ?? b.createdAt;

            return bDate.compareTo(aDate);
          });

          final totalUpcoming = upcomingBills.fold<double>(
            0,
                (total, bill) => total + bill.amount,
          );

          final totalOverdue = overdueBills.fold<double>(
            0,
                (total, bill) => total + bill.amount,
          );

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async {
              context.read<BillBloc>().add(const LoadBills());

              await Future.delayed(const Duration(milliseconds: 500));
            },
            child: ListView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
              children: [
                _buildSummary(
                  context,
                  upcomingCount: upcomingBills.length,
                  overdueCount: overdueBills.length,
                  totalUpcoming: totalUpcoming,
                  totalOverdue: totalOverdue,
                ),

                const SizedBox(height: 24),

                if (overdueBills.isNotEmpty) ...[
                  _buildSectionHeader(
                    context,
                    title: 'Overdue',
                    count: overdueBills.length,
                  ),
                  const SizedBox(height: 12),
                  ...overdueBills.map(
                        (bill) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _BillCard(
                        bill: bill,
                        status: BillCardStatus.overdue,
                        onEdit: () {
                          _showBillDialog(context, existingBill: bill);
                        },
                        onDelete: () {
                          _confirmDelete(context, bill);
                        },
                        onMarkPaid: () {
                          _markBillPaid(context, bill);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                if (upcomingBills.isNotEmpty) ...[
                  _buildSectionHeader(
                    context,
                    title: 'Upcoming',
                    count: upcomingBills.length,
                  ),
                  const SizedBox(height: 12),
                  ...upcomingBills.map(
                        (bill) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _BillCard(
                        bill: bill,
                        status: BillCardStatus.upcoming,
                        onEdit: () {
                          _showBillDialog(context, existingBill: bill);
                        },
                        onDelete: () {
                          _confirmDelete(context, bill);
                        },
                        onMarkPaid: () {
                          _markBillPaid(context, bill);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                if (paidBills.isNotEmpty) ...[
                  _buildSectionHeader(
                    context,
                    title: 'Paid',
                    count: paidBills.length,
                  ),
                  const SizedBox(height: 12),
                  ...paidBills.map(
                        (bill) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _BillCard(
                        bill: bill,
                        status: BillCardStatus.paid,
                        onEdit: () {
                          _showBillDialog(context, existingBill: bill);
                        },
                        onDelete: () {
                          _showPaidBillDeleteMessage(context);
                        },
                        onMarkPaid: null,
                      ),
                    ),
                  ),
                ],

                if (bills.isEmpty) _buildEmpty(context),
              ],
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // SUMMARY
  // ============================================================

  Widget _buildSummary(
      BuildContext context, {
        required int upcomingCount,
        required int overdueCount,
        required double totalUpcoming,
        required double totalOverdue,
      }) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            icon: Icons.calendar_month_rounded,
            title: 'Upcoming',
            value: upcomingCount.toString(),
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryCard(
            icon: Icons.warning_amber_rounded,
            title: 'Overdue',
            value: overdueCount.toString(),
            color: AppColors.expense,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryMoneyCard(
            title: 'Due',
            amount: totalUpcoming + totalOverdue,
            color: theme.brightness == Brightness.dark
                ? AppColors.darkText
                : AppColors.lightText,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // SECTION HEADER
  // ============================================================

  Widget _buildSectionHeader(
      BuildContext context, {
        required String title,
        required int count,
      }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        Text(
          '$count bills',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).textTheme.bodySmall?.color
                ?.withValues(alpha: 0.55),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // EMPTY
  // ============================================================

  Widget _buildEmpty(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? AppColors.darkSurface
            : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              color: AppColors.primary,
              size: 34,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No bills yet',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            'Add your bills and never miss a payment.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: () {
              _showBillDialog(context);
            },
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Bill'),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ERROR
  // ============================================================

  Widget _buildError(BuildContext context, String? message) {
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
              'Could not load bills',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              message ?? 'Something went wrong.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: () {
                context.read<BillBloc>().add(const LoadBills());
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ADD / EDIT BILL DIALOG
  // ============================================================

  void _showBillDialog(BuildContext context, {BillEntity? existingBill}) {
    final nameController = TextEditingController(
      text: existingBill?.name ?? '',
    );

    final amountController = TextEditingController(
      text: existingBill?.amount.toString() ?? '',
    );

    DateTime selectedDate = existingBill?.dueDate ?? DateTime.now();

    String selectedCategory = existingBill?.categoryName ?? 'Bills';

    String? selectedWalletId = existingBill?.walletId;

    String? walletError;

    bool isRecurring = existingBill?.isRecurring ?? false;

    String recurrence = existingBill?.recurrence ?? 'monthly';

    final categories = [
      'Bills',
      'Rent',
      'Electricity',
      'Internet',
      'Mobile',
      'Insurance',
      'Subscription',
      'Other',
    ];

    // Keep legacy/custom categories selectable when editing an existing bill.
    if (existingBill != null &&
        !categories.contains(existingBill.categoryName)) {
      categories.add(existingBill.categoryName);
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final theme = Theme.of(context);
            final isEditing = existingBill != null;
            final isPaidBill = existingBill?.isPaid ?? false;

            return AlertDialog(
              title: Text(
                isEditing ? 'Edit Bill' : 'Add Bill',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isPaidBill) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.income.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppColors.income.withValues(alpha: 0.20),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.lock_rounded,
                              color: AppColors.income,
                              size: 19,
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                'This bill is already paid. Amount, category and payment wallet are locked to keep the linked expense transaction consistent.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppColors.income,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                    ],

                    const Text(
                      'Bill name',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),

                    const SizedBox(height: 8),

                    TextField(
                      controller: nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        hintText: 'e.g. Electricity Bill',
                        prefixIcon: Icon(Icons.receipt_long_rounded),
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 18),

                    Text(
                      isPaidBill ? 'Amount (locked after payment)' : 'Amount',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),

                    const SizedBox(height: 8),

                    BlocBuilder<CurrencyCubit, CurrencyState>(
                      builder: (context, currencyState) {
                        return TextField(
                          controller: amountController,
                          enabled: !isPaidBill,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            hintText: '0.00',
                            prefixText: '${currencyState.currency.symbol} ',
                            border: const OutlineInputBorder(),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 18),

                    Text(
                      isPaidBill ? 'Category (locked after payment)' : 'Category',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),

                    const SizedBox(height: 8),

                    DropdownButtonFormField<String>(
                      initialValue: selectedCategory,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.category_rounded),
                        border: OutlineInputBorder(),
                      ),
                      items: categories
                          .map(
                            (category) => DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        ),
                      )
                          .toList(),
                      onChanged: isPaidBill
                          ? null
                          : (value) {
                        if (value != null) {
                          setDialogState(() {
                            selectedCategory = value;
                          });
                        }
                      },
                    ),

                    const SizedBox(height: 18),

                    const Text(
                      'Due date',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),

                    const SizedBox(height: 8),

                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );

                        if (picked != null) {
                          setDialogState(() {
                            selectedDate = picked;
                          });
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.calendar_month_rounded),
                          border: OutlineInputBorder(),
                        ),
                        child: Text(
                          DateFormat('dd MMM yyyy').format(selectedDate),
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    const Text(
                      'Payment source',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),

                    const SizedBox(height: 8),

                    BlocBuilder<WalletBloc, WalletState>(
                      builder: (context, walletState) {
                        final wallets = walletState.wallets;

                        // A paid bill must keep its original wallet.
                        if (isPaidBill) {
                          return InputDecorator(
                            decoration: InputDecoration(
                              prefixIcon: const Icon(
                                Icons.account_balance_wallet_rounded,
                              ),
                              labelText: 'Payment Wallet (locked after payment)',
                              suffixIcon: const Icon(Icons.lock_rounded, size: 19),
                              border: const OutlineInputBorder(),
                            ),
                            child: Text(
                              existingBill?.walletName ?? 'Wallet unavailable',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: existingBill?.walletName == null
                                    ? theme.textTheme.bodyLarge?.color
                                    ?.withValues(alpha: 0.55)
                                    : null,
                              ),
                            ),
                          );
                        }

                        if (wallets.isEmpty) {
                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.expense.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: AppColors.expense.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.account_balance_wallet_rounded,
                                  color: AppColors.expense,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'No wallets available. Create a wallet first before adding a bill.',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: AppColors.expense,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        final validSelectedWalletId = wallets.any(
                              (wallet) => wallet.id == selectedWalletId,
                        )
                            ? selectedWalletId
                            : null;

                        return DropdownButtonFormField<String>(
                          initialValue: validSelectedWalletId,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(
                              Icons.account_balance_wallet_rounded,
                            ),
                            labelText: 'Payment Wallet *',
                            hintText: 'Select wallet',
                            border: const OutlineInputBorder(),
                            errorText: walletError,
                          ),
                          items: wallets.map((wallet) {
                            return DropdownMenuItem<String>(
                              value: wallet.id,
                              child: Text(wallet.name),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setDialogState(() {
                              selectedWalletId = value;
                              walletError = null;
                            });
                          },
                        );
                      },
                    ),

                    const SizedBox(height: 8),

                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Recurring bill',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: const Text('Repeat this bill automatically'),
                      value: isRecurring,
                      onChanged: (value) {
                        setDialogState(() {
                          isRecurring = value;
                        });
                      },
                    ),

                    if (isRecurring) ...[
                      const SizedBox(height: 8),

                      DropdownButtonFormField<String>(
                        initialValue: recurrence,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.repeat_rounded),
                          labelText: 'Repeat',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'weekly',
                            child: Text('Weekly'),
                          ),
                          DropdownMenuItem(
                            value: 'monthly',
                            child: Text('Monthly'),
                          ),
                          DropdownMenuItem(
                            value: 'yearly',
                            child: Text('Yearly'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() {
                              recurrence = value;
                            });
                          }
                        },
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Cancel'),
                ),

                ElevatedButton(
                  onPressed: () {
                    final name = nameController.text.trim();

                    final amount = double.tryParse(
                      amountController.text.trim(),
                    );

                    final user = FirebaseAuth.instance.currentUser;

                    if (name.isEmpty) {
                      return;
                    }

                    if (amount == null || amount <= 0) {
                      return;
                    }

                    if (user == null) {
                      return;
                    }

                    final walletState = context.read<WalletBloc>().state;

                    // ========================================================
                    // PAID BILL PROTECTION
                    // Keep amount, category and wallet exactly as originally
                    // recorded because the linked expense transaction uses
                    // those values. Only metadata fields may be edited.
                    // ========================================================

                    final double savedAmount;
                    final String savedCategoryId;
                    final String savedCategoryName;
                    final String? savedWalletId;
                    final String? savedWalletName;

                    if (isPaidBill) {
                      final originalBill = existingBill!;

                      savedAmount = originalBill.amount;
                      savedCategoryId = originalBill.categoryId;
                      savedCategoryName = originalBill.categoryName;
                      savedWalletId = originalBill.walletId;
                      savedWalletName = originalBill.walletName;
                    } else {
                      if (walletState.wallets.isEmpty) {
                        setDialogState(() {
                          walletError =
                          'No wallet available. Create a wallet first.';
                        });
                        return;
                      }

                      if (selectedWalletId == null ||
                          selectedWalletId!.isEmpty) {
                        setDialogState(() {
                          walletError = 'Please select a payment wallet';
                        });
                        return;
                      }

                      String? selectedWalletName;

                      for (final wallet in walletState.wallets) {
                        if (wallet.id == selectedWalletId) {
                          selectedWalletName = wallet.name;
                          break;
                        }
                      }

                      if (selectedWalletName == null) {
                        setDialogState(() {
                          walletError =
                          'Selected wallet is no longer available';
                        });
                        return;
                      }

                      savedAmount = amount!;
                      savedCategoryId = selectedCategory.toLowerCase().replaceAll(
                        ' ',
                        '_',
                      );
                      savedCategoryName = selectedCategory;
                      savedWalletId = selectedWalletId;
                      savedWalletName = selectedWalletName;
                    }

                    final bill = BillEntity(
                      id: existingBill?.id ?? '',
                      userId: user.uid,
                      name: name,
                      amount: savedAmount,
                      dueDate: selectedDate,
                      categoryId: savedCategoryId,
                      categoryName: savedCategoryName,
                      walletId: savedWalletId,
                      walletName: savedWalletName,
                      isRecurring: isRecurring,
                      recurrence: isRecurring ? recurrence : 'none',
                      isPaid: existingBill?.isPaid ?? false,
                      paidAt: existingBill?.paidAt,
                      createdAt: existingBill?.createdAt ?? DateTime.now(),
                    );

                    if (isEditing) {
                      context.read<BillBloc>().add(UpdateBillEvent(bill));
                    } else {
                      context.read<BillBloc>().add(AddBillEvent(bill));
                    }

                    Navigator.of(dialogContext).pop();
                  },
                  child: Text(isEditing ? 'Update' : 'Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ============================================================
  // MARK PAID
  // ============================================================

  void _markBillPaid(BuildContext context, BillEntity bill) {
    if (bill.isPaid) {
      return;
    }

    // Legacy bills created before wallet became mandatory
    // must be assigned to a wallet before they can be paid.
    if (bill.walletId == null || bill.walletId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please edit this bill and select a payment wallet first',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Mark bill as paid?',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          content: Text('Mark "${bill.name}" as paid?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();

                context.read<BillBloc>().add(MarkBillPaidEvent(bill));
              },
              child: const Text('Mark Paid'),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // PAID BILL DELETE BLOCK
  // ============================================================

  void _showPaidBillDeleteMessage(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Paid bills cannot be deleted because they are linked to an expense transaction.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ============================================================
  // DELETE
  // ============================================================

  Future<void> _confirmDelete(BuildContext context, BillEntity bill) async {
    if (bill.isPaid) {
      _showPaidBillDeleteMessage(context);
      return;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Delete bill?',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          content: Text('Delete "${bill.name}"?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text(
                'Delete',
                style: TextStyle(
                  color: AppColors.expense,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (result == true && context.mounted) {
      context.read<BillBloc>().add(DeleteBillEvent(bill.id));
    }
  }
}

// ================================================================
// SUMMARY CARD
// ================================================================

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;

  const _SummaryCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(13),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.55),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// MONEY SUMMARY CARD
// ================================================================

class _SummaryMoneyCard extends StatelessWidget {
  final String title;
  final double amount;
  final Color color;

  const _SummaryMoneyCard({
    required this.title,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(13),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.payments_rounded,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.55),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          CurrencyText(
            amount,
            style: theme.textTheme.titleSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// BILL CARD
// ================================================================

enum BillCardStatus { upcoming, overdue, paid }

class _BillCard extends StatelessWidget {
  final BillEntity bill;
  final BillCardStatus status;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onMarkPaid;

  const _BillCard({
    required this.bill,
    required this.status,
    required this.onEdit,
    required this.onDelete,
    required this.onMarkPaid,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final isOverdue = status == BillCardStatus.overdue;

    final isPaid = status == BillCardStatus.paid;

    final statusColor = isPaid
        ? AppColors.income
        : isOverdue
        ? AppColors.expense
        : AppColors.primary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? AppColors.darkSurface
            : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isOverdue
              ? AppColors.expense.withValues(alpha: 0.22)
              : isPaid
              ? AppColors.income.withValues(alpha: 0.18)
              : theme.brightness == Brightness.dark
              ? AppColors.darkBorder
              : AppColors.lightBorder,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  _categoryIcon(bill.categoryName),
                  color: statusColor,
                ),
              ),

              const SizedBox(width: 13),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bill.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      bill.categoryName,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color?.withValues(
                          alpha: 0.55,
                        ),
                      ),
                    ),

                    const SizedBox(height: 5),

                    Row(
                      children: [
                        Icon(
                          isPaid
                              ? Icons.check_circle_rounded
                              : Icons.calendar_today_rounded,
                          size: 13,
                          color: statusColor,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            isPaid
                                ? 'Paid ${DateFormat('dd MMM yyyy').format(bill.paidAt ?? bill.dueDate)}'
                                : isOverdue
                                ? 'Due ${DateFormat('dd MMM yyyy').format(bill.dueDate)}'
                                : 'Due ${DateFormat('dd MMM yyyy').format(bill.dueDate)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              CurrencyText(
                bill.amount,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),

              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') {
                    onEdit();
                  }

                  if (value == 'delete') {
                    onDelete();
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),

          if (!isPaid && onMarkPaid != null) ...[
            const SizedBox(height: 14),

            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                onPressed: onMarkPaid,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
                icon: const Icon(Icons.check_rounded, size: 19),
                label: const Text(
                  'Mark as Paid',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],

          if (bill.isRecurring) ...[
            const SizedBox(height: 10),

            Row(
              children: [
                Icon(
                  Icons.repeat_rounded,
                  size: 15,
                  color: theme.textTheme.bodySmall?.color?.withValues(
                    alpha: 0.50,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  _recurrenceLabel(bill.recurrence),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.textTheme.bodySmall?.color?.withValues(
                      alpha: 0.50,
                    ),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (bill.walletName != null) ...[
                  const SizedBox(width: 10),
                  const Text('•'),
                  const SizedBox(width: 10),
                  Icon(
                    Icons.account_balance_wallet_rounded,
                    size: 14,
                    color: theme.textTheme.bodySmall?.color?.withValues(
                      alpha: 0.50,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      bill.walletName!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color?.withValues(
                          alpha: 0.50,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ] else if (bill.walletName != null) ...[
            const SizedBox(height: 10),

            Row(
              children: [
                Icon(
                  Icons.account_balance_wallet_rounded,
                  size: 14,
                  color: theme.textTheme.bodySmall?.color?.withValues(
                    alpha: 0.50,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  bill.walletName!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.textTheme.bodySmall?.color?.withValues(
                      alpha: 0.50,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  IconData _categoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'bills':
        return Icons.receipt_long_rounded;

      case 'rent':
        return Icons.home_work_rounded;

      case 'electricity':
        return Icons.bolt_rounded;

      case 'internet':
        return Icons.wifi_rounded;

      case 'mobile':
        return Icons.phone_android_rounded;

      case 'insurance':
        return Icons.security_rounded;

      case 'subscription':
        return Icons.subscriptions_rounded;

      default:
        return Icons.receipt_long_rounded;
    }
  }

  String _recurrenceLabel(String value) {
    switch (value) {
      case 'weekly':
        return 'Weekly';

      case 'monthly':
        return 'Monthly';

      case 'yearly':
        return 'Yearly';

      default:
        return 'Recurring';
    }
  }
}
