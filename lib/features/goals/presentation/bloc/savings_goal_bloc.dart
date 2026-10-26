import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/add_goal_contribution.dart';
import '../../domain/usecases/add_savings_goal.dart';
import '../../domain/usecases/delete_savings_goal.dart';
import '../../domain/usecases/get_savings_goals.dart';
import '../../domain/usecases/remove_goal_contribution.dart';
import '../../domain/usecases/update_savings_goal.dart';
import 'savings_goal_event.dart';
import 'savings_goal_state.dart';

class SavingsGoalBloc extends Bloc<SavingsGoalEvent, SavingsGoalState> {
  final GetSavingsGoals getSavingsGoals;
  final AddSavingsGoal addSavingsGoal;
  final UpdateSavingsGoal updateSavingsGoal;
  final DeleteSavingsGoal deleteSavingsGoal;
  final AddGoalContribution addGoalContribution;
  final RemoveGoalContribution removeGoalContribution;

  SavingsGoalBloc({
    required this.getSavingsGoals,
    required this.addSavingsGoal,
    required this.updateSavingsGoal,
    required this.deleteSavingsGoal,
    required this.addGoalContribution,
    required this.removeGoalContribution,
  }) : super(const SavingsGoalState()) {
    on<LoadSavingsGoals>(_onLoad);
    on<AddSavingsGoalEvent>(_onAdd);
    on<UpdateSavingsGoalEvent>(_onUpdate);
    on<DeleteSavingsGoalEvent>(_onDelete);
    on<AddGoalContributionEvent>(_onAddContribution);
    on<RemoveGoalContributionEvent>(_onRemoveContribution);
  }

  Future<void> _onLoad(
      LoadSavingsGoals event,
      Emitter<SavingsGoalState> emit,
      ) async {
    emit(
      state.copyWith(
        status: SavingsGoalStatusState.loading,
        clearError: true,
      ),
    );

    try {
      final goals = await getSavingsGoals();

      emit(
        state.copyWith(
          status: SavingsGoalStatusState.loaded,
          goals: goals,
          clearError: true,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: SavingsGoalStatusState.error,
          errorMessage: _message(e),
        ),
      );
    }
  }

  Future<void> _onAdd(
      AddSavingsGoalEvent event,
      Emitter<SavingsGoalState> emit,
      ) async {
    emit(
      state.copyWith(
        status: SavingsGoalStatusState.actionInProgress,
        clearError: true,
      ),
    );

    try {
      await addSavingsGoal(event.goal);

      final goals = await getSavingsGoals();

      emit(
        state.copyWith(
          status: SavingsGoalStatusState.loaded,
          goals: goals,
          clearError: true,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: SavingsGoalStatusState.loaded,
          errorMessage: _message(e),
        ),
      );
    }
  }

  Future<void> _onUpdate(
      UpdateSavingsGoalEvent event,
      Emitter<SavingsGoalState> emit,
      ) async {
    emit(
      state.copyWith(
        status: SavingsGoalStatusState.actionInProgress,
        clearError: true,
      ),
    );

    try {
      await updateSavingsGoal(event.goal);

      final goals = await getSavingsGoals();

      emit(
        state.copyWith(
          status: SavingsGoalStatusState.loaded,
          goals: goals,
          clearError: true,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: SavingsGoalStatusState.loaded,
          errorMessage: _message(e),
        ),
      );
    }
  }

  Future<void> _onDelete(
      DeleteSavingsGoalEvent event,
      Emitter<SavingsGoalState> emit,
      ) async {
    emit(
      state.copyWith(
        status: SavingsGoalStatusState.actionInProgress,
        clearError: true,
      ),
    );

    try {
      await deleteSavingsGoal(event.goalId);

      final goals = state.goals
          .where((goal) => goal.id != event.goalId)
          .toList();

      emit(
        state.copyWith(
          status: SavingsGoalStatusState.loaded,
          goals: goals,
          clearError: true,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: SavingsGoalStatusState.loaded,
          errorMessage: _message(e),
        ),
      );
    }
  }

  Future<void> _onAddContribution(
      AddGoalContributionEvent event,
      Emitter<SavingsGoalState> emit,
      ) async {
    emit(
      state.copyWith(
        status: SavingsGoalStatusState.actionInProgress,
        clearError: true,
      ),
    );

    try {
      await addGoalContribution(
        goalId: event.goalId,
        amount: event.amount,
        walletId: event.walletId,
        note: event.note,
      );

      final goals = await getSavingsGoals();

      emit(
        state.copyWith(
          status: SavingsGoalStatusState.loaded,
          goals: goals,
          clearError: true,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: SavingsGoalStatusState.loaded,
          errorMessage: _message(e),
        ),
      );
    }
  }

  Future<void> _onRemoveContribution(
      RemoveGoalContributionEvent event,
      Emitter<SavingsGoalState> emit,
      ) async {
    emit(
      state.copyWith(
        status: SavingsGoalStatusState.actionInProgress,
        clearError: true,
      ),
    );

    try {
      await removeGoalContribution(
        goalId: event.goalId,
        contributionId: event.contributionId,
      );

      final goals = await getSavingsGoals();

      emit(
        state.copyWith(
          status: SavingsGoalStatusState.loaded,
          goals: goals,
          clearError: true,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: SavingsGoalStatusState.loaded,
          errorMessage: _message(e),
        ),
      );
    }
  }

  String _message(Object error) {
    return error
        .toString()
        .replaceFirst('Exception: ', '')
        .replaceFirst('Bad state: ', '');
  }
}