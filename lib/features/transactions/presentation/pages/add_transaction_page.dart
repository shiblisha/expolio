import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/currency/currency_cubit.dart';
import '../../../../core/currency/currency_state.dart';
import '../../../../core/enums/app_currency.dart';
import '../../../../core/enums/category_type.dart';
import '../../../../core/enums/payment_method.dart';
import '../../../../core/enums/transaction_type.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/notifications/local_notification_service.dart';

import '../../../categories/domain/entities/category_entity.dart';
import '../../../categories/presentation/bloc/category_bloc.dart';
import '../../../categories/presentation/bloc/category_event.dart';
import '../../../categories/presentation/bloc/category_state.dart';

import '../../../wallet/domain/entities/wallet_entity.dart';
import '../../../wallet/presentation/bloc/wallet_bloc.dart';
import '../../../wallet/presentation/bloc/wallet_state.dart';
import '../../../budget/domain/entities/budget_entity.dart';
import '../../../budget/presentation/bloc/budget_bloc.dart';
import '../../../budget/presentation/bloc/budget_state.dart';
import '../../domain/entities/transaction_entity.dart';
import '../bloc/transaction_bloc.dart';
import '../bloc/transaction_event.dart';
import '../bloc/transaction_state.dart';

class AddTransactionPage extends StatefulWidget {
  final TransactionType initialType;
  final TransactionEntity? transaction;

  const AddTransactionPage({
    super.key,
    this.initialType = TransactionType.expense,
    this.transaction,
  });

  bool get isEditing => transaction != null;

  @override
  State<AddTransactionPage> createState() =>
      _AddTransactionPageState();
}

class _AddTransactionPageState extends State<AddTransactionPage> {
  final _formKey = GlobalKey<FormState>();

  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  late TransactionType _transactionType;

  PaymentMethod _paymentMethod = PaymentMethod.cash;

  DateTime _selectedDate = DateTime.now();

  String? _selectedCategoryId;
  String? _selectedCategoryName;

  String? _selectedWalletId;

  // Pending notification prepared during the budget warning.
  String? _pendingNotificationTitle;
  String? _pendingNotificationBody;
  String? _pendingBudgetNotificationKey;
  int? _pendingBudgetNotificationStage;

