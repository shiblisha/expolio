import '../entities/transaction_entity.dart';

abstract class TransactionRepository {
  // Watch all transactions
  Stream<List<TransactionEntity>> watchTransactions();

  // Add a new transaction
  Future<void> addTransaction(TransactionEntity transaction);

  // Update an existing transaction
  Future<void> updateTransaction(TransactionEntity transaction);

  // Delete a transaction
  Future<void> deleteTransaction(String transactionId);
}
