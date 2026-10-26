import '../entities/savings_goal_entity.dart';
import '../repositories/savings_goal_repository.dart';

class UpdateSavingsGoal {
  final SavingsGoalRepository repository;
  const UpdateSavingsGoal(this.repository);
  Future<void> call(SavingsGoalEntity goal) => repository.updateGoal(goal);
}
