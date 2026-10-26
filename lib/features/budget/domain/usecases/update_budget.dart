import '../entities/budget_entity.dart';
import '../repositories/budget_repository.dart';

class UpdateBudget {
  final BudgetRepository repository;

  const UpdateBudget(this.repository);

  Future<void> call(BudgetEntity budget) {
    return repository.updateBudget(budget);
  }
}