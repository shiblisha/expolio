import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/currency/currency_cubit.dart';
import '../../../../core/currency/currency_state.dart';
import '../../../../core/enums/app_currency.dart';
import '../../../../core/enums/payment_method.dart';
import '../../../../core/enums/transaction_type.dart';
import '../../../../shared/widgets/app_loading_indicator.dart';
import '../../../wallet/presentation/bloc/wallet_bloc.dart';
import '../../../wallet/presentation/bloc/wallet_state.dart';
import '../../domain/entities/transaction_entity.dart';
import '../bloc/transaction_bloc.dart';
import '../bloc/transaction_event.dart';
import '../bloc/transaction_state.dart';



class TransferPage extends StatefulWidget {
  const TransferPage({super.key});

  @override
  State<TransferPage> createState() => _TransferPageState();
}

class _TransferPageState extends State<TransferPage> {
  final _formKey = GlobalKey<FormState>();

  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  String? _fromWalletId;
  String? _toWalletId;

  DateTime _selectedDate = DateTime.now();

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Transfer Money',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
      ),
      body: BlocListener<TransactionBloc, TransactionState>(
        listener: (context, state) {
          // --------------------------------------------------------
          // TRANSFER SAVED
          // --------------------------------------------------------

          if (state.saveSuccess) {
            Navigator.of(context).pop();
            return;
          }

          // --------------------------------------------------------
          // ERROR
          // --------------------------------------------------------

          if (state.status == TransactionStatus.failure &&
              state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage!),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        child: BlocBuilder<WalletBloc, WalletState>(
          builder: (context, walletState) {
            final wallets = walletState.wallets;

            // ------------------------------------------------------
            // NEED TWO WALLETS
            // ------------------------------------------------------

            if (wallets.length < 2) {
              return _buildNeedWallets(context);
            }

            return SafeArea(
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ------------------------------------------------
                            // TRANSFER ICON
                            // ------------------------------------------------

                            _buildTransferIcon(),

                            const SizedBox(height: 28),

                            // ------------------------------------------------
                            // FROM WALLET
                            // ------------------------------------------------
                            _buildSectionTitle('From wallet'),

                            const SizedBox(height: 10),

                            _buildWalletDropdown(
                              value: _fromWalletId,
                              wallets: wallets,
                              hint: 'Select source wallet',
                              onChanged: (value) {
                                setState(() {
                                  _fromWalletId = value;
                                });
                              },
                            ),

                            const SizedBox(height: 22),

                            // ------------------------------------------------
                            // TO WALLET
                            // ------------------------------------------------
                            _buildSectionTitle('To wallet'),

                            const SizedBox(height: 10),

                            _buildWalletDropdown(
                              value: _toWalletId,
                              wallets: wallets,
                              hint: 'Select destination wallet',
                              onChanged: (value) {
                                setState(() {
                                  _toWalletId = value;
                                });
                              },
                            ),

                            const SizedBox(height: 24),

                            // ------------------------------------------------
                            // AMOUNT
                            // ------------------------------------------------
                            _buildSectionTitle('Amount'),

                            const SizedBox(height: 10),

                            BlocBuilder<CurrencyCubit, CurrencyState>(
                              builder: (context, currencyState) {
                                return TextFormField(
                                  controller: _amountController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  style: const TextStyle(
                                    fontSize: 30,
                                    fontWeight: FontWeight.w800,
                                  ),
                                  decoration: InputDecoration(
                                    prefixText:
                                        '${currencyState.currency.symbol} ',
                                    hintText: '0.00',
                                    filled: true,
                                    fillColor:
                                        Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? AppColors.darkSurface
                                        : AppColors.lightSurface,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(18),
                                      borderSide: BorderSide.none,
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
                                );
                              },
                            ),

                            const SizedBox(height: 24),

                            // ------------------------------------------------
                            // DATE
                            // ------------------------------------------------
                            _buildSectionTitle('Date'),

                            const SizedBox(height: 10),

                            GestureDetector(
                              onTap: _pickDate,
                              child: Container(
                                padding: const EdgeInsets.all(15),
                                decoration: BoxDecoration(
                                  color:
                                      Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? AppColors.darkSurface
                                      : AppColors.lightSurface,
                                  borderRadius: BorderRadius.circular(17),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.calendar_month_rounded,
                                      color: AppColors.primary,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      '${_selectedDate.day.toString().padLeft(2, '0')}/'
                                      '${_selectedDate.month.toString().padLeft(2, '0')}/'
                                      '${_selectedDate.year}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 24),

                            // ------------------------------------------------
                            // NOTE
                            // ------------------------------------------------
                            _buildSectionTitle('Note'),

                            const SizedBox(height: 10),

                            TextField(
                              controller: _noteController,
                              maxLines: 3,
                              decoration: InputDecoration(
                                hintText: 'Optional note',
                                filled: true,
                                fillColor:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? AppColors.darkSurface
                                    : AppColors.lightSurface,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(18),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // --------------------------------------------------------
                    // SAVE BUTTON
                    // --------------------------------------------------------
                    _buildSaveButton(),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ================================================================
  // TRANSFER ICON
  // ================================================================

  Widget _buildTransferIcon() {
    return Center(
      child: Container(
        width: 78,
        height: 78,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.swap_vert_rounded,
          color: AppColors.primary,
          size: 40,
        ),
      ),
    );
  }

  // ================================================================
  // SECTION TITLE
  // ================================================================

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium
          ?.copyWith(fontWeight: FontWeight.w800),
    );
  }

  // ================================================================
  // WALLET DROPDOWN
  // ================================================================

  Widget _buildWalletDropdown({
    required String? value,
    required List wallets,
    required String hint,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        filled: true,
        fillColor: Theme.of(context).brightness == Brightness.dark
            ? AppColors.darkSurface
            : AppColors.lightSurface,
        prefixIcon: const Icon(Icons.account_balance_wallet_rounded),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: BorderSide.none,
        ),
      ),
      hint: Text(hint),
      items: wallets.map<DropdownMenuItem<String>>((wallet) {
        return DropdownMenuItem<String>(
          value: wallet.id,
          child: Text(wallet.name),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  // ================================================================
  // SAVE BUTTON
  // ================================================================

  Widget _buildSaveButton() {
    return BlocBuilder<TransactionBloc, TransactionState>(
      builder: (context, state) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: state.isSaving ? null : _saveTransfer,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: state.isSaving
                  ? const SizedBox(
                      width: 23,
                      height: 23,
                      child: AppLoadingIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Text(
                      'Transfer Money',
                      style: TextStyle(
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

  // ================================================================
  // DATE PICKER
  // ================================================================

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme
                .copyWith(primary: AppColors.primary),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  // ================================================================
  // SAVE TRANSFER
  // ================================================================

  void _saveTransfer() {
    // --------------------------------------------------------------
    // VALIDATE FORM
    // --------------------------------------------------------------

    if (!_formKey.currentState!.validate()) {
      return;
    }

    // --------------------------------------------------------------
    // VALIDATE WALLETS
    // --------------------------------------------------------------

    if (_fromWalletId == null || _toWalletId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select both wallets'),
          behavior: SnackBarBehavior.floating,
        ),
      );

      return;
    }

    // --------------------------------------------------------------
    // SAME WALLET CHECK
    // --------------------------------------------------------------

    if (_fromWalletId == _toWalletId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Source and destination wallets must be different'),
          behavior: SnackBarBehavior.floating,
        ),
      );

      return;
    }

    // --------------------------------------------------------------
    // PARSE AMOUNT
    // --------------------------------------------------------------

    final amount = double.tryParse(_amountController.text.trim());

    if (amount == null || amount <= 0) {
      return;
    }

    // --------------------------------------------------------------
    // GET WALLET STATE
    // --------------------------------------------------------------

    final walletState = context.read<WalletBloc>().state;

    final fromWallet = walletState.wallets.firstWhere(
      (wallet) => wallet.id == _fromWalletId,
    );

    final toWallet = walletState.wallets.firstWhere(
      (wallet) => wallet.id == _toWalletId,
    );

    // --------------------------------------------------------------
    // GET CURRENT USER
    // --------------------------------------------------------------

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

    // --------------------------------------------------------------
    // CREATE TRANSFER TRANSACTION
    // --------------------------------------------------------------

    final transaction = TransactionEntity(
      id: '',
      userId: user.uid,
      amount: amount,
      type: TransactionType.transfer,
      categoryId: 'transfer',
      categoryName: 'Transfer',
      paymentMethod: PaymentMethod.bank,
      description: _noteController.text.trim(),
      date: _selectedDate,
      createdAt: DateTime.now(),
      fromWalletId: fromWallet.id,
      fromWalletName: fromWallet.name,
      toWalletId: toWallet.id,
      toWalletName: toWallet.name,
    );

    // --------------------------------------------------------------
    // SEND TO BLOC
    // --------------------------------------------------------------

    context.read<TransactionBloc>().add(AddTransactionEvent(transaction));
  }

  // ================================================================
  // NEED WALLETS
  // ================================================================

  Widget _buildNeedWallets(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.swap_vert_rounded,
              color: AppColors.primary,
              size: 60,
            ),

            const SizedBox(height: 18),

            const Text(
              'Create at least two wallets',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),

            const SizedBox(height: 8),

            const Text(
              'You need two wallets to make a transfer.',
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 20),

            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
              },
              icon: const Icon(Icons.account_balance_wallet_rounded),
              label: const Text('Go to Wallets'),
            ),
          ],
        ),
      ),
    );
  }
}
