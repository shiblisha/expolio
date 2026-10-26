import '../entities/budget_entity.dart';
import '../repositories/budget_repository.dart';

class GetBudgets {
  final BudgetRepository repository;

  const GetBudgets(this.repository);

  Future<List<BudgetEntity>> call() {
    return repository.getBudgets();
  }
}