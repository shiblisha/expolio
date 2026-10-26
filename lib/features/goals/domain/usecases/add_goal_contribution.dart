import '../repositories/savings_goal_repository.dart';

class AddGoalContribution {
  final SavingsGoalRepository repository;

  const AddGoalContribution(this.repository);

  Future<void> call({
    required String goalId,
    required double amount,
    required String walletId,
    String note = '',
  }) {
    return repository.addContribution(
      goalId: goalId,
      amount: amount,
      walletId: walletId,
      note: note,
    );
  }
}