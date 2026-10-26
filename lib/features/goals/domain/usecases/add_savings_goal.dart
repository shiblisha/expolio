import '../entities/savings_goal_entity.dart';
import '../repositories/savings_goal_repository.dart';

class AddSavingsGoal {
  final SavingsGoalRepository repository;
  const AddSavingsGoal(this.repository);
  Future<void> call(SavingsGoalEntity goal) => repository.addGoal(goal);
}
