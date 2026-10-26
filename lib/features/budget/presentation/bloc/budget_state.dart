import 'package:equatable/equatable.dart';

import '../../domain/entities/budget_entity.dart';

enum BudgetStatus {
  initial,
  loading,
  success,
  failure,
}

class BudgetState extends Equatable {
  final BudgetStatus status;
  final List<BudgetEntity> budgets;
  final bool isSaving;
  final bool isDeleting;
  final String? errorMessage;

  const BudgetState({
    this.status = BudgetStatus.initial,
    this.budgets = const [],
    this.isSaving = false,
    this.isDeleting = false,
    this.errorMessage,
  });

  BudgetState copyWith({
    BudgetStatus? status,
    List<BudgetEntity>? budgets,
    bool? isSaving,
    bool? isDeleting,
    String? errorMessage,
    bool clearError = false,
  }) {
    return BudgetState(
      status: status ?? this.status,
      budgets: budgets ?? this.budgets,
      isSaving: isSaving ?? this.isSaving,
      isDeleting: isDeleting ?? this.isDeleting,
      errorMessage: clearError
          ? null
          : errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    status,
    budgets,
    isSaving,
    isDeleting,
    errorMessage,
  ];
}