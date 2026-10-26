import '../entities/savings_goal_entity.dart';

abstract class SavingsGoalRepository {
  Future<List<SavingsGoalEntity>> getGoals();

  Future<void> addGoal(SavingsGoalEntity goal);

  Future<void> updateGoal(SavingsGoalEntity goal);

  Future<void> deleteGoal(String goalId);

  Future<void> addContribution({
    required String goalId,
    required double amount,
    required String walletId,
    String note = '',
  });

  Future<void> removeContribution({
    required String goalId,
    required String contributionId,
  });
}