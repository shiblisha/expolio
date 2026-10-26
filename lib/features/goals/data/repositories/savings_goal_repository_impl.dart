import '../../domain/entities/savings_goal_entity.dart';
import '../../domain/repositories/savings_goal_repository.dart';
import '../datasources/savings_goal_remote_data_source.dart';
import '../models/savings_goal_model.dart';

class SavingsGoalRepositoryImpl implements SavingsGoalRepository {
  final SavingsGoalRemoteDataSource remoteDataSource;

  const SavingsGoalRepositoryImpl({
    required this.remoteDataSource,
  });

  @override
  Future<List<SavingsGoalEntity>> getGoals() {
    return remoteDataSource.getGoals();
  }

  @override
  Future<void> addGoal(SavingsGoalEntity goal) {
    return remoteDataSource.addGoal(
      SavingsGoalModel(
        id: goal.id,
        userId: goal.userId,
        name: goal.name,
        targetAmount: goal.targetAmount,
        currentAmount: goal.currentAmount,
        targetDate: goal.targetDate,
        description: goal.description,
        iconCodePoint: goal.iconCodePoint,
        colorValue: goal.colorValue,
        createdAt: goal.createdAt,
        updatedAt: goal.updatedAt,
        contributions: goal.contributions,
      ),
    );
  }

  @override
  Future<void> updateGoal(SavingsGoalEntity goal) {
    return remoteDataSource.updateGoal(
      SavingsGoalModel(
        id: goal.id,
        userId: goal.userId,
        name: goal.name,
        targetAmount: goal.targetAmount,
        currentAmount: goal.currentAmount,
        targetDate: goal.targetDate,
        description: goal.description,
        iconCodePoint: goal.iconCodePoint,
        colorValue: goal.colorValue,
        createdAt: goal.createdAt,
        updatedAt: goal.updatedAt,
        contributions: goal.contributions,
      ),
    );
  }

  @override
  Future<void> deleteGoal(String goalId) {
    return remoteDataSource.deleteGoal(goalId);
  }

  @override
  Future<void> addContribution({
    required String goalId,
    required double amount,
    required String walletId,
    String note = '',
  }) {
    return remoteDataSource.addContribution(
      goalId: goalId,
      amount: amount,
      walletId: walletId,
      note: note,
    );
  }

  @override
  Future<void> removeContribution({
    required String goalId,
    required String contributionId,
  }) {
    return remoteDataSource.removeContribution(
      goalId: goalId,
      contributionId: contributionId,
    );
  }
}