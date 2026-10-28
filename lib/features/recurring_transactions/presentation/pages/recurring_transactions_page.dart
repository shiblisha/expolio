import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/enums/app_currency.dart';
import '../../../../core/enums/category_type.dart';
import '../../../../core/enums/payment_method.dart';
import '../../../../core/enums/transaction_type.dart';
import '../../../../core/currency/currency_cubit.dart';
import '../../../../core/currency/currency_state.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/widgets/app_loading_indicator.dart';
import '../../../categories/domain/entities/category_entity.dart';
import '../../../categories/presentation/bloc/category_bloc.dart';
import '../../../categories/presentation/bloc/category_event.dart';
import '../../../categories/presentation/bloc/category_state.dart';
import '../../../wallet/domain/entities/wallet_entity.dart';
import '../../../wallet/presentation/bloc/wallet_bloc.dart';
import '../../../wallet/presentation/bloc/wallet_event.dart';
import '../../../wallet/presentation/bloc/wallet_state.dart';
import '../../../transactions/presentation/bloc/transaction_bloc.dart';
import '../../../transactions/presentation/bloc/transaction_event.dart';
import '../../data/recurring_transaction_service.dart';
import '../../domain/entities/recurring_transaction_entity.dart';

class RecurringTransactionsPage extends StatefulWidget {
  const RecurringTransactionsPage({super.key});

  @override
  State<RecurringTransactionsPage> createState() =>
      _RecurringTransactionsPageState();
}

class _RecurringTransactionsPageState
    extends State<RecurringTransactionsPage> {
  final RecurringTransactionService _service =
      RecurringTransactionService();

  List<RecurringTransactionEntity> _items = [];
  bool _loading = true;
  bool _processing = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      context.read<CategoryBloc>().add(const LoadCategories());
      context.read<WalletBloc>().add(const LoadWallets());

      await _processDueAndLoad();
    });
  }

  Future<void> _processDueAndLoad() async {
    try {
      setState(() {
        _loading = true;
      });

      final count = await _service.processDueTransactions(
        currency: context.read<CurrencyCubit>().state.currency,
      );

      if (count > 0 && mounted) {
        context.read<TransactionBloc>().add(const LoadTransactions());
        context.read<WalletBloc>().add(const LoadWallets());
      }

      final items = await _service.getAll();

      if (!mounted) {
        return;
      }

      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
      });

      _showError(error);
    }
  }

  Future<void> _processDueNow() async {
    if (_processing) {
      return;
    }

    setState(() {
      _processing = true;
    });

    try {
      final count = await _service.processDueTransactions(
        currency: context.read<CurrencyCubit>().state.currency,
      );

      if (count > 0 && mounted) {
        context.read<TransactionBloc>().add(const LoadTransactions());
        context.read<WalletBloc>().add(const LoadWallets());
      }

      final items = await _service.getAll();

      if (!mounted) {
        return;
      }

      setState(() {
        _items = items;
        _processing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            count == 0
                ? 'No recurring transactions were due.'
                : '$count recurring transaction${count == 1 ? '' : 's'} created.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _processing = false;
      });

      _showError(error);
    }
  }

  Future<void> _showEditor({
    RecurringTransactionEntity? existing,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RecurringTransactionEditor(
        existing: existing,
        service: _service,
      ),
    );

    if (result == true && mounted) {
      // The recurring editor can update an already-created transaction.
      // Reload both sources so TransactionsPage, Dashboard and wallet
      // calculations immediately reflect the edited values.
      context.read<TransactionBloc>().add(
        const LoadTransactions(),
      );
      context.read<WalletBloc>().add(
        const LoadWallets(),
      );

      await _processDueAndLoad();
    }
  }

  Future<void> _toggle(
    RecurringTransactionEntity item,
  ) async {
    try {
      await _service.setActive(
        id: item.id,
        active: !item.active,
      );

      await _processDueAndLoad();
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _delete(
    RecurringTransactionEntity item,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Delete recurring transaction?',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          content: Text(
            'This will remove the ${_frequencyLabel(item.frequency).toLowerCase()} ${item.categoryName} schedule. Already-created transactions will stay.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.expense,
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _service.delete(item.id);
      await _processDueAndLoad();
    } catch (error) {
      _showError(error);
    }
  }

  void _showError(Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error.toString().replaceFirst('Bad state: ', ''),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Recurring Transactions',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Process due transactions',
            onPressed: _processing ? null : _processDueNow,
            icon: _processing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: AppLoadingIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _processDueAndLoad,
        child: _loading
            ?  ListView(
                physics: AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(height: 250),
                  Center(child: AppLoadingIndicator()),
                ],
              )
            : _items.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    children: [
                      const SizedBox(height: 90),
                      _EmptyRecurringState(),
                    ],
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _RecurringCard(
                          item: item,
                          onEdit: () => _showEditor(existing: item),
                          onToggle: () => _toggle(item),
                          onDelete: () => _delete(item),
                        ),
                      );
                    },
                  ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEditor(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add recurring'),
      ),
      backgroundColor: theme.scaffoldBackgroundColor,
    );
  }
}

