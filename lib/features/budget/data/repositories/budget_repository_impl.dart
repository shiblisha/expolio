import '../../domain/entities/budget_entity.dart';
import '../../domain/repositories/budget_repository.dart';
import '../datasources/budget_remote_datasource.dart';
import '../models/budget_model.dart';

class BudgetRepositoryImpl implements BudgetRepository {
  final BudgetRemoteDataSource remoteDataSource;

  BudgetRepositoryImpl({
    required this.remoteDataSource,
  });

  @override
  Future<List<BudgetEntity>> getBudgets() async {
    return remoteDataSource.getBudgets();
  }

  @override
  Stream<List<BudgetEntity>> watchBudgets() {
    return remoteDataSource.watchBudgets();
  }

  @override
  Future<void> addBudget(BudgetEntity budget) async {
    await remoteDataSource.addBudget(
      BudgetModel.fromEntity(budget),
    );
  }

  @override
  Future<void> updateBudget(BudgetEntity budget) async {
    await remoteDataSource.updateBudget(
      BudgetModel.fromEntity(budget),
    );
  }

  @override
  Future<void> deleteBudget(String budgetId) async {
    await remoteDataSource.deleteBudget(budgetId);
  }
}