  @override
  void initState() {
    super.initState();

    final existingTransaction = widget.transaction;

    if (existingTransaction != null) {
      _transactionType = existingTransaction.type;

      _amountController.text =
          existingTransaction.amount.toString();

      _noteController.text =
          existingTransaction.description;

      _selectedDate = existingTransaction.date;

      _paymentMethod = existingTransaction.paymentMethod;

      _selectedCategoryId =
          existingTransaction.categoryId;

      _selectedCategoryName =
          existingTransaction.categoryName;

      _selectedWalletId =
          existingTransaction.walletId;
    } else {
      _transactionType = widget.initialType;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  bool get isIncome =>
      _transactionType == TransactionType.income;

  Color get accentColor =>
      isIncome ? AppColors.income : AppColors.expense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isEditing
              ? 'Edit Transaction'
              : 'Add Transaction',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
      ),
      body: BlocListener<TransactionBloc, TransactionState>(
        listener: (context, state) async {
          if (state.saveSuccess) {
            final notificationTitle = _pendingNotificationTitle;
            final notificationBody = _pendingNotificationBody;
            final notificationKey = _pendingBudgetNotificationKey;
            final notificationStage = _pendingBudgetNotificationStage;

            _pendingNotificationTitle = null;
            _pendingNotificationBody = null;
            _pendingBudgetNotificationKey = null;
            _pendingBudgetNotificationStage = null;

            if (notificationTitle != null &&
                notificationBody != null &&
                notificationKey != null &&
                notificationStage != null) {
              await LocalNotificationService.showBudgetAlert(
                id: DateTime.now().millisecondsSinceEpoch.remainder(2147483647),
                title: notificationTitle,
                body: notificationBody,
              );

              await _markBudgetNotificationSent(
                notificationKey,
                notificationStage,
              );
            }

            if (!mounted) {
              return;
            }

            Navigator.of(context).pop();
            return;
          }

          if (state.status == TransactionStatus.failure &&
              state.errorMessage != null) {
            _clearPendingBudgetNotification();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage!),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        child: SafeArea(
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      20,
                      8,
                      20,
                      24,
                    ),
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        _buildTypeSelector(),

                        const SizedBox(height: 26),

                        _buildAmountField(),

                        const SizedBox(height: 28),

                        _buildSectionTitle('Category'),

                        const SizedBox(height: 12),

                        _buildCategoryGrid(),

                        const SizedBox(height: 26),

                        _buildSectionTitle('Payment Method'),

                        const SizedBox(height: 12),

                        _buildPaymentMethods(),

                        const SizedBox(height: 26),

                        _buildSectionTitle('Date'),

                        const SizedBox(height: 12),

                        _buildDateSelector(),

                        const SizedBox(height: 26),

                        _buildSectionTitle('Note'),

                        const SizedBox(height: 12),

                        TextFormField(
                          controller: _noteController,
                          maxLines: 3,
                          textInputAction: TextInputAction.done,
                          decoration: InputDecoration(
                            hintText: 'Add a note...',
                            filled: true,
                            fillColor:
                            theme.brightness ==
                                Brightness.dark
                                ? AppColors.darkSurface
                                : AppColors.lightSurface,
                            prefixIcon: const Padding(
                              padding: EdgeInsets.only(
                                left: 16,
                                right: 10,
                                top: 14,
                              ),
                              child: Icon(
                                Icons.notes_rounded,
                                size: 21,
                              ),
                            ),
                            prefixIconConstraints:
                            const BoxConstraints(
                              minWidth: 50,
                            ),
                            border: OutlineInputBorder(
                              borderRadius:
                              BorderRadius.circular(18),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder:
                            OutlineInputBorder(
                              borderRadius:
                              BorderRadius.circular(18),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder:
                            OutlineInputBorder(
                              borderRadius:
                              BorderRadius.circular(18),
                              borderSide: BorderSide(
                                color: accentColor.withValues(
                                  alpha: 0.6,
                                ),
                                width: 1.2,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),

                _buildBottomButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // INCOME / EXPENSE SELECTOR
  // ============================================================

  Widget _buildTypeSelector() {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.darkSurface
            : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: _typeButton(
              label: 'Expense',
              icon: Icons.arrow_upward_rounded,
              type: TransactionType.expense,
            ),
          ),
          Expanded(
            child: _typeButton(
              label: 'Income',
              icon: Icons.arrow_downward_rounded,
              type: TransactionType.income,
            ),
          ),
        ],
      ),
    );
  }

  Widget _typeButton({
    required String label,
    required IconData icon,
    required TransactionType type,
  }) {
    final selected = _transactionType == type;

    final color = type == TransactionType.income
        ? AppColors.income
        : AppColors.expense;

    return GestureDetector(
      onTap: () {
        if (_transactionType == type) {
          return;
        }

        setState(() {
          _transactionType = type;

          // Category belongs to the selected type.
          _selectedCategoryId = null;
          _selectedCategoryName = null;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(
          vertical: 14,
        ),
        decoration: BoxDecoration(
          color: selected
              ? color
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: selected
                  ? Colors.white
                  : Theme.of(context).iconTheme.color,
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                color: selected
                    ? Colors.white
                    : Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // AMOUNT
  // ============================================================

  Widget _buildAmountField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Amount',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),

        const SizedBox(height: 12),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness ==
                Brightness.dark
                ? AppColors.darkSurface
                : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: accentColor.withValues(
                alpha: 0.18,
              ),
            ),
          ),
          child: Row(
            children: [
              BlocBuilder<CurrencyCubit, CurrencyState>(
                builder: (context, currencyState) {
                  return Text(
                    currencyState.currency.symbol,
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                    ),
                  );
                },
              ),

              const SizedBox(width: 12),

              Expanded(
                child: TextFormField(
                  controller: _amountController,
                  keyboardType:
                  const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                  ),
                  decoration: const InputDecoration(
                    hintText: '0.00',
                    border: InputBorder.none,
                  ),
                  validator: (value) {
                    if (value == null ||
                        value.trim().isEmpty) {
                      return 'Enter amount';
                    }

                    final amount =
                    double.tryParse(
                      value.trim(),
                    );

                    if (amount == null ||
                        amount <= 0) {
                      return 'Enter a valid amount';
                    }

                    return null;
                  },
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 26),

        _buildSectionTitle('Wallet'),

        const SizedBox(height: 12),

        _buildWalletSelector(),
      ],
    );
  }

  // ============================================================
  // WALLET
  // ============================================================

  Widget _buildWalletSelector() {
    return BlocBuilder<WalletBloc, WalletState>(
      builder: (context, state) {
        final wallets = state.wallets;

        if (wallets.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness ==
                  Brightness.dark
                  ? AppColors.darkSurface
                  : AppColors.lightSurface,
              borderRadius: BorderRadius.circular(17),
              border: Border.all(
                color: AppColors.expense.withValues(
                  alpha: 0.2,
                ),
              ),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.expense,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Create a wallet first from Manage → Wallets.',
                  ),
                ),
              ],
            ),
          );
        }

        final selectedId = wallets.any(
              (wallet) => wallet.id == _selectedWalletId,
        )
            ? _selectedWalletId
            : null;

        return DropdownButtonFormField<String>(
          initialValue: selectedId,
          decoration: InputDecoration(
            filled: true,
            fillColor: Theme.of(context).brightness ==
                Brightness.dark
                ? AppColors.darkSurface
                : AppColors.lightSurface,
            prefixIcon: const Icon(
              Icons.account_balance_wallet_rounded,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(17),
              borderSide: BorderSide.none,
            ),
          ),
          hint: const Text('Select wallet'),
          items: wallets.map((wallet) {
            return DropdownMenuItem<String>(
              value: wallet.id,
              child: Text(wallet.name),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedWalletId = value;
            });
          },
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Select a wallet';
            }

            return null;
          },
        );
      },
    );
  }

  // ============================================================
  // SECTION TITLE
  // ============================================================

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context)
          .textTheme
          .titleMedium
          ?.copyWith(
        fontWeight: FontWeight.w800,
      ),
    );
  }

  // ============================================================
  // DYNAMIC CATEGORY GRID
  // ============================================================

  Widget _buildCategoryGrid() {
    return BlocBuilder<CategoryBloc, CategoryState>(
      builder: (context, state) {
        if (state.status == CategoryStatus.loading &&
            state.categories.isEmpty) {
          return Container(
            height: 180,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Theme.of(context).brightness ==
                  Brightness.dark
                  ? AppColors.darkSurface
                  : AppColors.lightSurface,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const CircularProgressIndicator(),
          );
        }

        if (state.status == CategoryStatus.failure &&
            state.categories.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness ==
                  Brightness.dark
                  ? AppColors.darkSurface
                  : AppColors.lightSurface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: AppColors.expense.withValues(
                  alpha: 0.2,
                ),
              ),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: AppColors.expense,
                  size: 28,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Could not load categories',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () {
                    context.read<CategoryBloc>().add(
                      const LoadCategories(),
                    );
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final categories = state.categories
            .where(
              (category) =>
          category.type == _transactionCategoryType,
        )

            .toList();

        if (categories.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness ==
                  Brightness.dark
                  ? AppColors.darkSurface
                  : AppColors.lightSurface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Theme.of(context).brightness ==
                    Brightness.dark
                    ? AppColors.darkBorder
                    : AppColors.lightBorder,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.category_outlined,
                  size: 32,
                  color: accentColor,
                ),
                const SizedBox(height: 10),
                Text(
                  isIncome
                      ? 'No income categories'
                      : 'No expense categories',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Create categories from Manage → Categories.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.color
                        ?.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          );
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: categories.length,
          gridDelegate:
          const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.85,
          ),
          itemBuilder: (context, index) {
            final category = categories[index];

            final selected = _isCategorySelected(category);

            final categoryColor =
            Color(category.colorValue);
            final categoryIcon = IconData(
              category.iconCodePoint,
              fontFamily: 'MaterialIcons',
            );

            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedCategoryId = category.id;
                  _selectedCategoryName = category.name;
                });
              },
              child: AnimatedContainer(
                duration:
                const Duration(milliseconds: 180),
                decoration: BoxDecoration(
                  color: selected
                      ? categoryColor.withValues(
                    alpha: 0.12,
                  )
                      : Theme.of(context).brightness ==
                      Brightness.dark
                      ? AppColors.darkSurface
                      : AppColors.lightSurface,
                  borderRadius:
                  BorderRadius.circular(16),
                  border: Border.all(
                    color: selected
                        ? categoryColor
                        : Colors.transparent,
                    width: 1.2,
                  ),
                ),
                child: Column(
                  mainAxisAlignment:
                  MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: selected
                            ? categoryColor.withValues(
                          alpha: 0.14,
                        )
                            : Theme.of(context)
                            .brightness ==
                            Brightness.dark
                            ? AppColors.darkSurface2
                            : AppColors.lightBackground,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        categoryIcon,
                        size: 20,
                        color: selected
                            ? categoryColor
                            : categoryColor.withValues(
                          alpha: 0.75,
                        ),
                      ),
                    ),

                    const SizedBox(height: 7),

                    Padding(
                      padding:
                      const EdgeInsets.symmetric(
                        horizontal: 4,
                      ),
                      child: Text(
                        category.name,
                        maxLines: 1,
                        overflow:
                        TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: selected
                              ? FontWeight.w800
                              : FontWeight.w600,
                          color: selected
                              ? categoryColor
                              : null,
                        ),
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

  CategoryType get _transactionCategoryType {
    return _transactionType == TransactionType.income
        ? CategoryType.income
        : CategoryType.expense;
  }

  bool _isCategorySelected(
      CategoryEntity category,
      ) {
    // Normal case: actual Firebase category ID.
    if (_selectedCategoryId == category.id) {
      return true;
    }

    // Compatibility with older transactions where
    // categoryId was saved as lowercase category name.
    if (_selectedCategoryName != null &&
        category.name.toLowerCase() ==
            _selectedCategoryName!.toLowerCase()) {
      return true;
    }

    return false;
  }

  // ============================================================
  // PAYMENT METHOD
  // ============================================================

  Widget _buildPaymentMethods() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: PaymentMethod.values.map((method) {
          final selected = method == _paymentMethod;

          return Padding(
            padding:
            const EdgeInsets.only(right: 10),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _paymentMethod = method;
                });
              },
              child: AnimatedContainer(
                duration:
                const Duration(milliseconds: 180),
                padding:
                const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? accentColor.withValues(
                    alpha: 0.12,
                  )
                      : Theme.of(context).brightness ==
                      Brightness.dark
                      ? AppColors.darkSurface
                      : AppColors.lightSurface,
                  borderRadius:
                  BorderRadius.circular(14),
                  border: Border.all(
                    color: selected
                        ? accentColor
                        : Colors.transparent,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _paymentIcon(method),
                      size: 18,
                      color:
                      selected ? accentColor : null,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _paymentLabel(method),
                      style: TextStyle(
                        color:
                        selected ? accentColor : null,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ============================================================
  // DATE
  // ============================================================

  Widget _buildDateSelector() {
    return GestureDetector(
      onTap: _pickDate,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness ==
              Brightness.dark
              ? AppColors.darkSurface
              : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(17),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: accentColor.withValues(
                  alpha: 0.11,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.calendar_month_rounded,
                color: accentColor,
                size: 20,
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Text(
                DateFormat(
                  'dd MMM yyyy',
                ).format(_selectedDate),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),

            const Icon(
              Icons.chevron_right_rounded,
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SAVE BUTTON
  // ============================================================

  Widget _buildBottomButton() {
    return BlocBuilder<TransactionBloc,
        TransactionState>(
      builder: (context, state) {
        return Container(
          padding:
          const EdgeInsets.fromLTRB(
            20,
            12,
            20,
            18,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context)
                .scaffoldBackgroundColor,
          ),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: state.isSaving
                  ? null
                  : _saveTransaction,
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                accentColor.withValues(
                  alpha: 0.55,
                ),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius:
                  BorderRadius.circular(18),
                ),
              ),
              child: state.isSaving
                  ? const SizedBox(
                width: 23,
                height: 23,
                child:
                CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor:
                  AlwaysStoppedAnimation<
                      Color>(
                    Colors.white,
                  ),
                ),
              )
                  : Text(
                '${widget.isEditing ? 'Update' : 'Save'} '
                    '${isIncome ? 'Income' : 'Expense'}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // DATE PICKER
  // ============================================================

  Future<void> _pickDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme:
            Theme.of(context).colorScheme.copyWith(
              primary: accentColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      setState(() {
        _selectedDate = pickedDate;
      });
    }
  }

  // ============================================================
  // SAVE TRANSACTION
  // ============================================================

  Future<void> _saveTransaction() async {

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedCategoryId == null &&
        _selectedCategoryName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select a category',
          ),
          behavior:
          SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final amount = double.tryParse(
      _amountController.text.trim(),
    );

    if (amount == null || amount <= 0) {
      return;
    }

    final user =
        FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'User is not authenticated',
          ),
          behavior:
          SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // ==========================================================
    // FIND SELECTED CATEGORY FROM CATEGORY BLOC
    // ==========================================================

    final categoryState =
        context.read<CategoryBloc>().state;

    CategoryEntity? selectedCategory;

    for (final category
    in categoryState.categories) {
      if (_selectedCategoryId != null &&
          category.id == _selectedCategoryId) {
        selectedCategory = category;
        break;
      }

      // Compatibility with old transactions
      // where the category ID was the lowercase name.
      if (_selectedCategoryName != null &&
          category.name.toLowerCase() ==
              _selectedCategoryName!
                  .toLowerCase()) {
        selectedCategory = category;
        break;
      }
    }

    if (selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select a valid category',
          ),
          behavior:
          SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // ==========================================================
    // GET SELECTED WALLET
    // ==========================================================

    final walletState =
        context.read<WalletBloc>().state;

    WalletEntity? selectedWallet;

    for (final wallet
    in walletState.wallets) {
      if (wallet.id ==
          _selectedWalletId) {
        selectedWallet = wallet;
        break;
      }
    }

    if (selectedWallet == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select a wallet',
          ),
          behavior:
          SnackBarBehavior.floating,
        ),
      );
      return;
    }
    // ==========================================================
    // BUDGET WARNING
    // ==========================================================

    if (_transactionType == TransactionType.expense) {
      final shouldContinue = await _checkBudgetWarning(
        amount: amount,
      );

      if (!shouldContinue || !mounted) {
        return;
      }
    }
    // ==========================================================
    // CREATE TRANSACTION
    // ==========================================================

    final transaction = TransactionEntity(
      id: widget.transaction?.id ?? '',
      userId: user.uid,
      amount: amount,
      type: _transactionType,

      // Save the actual Firebase category ID.
      categoryId: selectedCategory.id,

      // Save the actual category name.
      categoryName: selectedCategory.name,

      paymentMethod: _paymentMethod,

      description:
      _noteController.text.trim(),

      date: _selectedDate,

      createdAt:
      widget.transaction?.createdAt ??
          DateTime.now(),

      walletId: selectedWallet.id,
      walletName: selectedWallet.name,
    );

    // ==========================================================
    // SEND TO BLOC
    // ==========================================================

    if (widget.isEditing) {
      context
          .read<TransactionBloc>()
          .add(
        UpdateTransactionEvent(
          transaction,
        ),
      );
    } else {
      context
          .read<TransactionBloc>()
          .add(
        AddTransactionEvent(
          transaction,
        ),
      );
    }
  }


  // ============================================================
  // BUDGET WARNING CHECK
  // ============================================================

  Future<bool> _checkBudgetWarning({
    required double amount,
  }) async {
    final budgetState = context.read<BudgetBloc>().state;
    final transactionState =
        context.read<TransactionBloc>().state;

    final categoryId = _selectedCategoryId;
    final categoryName = _selectedCategoryName;

    if (categoryId == null && categoryName == null) {
      return true;
    }

    // ----------------------------------------------------------
    // FIND MATCHING BUDGET FOR THE SELECTED DATE + CATEGORY
    // ----------------------------------------------------------

    BudgetEntity? matchingBudget;

    for (final budget in budgetState.budgets) {
      final sameMonth =
          budget.month.year == _selectedDate.year &&
              budget.month.month == _selectedDate.month;

      if (!sameMonth) {
        continue;
      }

      bool sameCategory = false;

      // Prefer the real Firebase category ID.
      if (categoryId != null &&
          categoryId.isNotEmpty &&
          budget.categoryId.isNotEmpty &&
          budget.categoryId == categoryId) {
        sameCategory = true;
      }

      // Fallback for older budget records.
      if (!sameCategory &&
          categoryName != null &&
          budget.categoryName.trim().toLowerCase() ==
              categoryName.trim().toLowerCase()) {
        sameCategory = true;
      }

      if (sameCategory) {
        matchingBudget = budget;
        break;
      }
    }

    // No budget exists for this category/month.
    if (matchingBudget == null ||
        matchingBudget.amount <= 0) {
      return true;
    }

    // ----------------------------------------------------------
    // CALCULATE EXISTING SPENDING
    // ----------------------------------------------------------

    double currentSpent = 0;

    for (final transaction in transactionState.transactions) {
      // Only expenses.
      if (transaction.type != TransactionType.expense) {
        continue;
      }

      // Only transactions from the selected month.
      if (transaction.date.year != _selectedDate.year ||
          transaction.date.month != _selectedDate.month) {
        continue;
      }

      // When editing, exclude the old transaction because
      // the new amount will be checked separately.
      if (widget.isEditing &&
          widget.transaction != null &&
          transaction.id == widget.transaction!.id) {
        continue;
      }

      bool sameCategory = false;

      // Prefer category ID.
      if (categoryId != null &&
          categoryId.isNotEmpty &&
          transaction.categoryId.isNotEmpty &&
          transaction.categoryId == categoryId) {
        sameCategory = true;
      }

      // Fallback to category name.
      if (!sameCategory &&
          categoryName != null &&
          transaction.categoryName.trim().toLowerCase() ==
              categoryName.trim().toLowerCase()) {
        sameCategory = true;
      }

      if (sameCategory) {
        currentSpent += transaction.amount;
      }
    }

    // ----------------------------------------------------------
    // NEW TOTAL AFTER THIS EXPENSE
    // ----------------------------------------------------------

    final newTotalSpent = currentSpent + amount;
    final budgetAmount = matchingBudget.amount;

    final percentage = newTotalSpent / budgetAmount;
    final remaining = budgetAmount - newTotalSpent;

    // Less than 80% means no warning.
    if (percentage < 0.80) {
      return true;
    }

    // ----------------------------------------------------------
    // WARNING CONTENT
    // ----------------------------------------------------------

    String title;
    String message;
    String actionText;
    IconData icon;
    Color color;

    if (percentage >= 1.0) {
      title = 'Budget exceeded';
      message =
      'This expense will take your '
          '${matchingBudget.categoryName} spending to '
          '${_formatBudgetPercentage(percentage)} of your budget.\n\n'
          'You will be over budget by '
          '${_formatBudgetCurrency(remaining.abs())}.';
      actionText = 'Add Anyway';
      icon = Icons.warning_amber_rounded;
      color = AppColors.expense;
    } else if (percentage >= 0.90) {
      title = '90% of budget reached';
      message =
      'After this expense, only '
          '${_formatBudgetCurrency(remaining)} will remain in your '
          '${matchingBudget.categoryName} budget.';
      actionText = 'Add Expense';
      icon = Icons.notifications_active_rounded;
      color = const Color(0xFFFF8A3D);
    } else {
      title = '80% of budget reached';
      message =
      'After this expense, '
          '${_formatBudgetCurrency(remaining)} will remain in your '
          '${matchingBudget.categoryName} budget.';
      actionText = 'Add Expense';
      icon = Icons.account_balance_wallet_outlined;
      color = AppColors.primary;
    }

    // ----------------------------------------------------------
    // PREPARE LOCAL NOTIFICATION
    // ----------------------------------------------------------

    // Only send a device notification when this threshold has not
    // already been notified for this exact budget/month.
    final notificationStage = _budgetNotificationStage(percentage);
    final notificationKey = _buildBudgetNotificationKey(
      matchingBudget,
    );

    final lastNotifiedStage = await _getBudgetNotificationStage(
      notificationKey,
    );

    if (notificationStage > lastNotifiedStage) {
      _pendingNotificationTitle = title;
      _pendingNotificationBody = message;
      _pendingBudgetNotificationKey = notificationKey;
      _pendingBudgetNotificationStage = notificationStage;
    } else {
      _clearPendingBudgetNotification();
    }

    // ----------------------------------------------------------
    // SHOW WARNING
    // ----------------------------------------------------------

    final shouldContinue = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            message,
            style: const TextStyle(
              height: 1.45,
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
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(actionText),
            ),
          ],
        );
      },
    );

    if (shouldContinue != true) {
      _clearPendingBudgetNotification();
      return false;
    }

    return true;
  }

  // ============================================================
  // BUDGET NOTIFICATION TRACKING
  // ============================================================

  int _budgetNotificationStage(double percentage) {
    if (percentage >= 1.0) {
      return 100;
    }

    if (percentage >= 0.90) {
      return 90;
    }

    if (percentage >= 0.80) {
      return 80;
    }

    return 0;
  }

  String _buildBudgetNotificationKey(BudgetEntity budget) {
    final userId =
        FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';

    final categoryKey = budget.categoryId.isNotEmpty
        ? budget.categoryId
        : budget.categoryName.trim().toLowerCase();

    final monthKey =
        '${_selectedDate.year}_${_selectedDate.month.toString().padLeft(2, '0')}';

    // Including the budget amount means changing the budget amount
    // starts a fresh threshold cycle for that month.
    final amountKey = budget.amount.toStringAsFixed(2);

    return 'budget_alert_${userId}_${monthKey}_${categoryKey}_$amountKey';
  }

  Future<int> _getBudgetNotificationStage(String key) async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getInt(key) ?? 0;
  }

  Future<void> _markBudgetNotificationSent(
      String key,
      int stage,
      ) async {
    final preferences = await SharedPreferences.getInstance();
    final currentStage = preferences.getInt(key) ?? 0;

    if (stage > currentStage) {
      await preferences.setInt(key, stage);
    }
  }

  void _clearPendingBudgetNotification() {
    _pendingNotificationTitle = null;
    _pendingNotificationBody = null;
    _pendingBudgetNotificationKey = null;
    _pendingBudgetNotificationStage = null;
  }

  // ============================================================
  // BUDGET PERCENTAGE FORMAT
  // ============================================================

  String _formatBudgetPercentage(double percentage) {
    return '${(percentage * 100).round()}%';
  }

  // ============================================================
  // BUDGET CURRENCY FORMAT
  // ============================================================

  String _formatBudgetCurrency(double amount) {
    final currency = context
        .read<CurrencyCubit>()
        .state
        .currency;

    return CurrencyFormatter.formatCompact(
      amount,
      currency,
    );
  }

  // ============================================================
  // PAYMENT ICON
  // ============================================================

  IconData _paymentIcon(
      PaymentMethod method,
      ) {
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

  // ============================================================
  // PAYMENT LABEL
  // ============================================================

  String _paymentLabel(
      PaymentMethod method,
      ) {
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
}
