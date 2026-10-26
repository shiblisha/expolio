import 'package:equatable/equatable.dart';

import '../../domain/entities/savings_goal_entity.dart';

abstract class SavingsGoalEvent extends Equatable {
  const SavingsGoalEvent();

  @override
  List<Object?> get props => [];
}

class LoadSavingsGoals extends SavingsGoalEvent {
  const LoadSavingsGoals();
}

class AddSavingsGoalEvent extends SavingsGoalEvent {
  final SavingsGoalEntity goal;

  const AddSavingsGoalEvent(this.goal);

  @override
  List<Object?> get props => [goal];
}

class UpdateSavingsGoalEvent extends SavingsGoalEvent {
  final SavingsGoalEntity goal;

  const UpdateSavingsGoalEvent(this.goal);

  @override
  List<Object?> get props => [goal];
}

class DeleteSavingsGoalEvent extends SavingsGoalEvent {
  final String goalId;

  const DeleteSavingsGoalEvent(this.goalId);

  @override
  List<Object?> get props => [goalId];
}

/// Add money to a savings goal from a selected wallet.
class AddGoalContributionEvent extends SavingsGoalEvent {
  final String goalId;
  final double amount;
  final String walletId;
  final String note;

  const AddGoalContributionEvent({
    required this.goalId,
    required this.amount,
    required this.walletId,
    this.note = '',
  });

  @override
  List<Object?> get props => [
    goalId,
    amount,
    walletId,
    note,
  ];
}

class RemoveGoalContributionEvent extends SavingsGoalEvent {
  final String goalId;
  final String contributionId;

  const RemoveGoalContributionEvent({
    required this.goalId,
    required this.contributionId,
  });

  @override
  List<Object?> get props => [
    goalId,
    contributionId,
  ];
}