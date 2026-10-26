import '../../domain/entities/transaction_entity.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../datasources/transaction_remote_datasource.dart';

class TransactionRepositoryImpl
    implements TransactionRepository {
  final TransactionRemoteDataSource remoteDataSource;

  TransactionRepositoryImpl({
    required this.remoteDataSource,
  });

  // ============================================================
  // WATCH TRANSACTIONS
  // ============================================================

  @override
  Stream<List<TransactionEntity>> watchTransactions() {
    return remoteDataSource.watchTransactions();
  }

  // ============================================================
  // ADD TRANSACTION
  // ============================================================

  @override
  Future<void> addTransaction(
      TransactionEntity transaction,
      ) {
    return remoteDataSource.addTransaction(
      transaction,
    );
  }

  // ============================================================
  // UPDATE TRANSACTION
  // ============================================================

  @override
  Future<void> updateTransaction(
      TransactionEntity transaction,
      ) {
    return remoteDataSource.updateTransaction(
      transaction,
    );
  }

  // ============================================================
  // DELETE TRANSACTION
  // ============================================================

  @override
  Future<void> deleteTransaction(
      String transactionId,
      ) {
    return remoteDataSource.deleteTransaction(
      transactionId,
    );
  }
}