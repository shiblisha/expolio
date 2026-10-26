import '../entities/budget_entity.dart';
import '../repositories/budget_repository.dart';

class AddBudget {
  final BudgetRepository repository;

  const AddBudget(this.repository);

  Future<void> call(BudgetEntity budget) {
    return repository.addBudget(budget);
  }
}