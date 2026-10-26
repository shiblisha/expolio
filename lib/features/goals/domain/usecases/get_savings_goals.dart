import '../entities/savings_goal_entity.dart';
import '../repositories/savings_goal_repository.dart';

class GetSavingsGoals {
  final SavingsGoalRepository repository;
  const GetSavingsGoals(this.repository);
  Future<List<SavingsGoalEntity>> call() => repository.getGoals();
}
