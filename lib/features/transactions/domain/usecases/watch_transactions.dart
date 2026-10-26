import '../entities/transaction_entity.dart';
import '../repositories/transaction_repository.dart';

class WatchTransactions {
  final TransactionRepository repository;

  WatchTransactions(this.repository);

  Stream<List<TransactionEntity>> call() {
    return repository.watchTransactions();
  }
}