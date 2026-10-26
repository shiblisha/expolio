import 'package:equatable/equatable.dart';

import '../../domain/entities/transaction_entity.dart';

abstract class TransactionEvent extends Equatable {
  const TransactionEvent();

  @override
  List<Object?> get props => [];
}

// ================================================================
// LOAD TRANSACTIONS
// ================================================================

class LoadTransactions extends TransactionEvent {
  const LoadTransactions();
}

// ================================================================
// ADD TRANSACTION
// ================================================================

class AddTransactionEvent extends TransactionEvent {
  final TransactionEntity transaction;

  const AddTransactionEvent(this.transaction);

  @override
  List<Object?> get props => [transaction];
}

// ================================================================
// UPDATE TRANSACTION
// ================================================================

class UpdateTransactionEvent extends TransactionEvent {
  final TransactionEntity transaction;

  const UpdateTransactionEvent(this.transaction);

  @override
  List<Object?> get props => [transaction];
}

// ================================================================
// DELETE TRANSACTION
// ================================================================

class DeleteTransactionEvent extends TransactionEvent {
  final String transactionId;

  const DeleteTransactionEvent(this.transactionId);

  @override
  List<Object?> get props => [transactionId];
}

// ================================================================
// FIREBASE STREAM UPDATED
// ================================================================

class TransactionsUpdated extends TransactionEvent {
  final List<TransactionEntity> transactions;

  const TransactionsUpdated(this.transactions);

  @override
  List<Object?> get props => [transactions];
}

// ================================================================
// FIREBASE ERROR
// ================================================================

class TransactionsError extends TransactionEvent {
  final String message;

  const TransactionsError(this.message);

  @override
  List<Object?> get props => [message];
}