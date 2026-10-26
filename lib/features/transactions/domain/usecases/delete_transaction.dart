import '../repositories/transaction_repository.dart';

class DeleteTransaction {
  final TransactionRepository repository;

  DeleteTransaction(this.repository);

  Future<void> call(String transactionId) {
    return repository.deleteTransaction(transactionId);
  }
}