import '../entities/transaction_entity.dart';
import '../repositories/transaction_repository.dart';

class UpdateTransaction {
  final TransactionRepository repository;

  const UpdateTransaction(this.repository);

  Future<void> call(TransactionEntity transaction) async {
    await repository.updateTransaction(transaction);
  }
}