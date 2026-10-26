import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/budget_entity.dart';
import '../../domain/usecases/add_budget.dart';
import '../../domain/usecases/delete_budget.dart';
import '../../domain/usecases/get_budgets.dart';
import '../../domain/usecases/update_budget.dart';

import 'budget_event.dart';
import 'budget_state.dart';

class BudgetBloc extends Bloc<BudgetEvent, BudgetState> {
  final GetBudgets getBudgets;
  final AddBudget addBudget;
  final UpdateBudget updateBudget;
  final DeleteBudget deleteBudget;

  BudgetBloc({
    required this.getBudgets,
    required this.addBudget,
    required this.updateBudget,
    required this.deleteBudget,
  }) : super(const BudgetState()) {
    on<LoadBudgets>(_onLoadBudgets);
    on<AddBudgetEvent>(_onAddBudget);
    on<UpdateBudgetEvent>(_onUpdateBudget);
    on<DeleteBudgetEvent>(_onDeleteBudget);
  }

  // ============================================================
  // LOAD
  // ============================================================

  Future<void> _onLoadBudgets(
      LoadBudgets event,
      Emitter<BudgetState> emit,
      ) async {
    emit(
      state.copyWith(
        status: BudgetStatus.loading,
        clearError: true,
      ),
    );

    try {
      final budgets = await getBudgets();

      emit(
        state.copyWith(
          status: BudgetStatus.success,
          budgets: budgets,
          clearError: true,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: BudgetStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  // ============================================================
  // ADD
  // ============================================================

  Future<void> _onAddBudget(
      AddBudgetEvent event,
      Emitter<BudgetState> emit,
      ) async {
    emit(
      state.copyWith(
        isSaving: true,
        clearError: true,
      ),
    );

    try {
      await addBudget(event.budget);

      final budgets = await getBudgets();

      emit(
        state.copyWith(
          status: BudgetStatus.success,
          budgets: budgets,
          isSaving: false,
          clearError: true,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: BudgetStatus.failure,
          isSaving: false,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  // ============================================================
  // UPDATE
  // ============================================================

  Future<void> _onUpdateBudget(
      UpdateBudgetEvent event,
      Emitter<BudgetState> emit,
      ) async {
    emit(
      state.copyWith(
        isSaving: true,
        clearError: true,
      ),
    );

    try {
      await updateBudget(event.budget);

      final budgets = await getBudgets();

      emit(
        state.copyWith(
          status: BudgetStatus.success,
          budgets: budgets,
          isSaving: false,
          clearError: true,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: BudgetStatus.failure,
          isSaving: false,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  // ============================================================
  // DELETE
  // ============================================================

  Future<void> _onDeleteBudget(
      DeleteBudgetEvent event,
      Emitter<BudgetState> emit,
      ) async {
    final previousBudgets = List<BudgetEntity>.of(
      state.budgets,
    );

    final updatedBudgets = previousBudgets
        .where(
          (budget) => budget.id != event.budgetId,
    )
        .toList();

    emit(
      state.copyWith(
        budgets: updatedBudgets,
        isDeleting: true,
        clearError: true,
      ),
    );

    try {
      await deleteBudget(event.budgetId);

      emit(
        state.copyWith(
          isDeleting: false,
          status: BudgetStatus.success,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          budgets: previousBudgets,
          isDeleting: false,
          status: BudgetStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }
}