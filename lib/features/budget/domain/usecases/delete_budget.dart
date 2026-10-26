import '../repositories/budget_repository.dart';

class DeleteBudget {
  final BudgetRepository repository;

  const DeleteBudget(this.repository);

  Future<void> call(String budgetId) {
    return repository.deleteBudget(budgetId);
  }
}