import '../repositories/savings_goal_repository.dart';

class RemoveGoalContribution {
  final SavingsGoalRepository repository;
  const RemoveGoalContribution(this.repository);

  Future<void> call({
    required String goalId,
    required String contributionId,
  }) {
    return repository.removeContribution(
      goalId: goalId,
      contributionId: contributionId,
    );
  }
}
