import 'package:equatable/equatable.dart';

import '../../domain/entities/savings_goal_entity.dart';

enum SavingsGoalStatusState { initial, loading, loaded, actionInProgress, error }

class SavingsGoalState extends Equatable {
  final SavingsGoalStatusState status;
  final List<SavingsGoalEntity> goals;
  final String? errorMessage;

  const SavingsGoalState({
    this.status = SavingsGoalStatusState.initial,
    this.goals = const [],
    this.errorMessage,
  });

  SavingsGoalState copyWith({
    SavingsGoalStatusState? status,
    List<SavingsGoalEntity>? goals,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SavingsGoalState(
      status: status ?? this.status,
      goals: goals ?? this.goals,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, goals, errorMessage];
}