class _RecurringTransactionEditor extends StatefulWidget {
  final RecurringTransactionEntity? existing;
  final RecurringTransactionService service;

  const _RecurringTransactionEditor({
    required this.existing,
    required this.service,
  });

  @override
  State<_RecurringTransactionEditor> createState() =>
      _RecurringTransactionEditorState();
}

class _RecurringTransactionEditorState
    extends State<_RecurringTransactionEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _descriptionController;

  TransactionType _type = TransactionType.expense;
  PaymentMethod _paymentMethod = PaymentMethod.cash;
  RecurringFrequency _frequency = RecurringFrequency.monthly;
  DateTime _startDate = DateTime.now();

  String? _categoryId;
  String? _categoryName;
  String? _walletId;

  bool _active = true;
  bool _saving = false;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();

    final existing = widget.existing;

    _amountController = TextEditingController(
      text: existing?.amount.toString() ?? '',
    );
    _descriptionController = TextEditingController(
      text: existing?.description ?? '',
    );

    if (existing != null) {
      _type = existing.type;
      _paymentMethod = existing.paymentMethod;
      _frequency = existing.frequency;
      _startDate = existing.nextDueDate;
      _categoryId = existing.categoryId;
      _categoryName = existing.categoryName;
      _walletId = existing.walletId;
      _active = existing.active;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate.isBefore(DateTime(2020))
          ? DateTime.now()
          : _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: _type == TransactionType.income
                  ? AppColors.income
                  : AppColors.expense,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
          9,
          0,
        );
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final amount = double.tryParse(
      _amountController.text.trim(),
    );

    if (amount == null || amount <= 0) {
      return;
    }

    if (_categoryId == null ||
        _categoryName == null ||
        _categoryId!.isEmpty) {
      _showError('Select a category.');
      return;
    }

    if (_walletId == null || _walletId!.isEmpty) {
      _showError('Select a wallet.');
      return;
    }

    final user = _currentUser();
    if (user == null) {
      _showError('User is not authenticated.');
      return;
    }

    final existing = widget.existing;
    final now = DateTime.now();

    // Keep a stable schedule anchor for monthly/yearly recurrence.
    final dayOfMonth = _startDate.day;
    final monthOfYear = _startDate.month;

    final item = RecurringTransactionEntity(
      id: existing?.id ?? '',
      userId: user.uid,
      amount: amount,
      type: _type,
      categoryId: _categoryId!,
      categoryName: _categoryName!,
      paymentMethod: _paymentMethod,
      description: _descriptionController.text.trim(),
      walletId: _walletId!,
      walletName: _walletNameFromState(),
      frequency: _frequency,
      nextDueDate: _startDate,
      dayOfMonth: dayOfMonth,
      monthOfYear: monthOfYear,
      active: _active,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
      lastRunAt: existing?.lastRunAt,
    );

    setState(() {
      _saving = true;
    });

    try {
      await widget.service.save(item);

      // When the first due date is today or in the past,
      // immediately process it so the schedule behaves predictably.
      await widget.service.processDueTransactions(
        currency: context.read<CurrencyCubit>().state.currency,
      );

      if (!mounted) {
        return;
      }

      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _saving = false;
      });

      _showError(error);
    }
  }

  User? _currentUser() {
    return FirebaseAuth.instance.currentUser;
  }

  String _walletNameFromState() {
    final walletState = context.read<WalletBloc>().state;
    for (final wallet in walletState.wallets) {
      if (wallet.id == _walletId) {
        return wallet.name;
      }
    }
    return '';
  }

  void _showError(Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error.toString().replaceFirst('Bad state: ', ''),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Material(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(28),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _editing
                              ? 'Edit Recurring Transaction'
                              : 'New Recurring Transaction',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _buildTypeSelector(),
                  const SizedBox(height: 18),
                  const Text(
                    'Amount',
                    style: TextStyle(
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
                        color: (_type == TransactionType.income
                                ? AppColors.income
                                : AppColors.expense)
                            .withValues(alpha: 0.18),
                      ),
                    ),
                    child: Row(
                      children: [
                        BlocBuilder<CurrencyCubit, CurrencyState>(
                          builder: (context, currencyState) {
                            final accentColor =
                                _type == TransactionType.income
                                    ? AppColors.income
                                    : AppColors.expense;

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
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                            ),
                            decoration: const InputDecoration(
                              hintText: '0.00',
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                vertical: 10,
                              ),
                            ),
                            validator: (value) {
                              final amount = double.tryParse(
                                value?.trim() ?? '',
                              );
                              if (amount == null || amount <= 0) {
                                return 'Enter a valid amount';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  BlocBuilder<CategoryBloc, CategoryState>(
                    builder: (context, state) {
                      final categories = state.categories
                          .where(
                            (item) => item.type == _categoryType,
                          )
                          .toList();

                      return DropdownButtonFormField<String>(
                        initialValue: categories.any(
                          (item) => item.id == _categoryId,
                        )
                            ? _categoryId
                            : null,
                        decoration: _inputDecoration(
                          label: 'Category',
                          icon: Icons.category_outlined,
                        ),
                        items: categories
                            .map(
                              (category) => DropdownMenuItem<String>(
                                value: category.id,
                                child: Text(category.name),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          final category = categories.firstWhere(
                            (item) => item.id == value,
                          );
                          setState(() {
                            _categoryId = category.id;
                            _categoryName = category.name;
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Select a category';
                          }
                          return null;
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  BlocBuilder<WalletBloc, WalletState>(
                    builder: (context, state) {
                      return DropdownButtonFormField<String>(
                        initialValue: state.wallets.any(
                          (item) => item.id == _walletId,
                        )
                            ? _walletId
                            : null,
                        decoration: _inputDecoration(
                          label: 'Wallet',
                          icon: Icons.account_balance_wallet_outlined,
                        ),
                        items: state.wallets
                            .map(
                              (wallet) => DropdownMenuItem<String>(
                                value: wallet.id,
                                child: Text(wallet.name),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            _walletId = value;
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
                  ),
                  const SizedBox(height: 16),
                  _sectionLabel('Payment method'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: PaymentMethod.values.map((method) {
                      final selected = method == _paymentMethod;
                      return ChoiceChip(
                        selected: selected,
                        label: Text(
                          _paymentLabel(method),
                        ),
                        avatar: Icon(
                          _paymentIcon(method),
                          size: 18,
                        ),
                        onSelected: (_) {
                          setState(() {
                            _paymentMethod = method;
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  _sectionLabel('Frequency'),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<RecurringFrequency>(
                    initialValue: _frequency,
                    decoration: _inputDecoration(
                      label: 'Repeat',
                      icon: Icons.repeat_rounded,
                    ),
                    items: RecurringFrequency.values
                        .map(
                          (frequency) =>
                              DropdownMenuItem<RecurringFrequency>(
                            value: frequency,
                            child: Text(frequency.label),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setState(() {
                        _frequency = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  _sectionLabel('Start date'),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 15,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness ==
                                Brightness.dark
                            ? AppColors.darkSurface
                            : AppColors.lightSurface,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.event_rounded),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              DateFormat(
                                'dd MMM yyyy',
                              ).format(_startDate),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 2,
                    decoration: _inputDecoration(
                      label: 'Note (optional)',
                      icon: Icons.notes_rounded,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Active',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: const Text(
                      'Create this transaction automatically when due.',
                    ),
                    value: _active,
                    onChanged: (value) {
                      setState(() {
                        _active = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _type == TransactionType.income
                                ? AppColors.income
                                : AppColors.expense,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child:CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor:
                                AlwaysStoppedAnimation<
                                    Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : Text(
                              _editing ? 'Save Changes' : 'Create Schedule',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  CategoryType get _categoryType {
    return _type == TransactionType.income
        ? CategoryType.income
        : CategoryType.expense;
  }

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
    final selected = _type == type;
    final color = type == TransactionType.income
        ? AppColors.income
        : AppColors.expense;

    return GestureDetector(
      onTap: () {
        if (_type == type) {
          return;
        }

        setState(() {
          _type = type;
          _categoryId = null;
          _categoryName = null;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: selected ? color : Colors.transparent,
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

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: Theme.of(context).brightness == Brightness.dark
          ? AppColors.darkSurface
          : AppColors.lightSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.w800,
      ),
    );
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
}

class _RecurringCard extends StatelessWidget {
  final RecurringTransactionEntity item;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _RecurringCard({
    required this.item,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isIncome = item.type == TransactionType.income;
    final color = isIncome ? AppColors.income : AppColors.expense;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? AppColors.darkSurface
            : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: item.active
              ? color.withValues(alpha: 0.18)
              : theme.dividerColor.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.11),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  item.type == TransactionType.income
                      ? Icons.arrow_downward_rounded
                      : Icons.arrow_upward_rounded,
                  color: color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.description.isEmpty
                          ? item.categoryName
                          : item.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${item.categoryName} • ${item.walletName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color:
                            theme.textTheme.bodySmall?.color?.withValues(
                          alpha: 0.55,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'toggle') {
                    onToggle();
                  } else if (value == 'delete') {
                    onDelete();
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem<String>(
                    value: 'toggle',
                    child: Text(
                      item.active ? 'Pause' : 'Activate',
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'delete',
                    child: Text('Delete'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Next: ${DateFormat('dd MMM yyyy').format(item.nextDueDate)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                _frequencyLabel(item.frequency),
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _formatAmountWidget(context, item.amount),
              ),
              Switch.adaptive(
                value: item.active,
                onChanged: (_) => onToggle(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _formatAmountWidget(BuildContext context, double amount) {
    return BlocBuilder<CurrencyCubit, CurrencyState>(
      builder: (context, currencyState) {
        return Text(
          CurrencyFormatter.formatCompact(
            amount,
            currencyState.currency,
          ),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: item.type == TransactionType.income
                    ? AppColors.income
                    : AppColors.expense,
                fontWeight: FontWeight.w800,
              ),
        );
      },
    );
  }
}

class _EmptyRecurringState extends StatelessWidget {
  const _EmptyRecurringState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? AppColors.darkSurface
            : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.repeat_rounded,
            size: 56,
            color: AppColors.primary,
          ),
          SizedBox(height: 14),
          Text(
            'No recurring transactions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 7),
          Text(
            'Create a schedule for salary, rent, EMI, subscriptions, or any other repeated transaction.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

String _frequencyLabel(RecurringFrequency frequency) {
  return frequency.label;
}
