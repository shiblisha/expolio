import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/enums/transaction_type.dart';
import '../../../../shared/widgets/currency_text.dart';
import '../../domain/entities/transaction_entity.dart';
import '../bloc/transaction_bloc.dart';
import '../bloc/transaction_event.dart';
import '../bloc/transaction_state.dart';

import '../../../bills/presentation/bloc/bill_bloc.dart';
import '../../../bills/presentation/bloc/bill_event.dart';

import 'add_transaction_page.dart';

class TransactionsPage extends StatelessWidget {
  const TransactionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Transactions',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
      ),
      body: BlocBuilder<TransactionBloc, TransactionState>(
        builder: (context, state) {
          if (state.status == TransactionStatus.loading &&
              state.transactions.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
              ),
            );
          }

          if (state.transactions.isEmpty) {
            return _EmptyTransactions(theme: theme);
          }

          return ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              20,
              8,
              20,
              110,
            ),
            itemCount: state.transactions.length,
            itemBuilder: (context, index) {
              final transaction = state.transactions[index];

              final isBillPayment =
              transaction.id.startsWith('bill_');

              final isGoalContribution =
                  transaction.type == TransactionType.transfer &&
                      transaction.categoryId == 'savings_goal';

              return Padding(
                padding: const EdgeInsets.only(
                  bottom: 10,
                ),
                child: Dismissible(
                  key: Key(
                    'transaction_${transaction.id}',
                  ),
                  direction: DismissDirection.endToStart,

                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(
                      right: 22,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.expense,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.white,
                    ),
                  ),

                  confirmDismiss: (_) async {
                    return await _confirmDelete(
                      context,
                      isBillPayment: isBillPayment,
                      isGoalContribution: isGoalContribution,
                    );
                  },

                  onDismissed: (_) {
                    _deleteTransaction(
                      context,
                      transaction,
                    );
                  },

                  child: _TransactionCard(
                    transaction: transaction,
                    isBillPayment: isBillPayment,

                    // ------------------------------------------------
                    // EDIT
                    // ------------------------------------------------
                    onEdit:
                    (transaction.type ==
                        TransactionType.transfer ||
                        isBillPayment)
                        ? null
                        : () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              AddTransactionPage(
                                transaction: transaction,
                              ),
                        ),
                      );
                    },

                    // ------------------------------------------------
                    // DELETE
                    // ------------------------------------------------
                    onDelete: () async {
                      final confirmed =
                      await _confirmDelete(
                        context,
                        isBillPayment:
                        isBillPayment,
                        isGoalContribution:
                        isGoalContribution,
                      );

                      if (confirmed &&
                          context.mounted) {
                        _deleteTransaction(
                          context,
                          transaction,
                        );
                      }
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // ================================================================
  // DELETE TRANSACTION
  // ================================================================

  Future<void> _deleteTransaction(
      BuildContext context,
      TransactionEntity transaction,
      ) async {
    final isGoalContribution =
        transaction.type == TransactionType.transfer &&
            transaction.categoryId == 'savings_goal';

    // ============================================================
    // SAVINGS GOAL CONTRIBUTION
    // ============================================================
    //
    // A savings goal contribution is represented as a transfer:
    //
    // wallet -> savings goal
    //
    // Therefore we must NOT simply delete the transaction.
    //
    // We must:
    //
    // 1. Find the goal
    // 2. Remove the contribution from the goal
    // 3. Reduce currentAmount
    // 4. Delete the linked transaction
    //
    // These operations are performed inside one Firestore
    // transaction.
    // ============================================================

    if (isGoalContribution) {
      try {
        final user =
            FirebaseAuth.instance.currentUser;

        if (user == null) {
          throw StateError(
            'User is not authenticated',
          );
        }

        const prefix =
            'goal_contribution_';

        if (!transaction.id.startsWith(prefix)) {
          throw StateError(
            'Invalid savings goal contribution transaction',
          );
        }

        final contributionId =
        transaction.id.substring(
          prefix.length,
        );

        if (contributionId.isEmpty) {
          throw StateError(
            'Savings contribution ID is missing',
          );
        }

        final firestore =
            FirebaseFirestore.instance;

        // ----------------------------------------------------------
        // FIND THE GOAL
        // ----------------------------------------------------------
        //
        // TransactionEntity currently does not expose goalId, so
        // we locate the goal by searching the user's goals for
        // the matching contribution ID.
        // ----------------------------------------------------------

        final goalsSnapshot = await firestore
            .collection('savings_goals')
            .where(
          'userId',
          isEqualTo: user.uid,
        )
            .get();

        String? goalId;

        for (final goalDoc
        in goalsSnapshot.docs) {
          final goalData = goalDoc.data();

          final rawContributions =
          goalData['contributions'];

          if (rawContributions is! List) {
            continue;
          }

          for (final item
          in rawContributions) {
            if (item is! Map) {
              continue;
            }

            final itemId =
                item['id']?.toString() ?? '';

            if (itemId ==
                contributionId) {
              goalId = goalDoc.id;
              break;
            }
          }

          if (goalId != null) {
            break;
          }
        }

        if (goalId == null) {
          throw StateError(
            'Savings goal for this contribution was not found',
          );
        }

        // ----------------------------------------------------------
        // REFERENCES
        // ----------------------------------------------------------

        final goalRef = firestore
            .collection('savings_goals')
            .doc(goalId);

        final linkedTransactionRef =
        firestore
            .collection('users')
            .doc(user.uid)
            .collection('transactions')
            .doc(transaction.id);

        // ----------------------------------------------------------
        // ATOMIC DELETE
        // ----------------------------------------------------------

        await firestore.runTransaction(
              (firestoreTransaction) async {
            // ------------------------------------------------------
            // READ GOAL
            // ------------------------------------------------------

            final goalSnapshot =
            await firestoreTransaction.get(
              goalRef,
            );

            final goalData =
            goalSnapshot.data();

            if (!goalSnapshot.exists ||
                goalData == null ||
                goalData['userId'] !=
                    user.uid) {
              throw StateError(
                'Savings goal not found',
              );
            }

            // ------------------------------------------------------
            // READ CONTRIBUTIONS
            // ------------------------------------------------------

            final rawContributions =
            goalData['contributions'];

            final keptContributions =
            <Map<String, dynamic>>[];

            double removedAmount = 0.0;
            bool foundContribution = false;

            if (rawContributions is List) {
              for (final item
              in rawContributions) {
                if (item is! Map) {
                  continue;
                }

                final map =
                Map<String, dynamic>.from(
                  item,
                );

                final itemId =
                    map['id']?.toString() ?? '';

                if (itemId ==
                    contributionId) {
                  removedAmount =
                      (map['amount'] as num?)
                          ?.toDouble() ??
                          0.0;

                  foundContribution = true;
                } else {
                  keptContributions.add(
                    map,
                  );
                }
              }
            }

            // ------------------------------------------------------
            // VALIDATE
            // ------------------------------------------------------

            if (!foundContribution ||
                removedAmount <= 0) {
              throw StateError(
                'Contribution not found',
              );
            }

            // ------------------------------------------------------
            // CURRENT GOAL AMOUNT
            // ------------------------------------------------------

            final currentAmount =
                (goalData['currentAmount']
                as num?)
                    ?.toDouble() ??
                    0.0;

            final nextAmount =
            (currentAmount -
                removedAmount)
                .clamp(
              0.0,
              double.infinity,
            )
                .toDouble();

            // ------------------------------------------------------
            // DELETE LINKED TRANSACTION
            // ------------------------------------------------------
            //
            // Wallet balances are calculated from the transaction
            // history. Removing this transfer restores the money
            // to the source wallet automatically.
            // ------------------------------------------------------

            firestoreTransaction.delete(
              linkedTransactionRef,
            );

            // ------------------------------------------------------
            // UPDATE GOAL
            // ------------------------------------------------------

            firestoreTransaction.update(
              goalRef,
              {
                'currentAmount':
                nextAmount,
                'contributions':
                keptContributions,
                'updatedAt':
                FieldValue.serverTimestamp(),
              },
            );
          },
        );

        // ----------------------------------------------------------
        // RELOAD TRANSACTIONS
        // ----------------------------------------------------------

        if (context.mounted) {
          context.read<TransactionBloc>().add(
            const LoadTransactions(),
          );

          ScaffoldMessenger.of(context)
              .showSnackBar(
            const SnackBar(
              content: Text(
                'Savings contribution removed',
              ),
              behavior:
              SnackBarBehavior.floating,
            ),
          );
        }

        return;
      } catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(
            SnackBar(
              content: Text(
                error
                    .toString()
                    .replaceFirst(
                  'Bad state: ',
                  '',
                ),
              ),
              behavior:
              SnackBarBehavior.floating,
            ),
          );

          // Refresh because Dismissible may already
          // have removed the item visually.
          context.read<TransactionBloc>().add(
            const LoadTransactions(),
          );
        }

        return;
      }
    }

    // ============================================================
    // NORMAL TRANSACTION DELETE
    // ============================================================

    context.read<TransactionBloc>().add(
      DeleteTransactionEvent(
        transaction.id,
      ),
    );

    // ============================================================
    // BILL PAYMENT
    // ============================================================

    if (transaction.id.startsWith(
      'bill_',
    )) {
      final billId =
      transaction.id.substring(
        'bill_'.length,
      );

      if (billId.isNotEmpty) {
        context.read<BillBloc>().add(
          DeleteBillEvent(
            billId,
          ),
        );
      }
    }
  }

  // ================================================================
  // DELETE CONFIRMATION
  // ================================================================

  Future<bool> _confirmDelete(
      BuildContext context, {
        bool isBillPayment = false,
        bool isGoalContribution = false,
      }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        String title;

        String content;

        if (isGoalContribution) {
          title =
          'Delete savings contribution?';

          content =
          'This will remove the contribution from the savings goal and restore the amount to the source wallet.';
        } else if (isBillPayment) {
          title = 'Delete bill payment?';

          content =
          'This will delete the payment transaction and the linked bill.';
        } else {
          title = 'Delete transaction?';

          content =
          'This transaction will be permanently deleted.';
        }

        return AlertDialog(
          title: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            content,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text(
                'Cancel',
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              child: const Text(
                'Delete',
                style: TextStyle(
                  color: AppColors.expense,
                  fontWeight:
                  FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }
}

// ================================================================
// TRANSACTION CARD
// ================================================================

class _TransactionCard
    extends StatelessWidget {
  final TransactionEntity transaction;
  final bool isBillPayment;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _TransactionCard({
    required this.transaction,
    required this.isBillPayment,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final isIncome =
        transaction.type ==
            TransactionType.income;

    final isTransfer =
        transaction.type ==
            TransactionType.transfer;

    final isGoalContribution =
        isTransfer &&
            transaction.categoryId ==
                'savings_goal';

    final color = isTransfer
        ? AppColors.primary
        : isIncome
        ? AppColors.income
        : AppColors.expense;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: theme.brightness ==
            Brightness.dark
            ? AppColors.darkSurface
            : AppColors.lightSurface,
        borderRadius:
        BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          // --------------------------------------------------
          // CATEGORY ICON
          // --------------------------------------------------

          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(
                alpha: 0.11,
              ),
              borderRadius:
              BorderRadius.circular(14),
            ),
            child: Icon(
              isGoalContribution
                  ? Icons.savings_rounded
                  : _categoryIcon(
                transaction
                    .categoryName,
              ),
              color: color,
            ),
          ),

          const SizedBox(width: 13),

          // --------------------------------------------------
          // TRANSACTION DETAILS
          // --------------------------------------------------

          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  isGoalContribution
                      ? 'Savings Goal'
                      : isTransfer
                      ? 'Transfer'
                      : transaction
                      .categoryName,
                  style: theme
                      .textTheme
                      .titleSmall
                      ?.copyWith(
                    fontWeight:
                    FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  isGoalContribution
                      ? 'From ${transaction.fromWalletName}'
                      : isTransfer
                      ? '${transaction.fromWalletName} → ${transaction.toWalletName}'
                      : transaction
                      .description
                      .isEmpty
                      ? 'No description'
                      : transaction
                      .description,
                  maxLines: 1,
                  overflow:
                  TextOverflow.ellipsis,
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

                const SizedBox(height: 5),

                Text(
                  DateFormat(
                    'dd MMM yyyy',
                  ).format(
                    transaction.date,
                  ),
                  style: theme
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                    fontSize: 10,
                    color: theme
                        .textTheme
                        .bodySmall
                        ?.color
                        ?.withValues(
                      alpha: 0.45,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // --------------------------------------------------
          // AMOUNT + MENU
          // --------------------------------------------------

          Column(
            mainAxisSize:
            MainAxisSize.min,
            crossAxisAlignment:
            CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize:
                MainAxisSize.min,
                children: [
                  Text(
                    isTransfer
                        ? '↔ '
                        : isIncome
                        ? '+ '
                        : '- ',
                    style: TextStyle(
                      color: color,
                      fontWeight:
                      FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),

                  CurrencyText(
                    transaction.amount,
                    style: TextStyle(
                      color: color,
                      fontWeight:
                      FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 3),

              // ------------------------------------------------
              // ACTION MENU
              // ------------------------------------------------

              PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                constraints:
                const BoxConstraints(
                  minWidth: 36,
                  minHeight: 36,
                ),
                icon: Icon(
                  Icons.more_vert_rounded,
                  size: 21,
                  color: theme
                      .textTheme
                      .bodyMedium
                      ?.color
                      ?.withValues(
                    alpha: 0.65,
                  ),
                ),
                onSelected:
                    (value) {
                  if (value == 'edit' &&
                      onEdit != null) {
                    onEdit!();
                  }

                  if (value == 'delete' &&
                      onDelete != null) {
                    onDelete!();
                  }
                },
                itemBuilder:
                    (context) {
                  return [
                    // Bill-payment transactions
                    // and transfers cannot be edited.
                    if (!isTransfer &&
                        !isBillPayment)
                      const PopupMenuItem<
                          String>(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(
                              Icons
                                  .edit_rounded,
                              size: 19,
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

                    const PopupMenuItem<
                        String>(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons
                                .delete_outline_rounded,
                            size: 19,
                            color:
                            AppColors
                                .expense,
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
                  ];
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ================================================================
  // CATEGORY ICON
  // ================================================================

  IconData _categoryIcon(
      String category,
      ) {
    switch (
    category.toLowerCase()) {
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
        return Icons
            .account_balance_wallet_rounded;

      case 'freelance':
        return Icons.work_rounded;

      case 'transfer':
        return Icons.swap_vert_rounded;

      case 'savings goal':
        return Icons.savings_rounded;

      default:
        return Icons.payments_rounded;
    }
  }
}

// ================================================================
// EMPTY TRANSACTIONS
// ================================================================

class _EmptyTransactions
    extends StatelessWidget {
  final ThemeData theme;

  const _EmptyTransactions({
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding:
        const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment:
          MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration:
              BoxDecoration(
                color: AppColors
                    .primary
                    .withValues(
                  alpha: 0.10,
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons
                    .receipt_long_rounded,
                color:
                AppColors.primary,
                size: 38,
              ),
            ),

            const SizedBox(height: 18),

            Text(
              'No transactions yet',
              style: theme
                  .textTheme
                  .titleLarge
                  ?.copyWith(
                fontWeight:
                FontWeight.w800,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              'Add your first income or expense using the + button.',
              textAlign:
              TextAlign.center,
              style: theme
                  .textTheme
                  .bodyMedium
                  ?.copyWith(
                color: theme
                    .textTheme
                    .bodyMedium
                    ?.color
                    ?.withValues(
                  alpha: 0.55,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}