import '../entities/savings_goal_entity.dart';
import '../repositories/savings_goal_repository.dart';

class DeleteSavingsGoal {
  final SavingsGoalRepository repository;
  const DeleteSavingsGoal(this.repository);
  Future<void> call(String goalId) => repository.deleteGoal(goalId);
}
