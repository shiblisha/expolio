import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/currency/currency_cubit.dart';
import '../../../../core/currency/currency_state.dart';
import '../../../../core/enums/app_currency.dart';
import '../../../../shared/widgets/currency_text.dart';

import '../../../wallet/domain/entities/wallet_entity.dart';
import '../../../wallet/presentation/bloc/wallet_bloc.dart';
import '../../../wallet/presentation/pages/wallet_page.dart';

import '../../domain/entities/savings_goal_entity.dart';
import '../bloc/savings_goal_bloc.dart';
import '../bloc/savings_goal_event.dart';
import '../bloc/savings_goal_state.dart';

import 'goals_page.dart';

class AddGoalMoneyPage extends StatefulWidget {
  final String? initialGoalId;

  const AddGoalMoneyPage({
    super.key,
    this.initialGoalId,
  });

  @override
  State<AddGoalMoneyPage> createState() => _AddGoalMoneyPageState();
}


class _AddGoalMoneyPageState
    extends State<AddGoalMoneyPage> {
  final _amountController =
  TextEditingController();

  final _noteController =
  TextEditingController();

  String? _selectedGoalId;

  String? _selectedWalletId;

  bool _saving = false;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _selectedGoalId = widget.initialGoalId;

    final bloc = context.read<SavingsGoalBloc>();

    if (bloc.state.status == SavingsGoalStatusState.initial) {
      bloc.add(const LoadSavingsGoals());
    }
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();

    super.dispose();
  }

  // ============================================================
  // SUBMIT
  // ============================================================

  void _submit() {
    final goalId =
        _selectedGoalId;

    final walletId =
        _selectedWalletId;

    final amount =
    double.tryParse(
      _amountController.text.trim(),
    );

    // ----------------------------------------------------------
    // VALIDATE GOAL
    // ----------------------------------------------------------

    if (goalId == null ||
        goalId.isEmpty) {
      _showMessage(
        'Please select a savings goal',
      );
      return;
    }

    // ----------------------------------------------------------
    // VALIDATE WALLET
    // ----------------------------------------------------------

    if (walletId == null ||
        walletId.isEmpty) {
      _showMessage(
        'Please select a wallet',
      );
      return;
    }

    // ----------------------------------------------------------
    // VALIDATE AMOUNT
    // ----------------------------------------------------------

    if (amount == null ||
        amount <= 0) {
      _showMessage(
        'Enter a valid amount',
      );
      return;
    }

    // ----------------------------------------------------------
    // FIND WALLET
    // ----------------------------------------------------------

    final walletState =
        context.read<WalletBloc>().state;

    WalletEntity? selectedWallet;

    for (final wallet
    in walletState.wallets) {
      if (wallet.id ==
          walletId) {
        selectedWallet =
            wallet;
        break;
      }
    }

    if (selectedWallet == null) {
      _showMessage(
        'Selected wallet not found',
      );
      return;
    }

    // ----------------------------------------------------------
    // FIND GOAL
    //
    // IMPORTANT:
    // We use SavingsGoalEntity here.
    // There is NO Model/Entity mismatch.
    // ----------------------------------------------------------

    final goalState =
        context.read<SavingsGoalBloc>().state;

    SavingsGoalEntity? selectedGoal;

    for (final goal
    in goalState.goals) {
      if (goal.id == goalId) {
        selectedGoal =
            goal;
        break;
      }
    }

    if (selectedGoal == null) {
      _showMessage(
        'Savings goal not found',
      );
      return;
    }

    // ----------------------------------------------------------
    // DON'T ADD MORE THAN REMAINING
    // ----------------------------------------------------------

    if (amount >
        selectedGoal.remainingAmount) {
      _showMessage(
        'Amount is greater than the remaining goal amount',
      );
      return;
    }

    // ----------------------------------------------------------
    // START SAVING
    // ----------------------------------------------------------

    setState(() {
      _saving = true;
    });

    // ----------------------------------------------------------
    // SINGLE BLOC EVENT
    //
    // This event triggers the datasource's atomic operation.
    // ----------------------------------------------------------

    context.read<SavingsGoalBloc>().add(
      AddGoalContributionEvent(
        goalId: selectedGoal.id,
        amount: amount,
        walletId: selectedWallet.id,
        note:
        _noteController.text.trim(),
      ),
    );
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(
      String message,
      ) {
    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
        behavior:
        SnackBarBehavior.floating,
      ),
    );
  }

  // ============================================================
  // CREATE GOAL
  // ============================================================

  void _openCreateGoal() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
        const GoalsPage(),
      ),
    );
  }

  // ============================================================
  // CREATE WALLET
  // ============================================================

  Future<void>
  _openCreateWallet() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
        const WalletPage(),
      ),
    );

    if (mounted) {
      setState(() {});
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    final theme =
    Theme.of(context);

    final isDark =
        theme.brightness ==
            Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Add to Savings Goal',
          style: TextStyle(
            fontWeight:
            FontWeight.w800,
          ),
        ),
        centerTitle: true,
      ),

      body: BlocListener<
          SavingsGoalBloc,
          SavingsGoalState>(
        listener:
            (context, state) {
          // ====================================================
          // ERROR
          // ====================================================

          if (state.status ==
              SavingsGoalStatusState.error) {
            if (mounted) {
              setState(() {
                _saving = false;
              });
            }

            _showMessage(
              state.errorMessage ??
                  'Could not add contribution',
            );

            return;
          }

          // ====================================================
          // SUCCESS
          // ====================================================

          if (_saving &&
              state.status ==
                  SavingsGoalStatusState
                      .loaded) {
            Navigator.of(
              context,
            ).pop(true);
          }
        },

        child: BlocBuilder<
            SavingsGoalBloc,
            SavingsGoalState>(
          builder:
              (context, goalState) {
            // ==================================================
            // ACTIVE GOALS
            // ==================================================

            final activeGoals =
            goalState.goals
                .where(
                  (goal) =>
              goal.status ==
                  SavingsGoalStatus
                      .active,
            )
                .toList();

            // ==================================================
            // LOADING
            // ==================================================

            if (goalState.status ==
                SavingsGoalStatusState
                    .loading &&
                goalState.goals.isEmpty) {
              return const Center(
                child:
                CircularProgressIndicator(
                  color:
                  AppColors.primary,
                ),
              );
            }

            // ==================================================
            // ERROR WITH NO GOALS
            // ==================================================

            if (goalState.status ==
                SavingsGoalStatusState
                    .error &&
                goalState.goals.isEmpty) {
              return Center(
                child: Padding(
                  padding:
                  const EdgeInsets
                      .all(24),
                  child: Column(
                    mainAxisSize:
                    MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons
                            .cloud_off_rounded,
                        color:
                        AppColors
                            .primary,
                        size: 52,
                      ),

                      const SizedBox(
                        height: 14,
                      ),

                      Text(
                        goalState
                            .errorMessage ??
                            'Could not load savings goals',
                        textAlign:
                        TextAlign.center,
                        style: theme
                            .textTheme
                            .bodyLarge,
                      ),

                      const SizedBox(
                        height: 18,
                      ),

                      OutlinedButton
                          .icon(
                        onPressed: () {
                          context
                              .read<
                              SavingsGoalBloc>()
                              .add(
                            const LoadSavingsGoals(),
                          );
                        },
                        icon: const Icon(
                          Icons
                              .refresh_rounded,
                        ),
                        label: const Text(
                          'Retry',
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            // ==================================================
            // NO ACTIVE GOALS
            // ==================================================

            if (activeGoals.isEmpty) {
              return Center(
                child: Padding(
                  padding:
                  const EdgeInsets
                      .all(28),
                  child: Column(
                    mainAxisSize:
                    MainAxisSize.min,
                    children: [
                      Container(
                        width: 74,
                        height: 74,
                        decoration:
                        BoxDecoration(
                          color: AppColors
                              .navPurple
                              .withValues(
                            alpha:
                            0.10,
                          ),
                          shape:
                          BoxShape
                              .circle,
                        ),
                        child:
                        const Icon(
                          Icons
                              .savings_rounded,
                          color: AppColors
                              .navPurple,
                          size: 34,
                        ),
                      ),

                      const SizedBox(
                        height: 16,
                      ),

                      Text(
                        'No active savings goals',
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
                        height: 6,
                      ),

                      Text(
                        'Create a goal first, then add money from one of your wallets.',
                        textAlign:
                        TextAlign
                            .center,
                        style: theme
                            .textTheme
                            .bodyMedium
                            ?.copyWith(
                          color: theme
                              .textTheme
                              .bodyMedium
                              ?.color
                              ?.withValues(
                            alpha:
                            0.60,
                          ),
                        ),
                      ),

                      const SizedBox(
                        height: 20,
                      ),

                      ElevatedButton
                          .icon(
                        onPressed:
                        _openCreateGoal,
                        icon:
                        const Icon(
                          Icons
                              .flag_rounded,
                        ),
                        label:
                        const Text(
                          'Create Goal',
                        ),
                        style:
                        ElevatedButton
                            .styleFrom(
                          backgroundColor:
                          AppColors
                              .navPurple,
                          foregroundColor:
                          Colors.white,
                          elevation: 0,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            // ==================================================
            // VALID GOAL
            // ==================================================

            SavingsGoalEntity
            validGoal;

            if (_selectedGoalId !=
                null) {
              SavingsGoalEntity?
              foundGoal;

              for (final goal
              in activeGoals) {
                if (goal.id ==
                    _selectedGoalId) {
                  foundGoal = goal;
                  break;
                }
              }

              validGoal =
                  foundGoal ??
                      activeGoals.first;
            } else {
              validGoal =
                  activeGoals.first;
            }

            // ==================================================
            // GET WALLETS
            // ==================================================

            final wallets =
            context.select<
                WalletBloc,
                List<WalletEntity>>(
                  (bloc) =>
              bloc.state.wallets,
            );

            // ==================================================
            // DEFAULT GOAL
            // ==================================================

            if (_selectedGoalId ==
                null &&
                activeGoals.isNotEmpty) {
              WidgetsBinding.instance
                  .addPostFrameCallback(
                    (_) {
                  if (!mounted) {
                    return;
                  }

                  if (_selectedGoalId !=
                      null) {
                    return;
                  }

                  setState(() {
                    _selectedGoalId =
                        validGoal.id;
                  });
                },
              );
            }

            // ==================================================
            // DEFAULT WALLET
            // ==================================================

            if (_selectedWalletId ==
                null &&
                wallets.isNotEmpty) {
              WidgetsBinding.instance
                  .addPostFrameCallback(
                    (_) {
                  if (!mounted) {
                    return;
                  }

                  if (_selectedWalletId !=
                      null) {
                    return;
                  }

                  setState(() {
                    _selectedWalletId =
                        wallets.first.id;
                  });
                },
              );
            }

            // ==================================================
            // FIND CURRENT WALLET
            // ==================================================

            WalletEntity?
            validWallet;

            for (final wallet
            in wallets) {
              if (wallet.id ==
                  _selectedWalletId) {
                validWallet =
                    wallet;
                break;
              }
            }

            return SafeArea(
              child:
              SingleChildScrollView(
                physics:
                const BouncingScrollPhysics(),

                padding:
                const EdgeInsets
                    .fromLTRB(
                  20,
                  12,
                  20,
                  30,
                ),

                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
                  children: [
                    // =================================================
                    // GOAL PREVIEW
                    // =================================================

                    _GoalPreview(
                      goal: validGoal,
                    ),

                    const SizedBox(
                      height: 24,
                    ),

                    // =================================================
                    // GOAL SELECT
                    // =================================================

                    Text(
                      'Savings Goal',
                      style: theme
                          .textTheme
                          .titleSmall
                          ?.copyWith(
                        fontWeight:
                        FontWeight
                            .w800,
                      ),
                    ),

                    const SizedBox(
                      height: 10,
                    ),

                    DropdownButtonFormField<
                        String>(
                      isExpanded: true,
                      initialValue:
                      validGoal.id,

                      decoration:
                      InputDecoration(
                        prefixIcon:
                        const Icon(
                          Icons
                              .flag_rounded,
                        ),
                        filled: true,
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
                            16,
                          ),
                          borderSide:
                          BorderSide
                              .none,
                        ),
                      ),

                      items:
                      activeGoals.map(
                            (goal) {
                          return DropdownMenuItem<
                              String>(
                            value: goal.id,
                            child: Text(
                              goal.name,
                              maxLines: 1,
                              overflow:
                              TextOverflow
                                  .ellipsis,
                            ),
                          );
                        },
                      ).toList(),

                      onChanged: _saving
                          ? null
                          : (value) {
                        if (value ==
                            null) {
                          return;
                        }

                        setState(
                              () {
                            _selectedGoalId =
                                value;
                          },
                        );
                      },
                    ),

                    const SizedBox(
                      height: 22,
                    ),

                    // =================================================
                    // WALLET
                    // =================================================

                    Text(
                      'From Wallet',
                      style: theme
                          .textTheme
                          .titleSmall
                          ?.copyWith(
                        fontWeight:
                        FontWeight
                            .w800,
                      ),
                    ),

                    const SizedBox(
                      height: 10,
                    ),

                    if (wallets.isEmpty)
                      _buildNoWallet(
                        context,
                        theme,
                        isDark,
                      )
                    else
                      DropdownButtonFormField<
                          String>(
                        isExpanded:
                        true,

                        initialValue:
                        validWallet
                            ?.id,

                        decoration:
                        InputDecoration(
                          prefixIcon:
                          const Icon(
                            Icons
                                .account_balance_wallet_rounded,
                          ),
                          filled: true,
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
                              16,
                            ),
                            borderSide:
                            BorderSide
                                .none,
                          ),
                        ),

                        items:
                        wallets.map(
                              (wallet) {
                            return DropdownMenuItem<
                                String>(
                              value:
                              wallet.id,
                              child:
                              Text(
                                wallet.name,
                                maxLines:
                                1,
                                overflow:
                                TextOverflow
                                    .ellipsis,
                              ),
                            );
                          },
                        ).toList(),

                        onChanged: _saving
                            ? null
                            : (value) {
                          setState(
                                () {
                              _selectedWalletId =
                                  value;
                            },
                          );
                        },
                      ),

                    if (validWallet !=
                        null) ...[
                      const SizedBox(
                        height: 8,
                      ),

                      Text(
                        'Money added to this goal will be transferred from ${validWallet.name}.',
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
                    ],

                    const SizedBox(
                      height: 22,
                    ),

                    // =================================================
                    // AMOUNT
                    // =================================================

                    Text(
                      'Amount',
                      style: theme
                          .textTheme
                          .titleSmall
                          ?.copyWith(
                        fontWeight:
                        FontWeight
                            .w800,
                      ),
                    ),

                    const SizedBox(
                      height: 10,
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
                          enabled:
                          !_saving &&
                              wallets
                                  .isNotEmpty,
                          keyboardType:
                          const TextInputType
                              .numberWithOptions(
                            decimal: true,
                          ),
                          style:
                          const TextStyle(
                            fontSize: 28,
                            fontWeight:
                            FontWeight
                                .w800,
                          ),
                          decoration:
                          InputDecoration(
                            prefixText:
                            '${currencyState.currency.symbol} ',
                            hintText:
                            '0.00',
                            filled: true,
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
                                18,
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
                      height: 22,
                    ),

                    // =================================================
                    // NOTE
                    // =================================================

                    Text(
                      'Note',
                      style: theme
                          .textTheme
                          .titleSmall
                          ?.copyWith(
                        fontWeight:
                        FontWeight
                            .w800,
                      ),
                    ),

                    const SizedBox(
                      height: 10,
                    ),

                    TextField(
                      controller:
                      _noteController,
                      enabled:
                      !_saving &&
                          wallets
                              .isNotEmpty,
                      maxLines: 3,
                      decoration:
                      InputDecoration(
                        hintText:
                        'Optional note',
                        prefixIcon:
                        const Padding(
                          padding:
                          EdgeInsets
                              .only(
                            left: 16,
                            right: 10,
                            top: 14,
                          ),
                          child: Icon(
                            Icons
                                .notes_rounded,
                          ),
                        ),
                        prefixIconConstraints:
                        const BoxConstraints(
                          minWidth: 50,
                        ),
                        filled: true,
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
                            18,
                          ),
                          borderSide:
                          BorderSide
                              .none,
                        ),
                      ),
                    ),

                    const SizedBox(
                      height: 30,
                    ),

                    // =================================================
                    // SAVE BUTTON
                    // =================================================

                    SizedBox(
                      width:
                      double.infinity,
                      child:
                      ElevatedButton
                          .icon(
                        onPressed:
                        _saving ||
                            wallets
                                .isEmpty
                            ? null
                            : _submit,

                        icon: _saving
                            ? const SizedBox(
                          width: 20,
                          height: 20,
                          child:
                          CircularProgressIndicator(
                            strokeWidth:
                            2.2,
                            color: Colors
                                .white,
                          ),
                        )
                            : const Icon(
                          Icons
                              .savings_rounded,
                        ),

                        label: Text(
                          _saving
                              ? 'Adding...'
                              : 'Add Money to Goal',
                          style:
                          const TextStyle(
                            fontSize:
                            16,
                            fontWeight:
                            FontWeight
                                .w800,
                          ),
                        ),

                        style:
                        ElevatedButton
                            .styleFrom(
                          backgroundColor:
                          AppColors
                              .navPurple,
                          foregroundColor:
                          Colors.white,
                          disabledBackgroundColor:
                          AppColors
                              .navPurple
                              .withValues(
                            alpha:
                            0.55,
                          ),
                          elevation: 0,
                          padding:
                          const EdgeInsets
                              .symmetric(
                            vertical: 16,
                          ),
                          shape:
                          RoundedRectangleBorder(
                            borderRadius:
                            BorderRadius
                                .circular(
                              18,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ============================================================
  // NO WALLET
  // ============================================================

  Widget _buildNoWallet(
      BuildContext context,
      ThemeData theme,
      bool isDark,
      ) {
    return Container(
      width:
      double.infinity,
      padding:
      const EdgeInsets.all(18),
      decoration:
      BoxDecoration(
        color: isDark
            ? AppColors
            .darkSurface
            : AppColors
            .lightSurface,
        borderRadius:
        BorderRadius.circular(
          18,
        ),
        border:
        Border.all(
          color: AppColors.expense
              .withValues(
            alpha: 0.18,
          ),
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons
                .account_balance_wallet_outlined,
            color:
            AppColors.primary,
            size: 34,
          ),

          const SizedBox(
            height: 10,
          ),

          const Text(
            'No wallets available',
            style: TextStyle(
              fontWeight:
              FontWeight
                  .w800,
            ),
          ),

          const SizedBox(
            height: 5,
          ),

          Text(
            'Create a wallet before adding money to a goal.',
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
                alpha:
                0.55,
              ),
            ),
          ),

          const SizedBox(
            height: 14,
          ),

          OutlinedButton.icon(
            onPressed: _saving
                ? null
                : _openCreateWallet,
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
}

// ================================================================
// GOAL PREVIEW
// ================================================================

class _GoalPreview
    extends StatelessWidget {
  final SavingsGoalEntity goal;

  const _GoalPreview({
    required this.goal,
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

    final color =
    Color(goal.colorValue);

    return Container(
      width:
      double.infinity,
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
        border:
        Border.all(
          color:
          color.withValues(
            alpha: 0.20,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration:
            BoxDecoration(
              color:
              color.withValues(
                alpha: 0.12,
              ),
              borderRadius:
              BorderRadius.circular(
                16,
              ),
            ),
            child: Icon(
              IconData(
                goal.iconCodePoint,
                fontFamily:
                'MaterialIcons',
              ),
              color: color,
            ),
          ),

          const SizedBox(
            width: 14,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment
                  .start,
              children: [
                Text(
                  goal.name,
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
                    const Text(
                      'Saved ',
                    ),

                    CurrencyText(
                      goal.currentAmount,
                      style:
                      const TextStyle(
                        fontWeight:
                        FontWeight
                            .w700,
                      ),
                    ),

                    const Text(
                      ' / ',
                    ),

                    CurrencyText(
                      goal.targetAmount,
                      style:
                      const TextStyle(
                        fontWeight:
                        FontWeight
                            .w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Text(
            '${(goal.progress * 100).round()}%',
            style: TextStyle(
              color: color,
              fontWeight:
              FontWeight
                  .w900,
            ),
          ),
        ],
      ),
    );
  }
}