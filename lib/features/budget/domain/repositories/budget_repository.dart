import '../entities/budget_entity.dart';

abstract class BudgetRepository {
  Future<List<BudgetEntity>> getBudgets();

  Stream<List<BudgetEntity>> watchBudgets();

  Future<void> addBudget(BudgetEntity budget);

  Future<void> updateBudget(BudgetEntity budget);

  Future<void> deleteBudget(String budgetId);
}