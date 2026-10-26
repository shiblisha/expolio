import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/currency/currency_cubit.dart';
import '../../../../core/currency/currency_state.dart';
import '../../../../core/enums/app_currency.dart';
import '../../../../shared/widgets/currency_text.dart';
import '../../../../core/enums/transaction_type.dart';
import '../../../../core/enums/wallet_type.dart';
import '../../../bills/presentation/bloc/bill_bloc.dart';
import '../../../transactions/presentation/bloc/transaction_bloc.dart';
import '../../../transactions/presentation/bloc/transaction_state.dart';
import '../../domain/entities/wallet_entity.dart';
import '../bloc/wallet_bloc.dart';
import '../bloc/wallet_event.dart';
import '../bloc/wallet_state.dart';

class WalletPage extends StatelessWidget {
  const WalletPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Wallets',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () {
              _showWalletDialog(context);
            },
            icon: const Icon(
              Icons.add_rounded,
            ),
          ),
        ],
      ),
      body: BlocBuilder<WalletBloc, WalletState>(
        builder: (context, walletState) {
          return BlocBuilder<TransactionBloc,
              TransactionState>(
            builder: (context, transactionState) {
              final wallets =
                  walletState.wallets;

              final transactions =
                  transactionState.transactions;

              final walletBalances =
              <String, double>{};

              for (final wallet in wallets) {
                walletBalances[wallet.id] =
                    wallet.initialBalance;

                for (final transaction
                in transactions) {
                  if (transaction.type ==
                      TransactionType.income) {
                    if (transaction.walletId ==
                        wallet.id) {
                      walletBalances[wallet.id] =
                          (walletBalances[
                          wallet.id] ??
                              0) +
                              transaction.amount;
                    }
                  }

                  if (transaction.type ==
                      TransactionType.expense) {
                    if (transaction.walletId ==
                        wallet.id) {
                      walletBalances[wallet.id] =
                          (walletBalances[
                          wallet.id] ??
                              0) -
                              transaction.amount;
                    }
                  }

                  if (transaction.type ==
                      TransactionType.transfer) {
                    if (transaction.fromWalletId ==
                        wallet.id) {
                      walletBalances[wallet.id] =
                          (walletBalances[
                          wallet.id] ??
                              0) -
                              transaction.amount;
                    }

                    if (transaction.toWalletId ==
                        wallet.id) {
                      walletBalances[wallet.id] =
                          (walletBalances[
                          wallet.id] ??
                              0) +
                              transaction.amount;
                    }
                  }
                }
              }

              final totalBalance =
              walletBalances.values.fold<double>(
                0,
                    (total, balance) =>
                total + balance,
              );

              return ListView(
                physics:
                const BouncingScrollPhysics(),
                padding:
                const EdgeInsets.fromLTRB(
                  20,
                  8,
                  20,
                  110,
                ),
                children: [
                  _buildTotalBalance(
                    context,
                    totalBalance,
                  ),

                  const SizedBox(height: 24),

                  if (wallets.isEmpty)
                    _buildEmpty(context)
                  else
                    ...wallets.map(
                          (wallet) {
                        return Padding(
                          padding:
                          const EdgeInsets.only(
                            bottom: 12,
                          ),
                          child: _WalletCard(
                            wallet: wallet,
                            balance:
                            walletBalances[
                            wallet.id] ??
                                0,
                            onEdit: () {
                              _showWalletDialog(
                                context,
                                existingWallet:
                                wallet,
                              );
                            },
                            onDelete: () {
                              _confirmDelete(
                                context,
                                wallet,
                              );
                            },
                          ),
                        );
                      },
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildTotalBalance(
      BuildContext context,
      double balance,
      ) {
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
        borderRadius:
        BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Text(
            'Total Wallet Balance',
            style: TextStyle(
              color:
              Colors.white.withValues(alpha: 0.70),
              fontSize: 13,
              fontWeight:
              FontWeight.w600,
            ),
          ),

          const SizedBox(height: 7),

          CurrencyText(
            balance,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'Across all your wallets',
            style: TextStyle(
              color:
              Colors.white.withValues(alpha: 0.60),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(
      BuildContext context,
      ) {
    final theme =
    Theme.of(context);

    return Container(
      padding:
      const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color:
        theme.brightness ==
            Brightness.dark
            ? AppColors.darkSurface
            : AppColors.lightSurface,
        borderRadius:
        BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration:
            BoxDecoration(
              color: AppColors.primary
                  .withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons
                  .account_balance_wallet_rounded,
              color: AppColors.primary,
              size: 34,
            ),
          ),

          const SizedBox(height: 16),

          Text(
            'No wallets yet',
            style: theme
                .textTheme
                .titleMedium
                ?.copyWith(
              fontWeight:
              FontWeight.w800,
            ),
          ),

          const SizedBox(height: 7),

          Text(
            'Create a wallet to start tracking where your money is.',
            textAlign:
            TextAlign.center,
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

          const SizedBox(height: 18),

          ElevatedButton.icon(
            onPressed: () {
              _showWalletDialog(
                context,
              );
            },
            icon: const Icon(
              Icons.add_rounded,
            ),
            label: const Text(
              'Create Wallet',
            ),
          ),
        ],
      ),
    );
  }

  void _showWalletDialog(
      BuildContext context, {
        WalletEntity? existingWallet,
      }) {
    final nameController =
    TextEditingController(
      text:
      existingWallet?.name ?? '',
    );

    final balanceController =
    TextEditingController(
      text: existingWallet?.initialBalance
          .toString() ??
          '',
    );

    WalletType selectedType =
        existingWallet?.type ??
            WalletType.cash;

    showDialog(
      context: context,
      useRootNavigator: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (
              context,
              setDialogState,
              ) {
            final editing =
                existingWallet != null;

            return AlertDialog(
              title: Text(
                editing
                    ? 'Edit Wallet'
                    : 'Create Wallet',
                style:
                const TextStyle(
                  fontWeight:
                  FontWeight.w800,
                ),
              ),
              content:
              SingleChildScrollView(
                child: Column(
                  mainAxisSize:
                  MainAxisSize.min,
                  crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
                  children: [
                    const Text(
                      'Wallet name',
                      style:
                      TextStyle(
                        fontWeight:
                        FontWeight.w700,
                      ),
                    ),

                    const SizedBox(
                      height: 8,
                    ),

                    TextField(
                      controller:
                      nameController,
                      textCapitalization:
                      TextCapitalization
                          .words,
                      decoration:
                      const InputDecoration(
                        hintText:
                        'e.g. HDFC Bank',
                        border:
                        OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(
                      height: 18,
                    ),

                    const Text(
                      'Wallet type',
                      style:
                      TextStyle(
                        fontWeight:
                        FontWeight.w700,
                      ),
                    ),

                    const SizedBox(
                      height: 8,
                    ),

                    DropdownButtonFormField<
                        WalletType>(
                      initialValue:
                      selectedType,
                      decoration:
                      const InputDecoration(
                        border:
                        OutlineInputBorder(),
                      ),
                      items:
                      WalletType.values
                          .map(
                            (type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Text(
                              _walletTypeLabel(
                                type,
                              ),
                            ),
                          );
                        },
                      ).toList(),
                      onChanged:
                          (value) {
                        if (value !=
                            null) {
                          setDialogState(
                                () {
                              selectedType =
                                  value;
                            },
                          );
                        }
                      },
                    ),

                    const SizedBox(
                      height: 18,
                    ),

                    const Text(
                      'Initial balance',
                      style:
                      TextStyle(
                        fontWeight:
                        FontWeight.w700,
                      ),
                    ),

                    const SizedBox(
                      height: 8,
                    ),

                    BlocBuilder<CurrencyCubit, CurrencyState>(
                      builder: (context, currencyState) {
                        return TextField(
                          controller: balanceController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            prefixText: '${currencyState.currency.symbol} ',
                            hintText: '0.00',
                            border: const OutlineInputBorder(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(
                      dialogContext,
                    );
                  },
                  child: const Text(
                    'Cancel',
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    final name =
                    nameController
                        .text
                        .trim();

                    final balance =
                    double.tryParse(
                      balanceController
                          .text
                          .trim(),
                    );

                    if (name.isEmpty ||
                        balance == null) {
                      return;
                    }

                    final user =
                        FirebaseAuth
                            .instance
                            .currentUser;

                    if (user == null) {
                      return;
                    }

                    final wallet =
                    WalletEntity(
                      id:
                      existingWallet
                          ?.id ??
                          '',
                      userId: user.uid,
                      name: name,
                      type:
                      selectedType,
                      initialBalance:
                      balance,
                      createdAt:
                      existingWallet
                          ?.createdAt ??
                          DateTime.now(),
                    );

                    if (editing) {
                      context
                          .read<WalletBloc>()
                          .add(
                        UpdateWalletEvent(
                          wallet,
                        ),
                      );
                    } else {
                      context
                          .read<WalletBloc>()
                          .add(
                        AddWalletEvent(
                          wallet,
                        ),
                      );
                    }

                    Navigator.pop(
                      dialogContext,
                    );
                  },
                  child: Text(
                    editing
                        ? 'Update'
                        : 'Save',
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDelete(
      BuildContext context,
      WalletEntity wallet,
      ) async {
    // ------------------------------------------------------------
    // CHECK WHETHER THIS WALLET IS USED
    // ------------------------------------------------------------

    final transactionState =
        context.read<TransactionBloc>().state;

    final billState =
        context.read<BillBloc>().state;

    final linkedTransactions =
        transactionState.transactions.where((transaction) {
          return transaction.walletId == wallet.id ||
              transaction.fromWalletId == wallet.id ||
              transaction.toWalletId == wallet.id;
        }).length;

    final linkedBills =
        billState.bills.where((bill) {
          return bill.walletId == wallet.id;
        }).length;

    final hasLinkedRecords =
        linkedTransactions > 0 || linkedBills > 0;

    // ------------------------------------------------------------
    // BLOCK DELETE WHEN WALLET IS IN USE
    // ------------------------------------------------------------

    if (hasLinkedRecords) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          final recordParts = <String>[];

          if (linkedTransactions > 0) {
            recordParts.add(
              '$linkedTransactions ${linkedTransactions == 1 ? 'transaction' : 'transactions'}',
            );
          }

          if (linkedBills > 0) {
            recordParts.add(
              '$linkedBills ${linkedBills == 1 ? 'bill' : 'bills'}',
            );
          }

          final recordsText = recordParts.join(' and ');

          return AlertDialog(
            title: const Text(
              'Cannot delete wallet',
              style: TextStyle(
                fontWeight: FontWeight.w800,
              ),
            ),
            content: Text(
              '"${wallet.name}" is currently linked to $recordsText.\n\nDelete or move those records first, then you can delete this wallet.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                },
                child: const Text('OK'),
              ),
            ],
          );
        },
      );

      return;
    }

    // ------------------------------------------------------------
    // NORMAL DELETE CONFIRMATION
    // ------------------------------------------------------------

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Delete wallet?',
            style: TextStyle(
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            'Delete "${wallet.name}"? This wallet has no linked transactions or bills.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
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
      context.read<WalletBloc>().add(
        DeleteWalletEvent(wallet.id),
      );
    }
  }

  static String _walletTypeLabel(
      WalletType type,
      ) {
    switch (type) {
      case WalletType.cash:
        return 'Cash';

      case WalletType.bank:
        return 'Bank Account';

      case WalletType.upi:
        return 'UPI';

      case WalletType.card:
        return 'Credit / Debit Card';

      case WalletType.savings:
        return 'Savings';

      case WalletType.other:
        return 'Other';
    }
  }
}

// ================================================================
// WALLET CARD
// ================================================================

class _WalletCard
    extends StatelessWidget {
  final WalletEntity wallet;
  final double balance;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _WalletCard({
    required this.wallet,
    required this.balance,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    final theme =
    Theme.of(context);

    return Container(
      padding:
      const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color:
        theme.brightness ==
            Brightness.dark
            ? AppColors.darkSurface
            : AppColors.lightSurface,
        borderRadius:
        BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration:
            BoxDecoration(
              color: AppColors.primary
                  .withValues(alpha: 0.11),
              borderRadius:
              BorderRadius.circular(
                15,
              ),
            ),
            child: Icon(
              _walletIcon(
                wallet.type,
              ),
              color:
              AppColors.primary,
            ),
          ),

          const SizedBox(width: 13),

          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment
                  .start,
              children: [
                Text(
                  wallet.name,
                  style: theme
                      .textTheme
                      .titleSmall
                      ?.copyWith(
                    fontWeight:
                    FontWeight.w800,
                  ),
                ),

                const SizedBox(
                  height: 4,
                ),

                Text(
                  _walletTypeLabel(
                    wallet.type,
                  ),
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

                const SizedBox(
                  height: 7,
                ),

                CurrencyText(
                  balance,
                  style: TextStyle(
                    color: balance >= 0
                        ? AppColors.income
                        : AppColors.expense,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),

          PopupMenuButton<String>(
            onSelected:
                (value) {
              if (value ==
                  'edit') {
                onEdit();
              }

              if (value ==
                  'delete') {
                onDelete();
              }
            },
            itemBuilder:
                (context) => [
              const PopupMenuItem(
                value: 'edit',
                child:
                Text('Edit'),
              ),
              const PopupMenuItem(
                value: 'delete',
                child:
                Text('Delete'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _walletIcon(
      WalletType type,
      ) {
    switch (type) {
      case WalletType.cash:
        return Icons.payments_rounded;

      case WalletType.bank:
        return Icons.account_balance_rounded;

      case WalletType.upi:
        return Icons.qr_code_rounded;

      case WalletType.card:
        return Icons.credit_card_rounded;

      case WalletType.savings:
        return Icons.savings_rounded;

      case WalletType.other:
        return Icons
            .account_balance_wallet_rounded;
    }
  }

  String _walletTypeLabel(
      WalletType type,
      ) {
    switch (type) {
      case WalletType.cash:
        return 'Cash';

      case WalletType.bank:
        return 'Bank Account';

      case WalletType.upi:
        return 'UPI';

      case WalletType.card:
        return 'Credit / Debit Card';

      case WalletType.savings:
        return 'Savings';

      case WalletType.other:
        return 'Other';
    }
  }
}
