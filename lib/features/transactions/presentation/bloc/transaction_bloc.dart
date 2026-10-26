import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/transaction_entity.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../../domain/usecases/add_transaction.dart';
import '../../domain/usecases/delete_transaction.dart';
import '../../domain/usecases/update_transaction.dart';
import '../../domain/usecases/watch_transactions.dart';
import 'transaction_event.dart';
import 'transaction_state.dart';

class TransactionBloc
    extends Bloc<TransactionEvent, TransactionState> {
  final WatchTransactions watchTransactions;
  final AddTransaction addTransaction;
  final UpdateTransaction updateTransaction;
  final DeleteTransaction deleteTransaction;

  StreamSubscription<List<TransactionEntity>>?
  _transactionsSubscription;

  TransactionBloc({
    required TransactionRepository repository,
  })  : watchTransactions = WatchTransactions(repository),
        addTransaction = AddTransaction(repository),
        updateTransaction = UpdateTransaction(repository),
        deleteTransaction = DeleteTransaction(repository),
        super(const TransactionState()) {
    on<LoadTransactions>(_onLoadTransactions);
    on<AddTransactionEvent>(_onAddTransaction);
    on<UpdateTransactionEvent>(_onUpdateTransaction);
    on<DeleteTransactionEvent>(_onDeleteTransaction);

    on<TransactionsUpdated>(_onTransactionsUpdated);
    on<TransactionsError>(_onTransactionsError);
  }

  // ============================================================
  // LOAD TRANSACTIONS
  // ============================================================

  Future<void> _onLoadTransactions(
      LoadTransactions event,
      Emitter<TransactionState> emit,
      ) async {
    emit(
      state.copyWith(
        status: TransactionStatus.loading,
        clearError: true,
      ),
    );

    await _transactionsSubscription?.cancel();

    _transactionsSubscription =
        watchTransactions().listen(
              (transactions) {
            add(
              TransactionsUpdated(
                transactions,
              ),
            );
          },
          onError: (error) {
            add(
              TransactionsError(
                error.toString(),
              ),
            );
          },
        );
  }

  // ============================================================
  // ADD TRANSACTION
  // ============================================================

  Future<void> _onAddTransaction(
      AddTransactionEvent event,
      Emitter<TransactionState> emit,
      ) async {
    emit(
      state.copyWith(
        isSaving: true,
        saveSuccess: false,
        clearError: true,
      ),
    );

    try {
      await addTransaction(
        event.transaction,
      );

      emit(
        state.copyWith(
          isSaving: false,
          saveSuccess: true,
          status: TransactionStatus.success,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          isSaving: false,
          saveSuccess: false,
          status: TransactionStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  // ============================================================
  // UPDATE TRANSACTION
  // ============================================================

  Future<void> _onUpdateTransaction(
      UpdateTransactionEvent event,
      Emitter<TransactionState> emit,
      ) async {
    emit(
      state.copyWith(
        isSaving: true,
        saveSuccess: false,
        clearError: true,
      ),
    );

    try {
      await updateTransaction(
        event.transaction,
      );

      emit(
        state.copyWith(
          isSaving: false,
          saveSuccess: true,
          status: TransactionStatus.success,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          isSaving: false,
          saveSuccess: false,
          status: TransactionStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  // ============================================================
  // DELETE TRANSACTION
  // ============================================================

  Future<void> _onDeleteTransaction(
      DeleteTransactionEvent event,
      Emitter<TransactionState> emit,
      ) async {
    // Keep the current list in case Firebase deletion fails.
    final previousTransactions = List.of(
      state.transactions,
    );

    // Remove the item immediately from the UI.
    final updatedTransactions = previousTransactions
        .where(
          (transaction) =>
      transaction.id != event.transactionId,
    )
        .toList();

    emit(
      state.copyWith(
        transactions: updatedTransactions,
        isDeleting: true,
        clearError: true,
      ),
    );

    try {
      await deleteTransaction(
        event.transactionId,
      );

      emit(
        state.copyWith(
          isDeleting: false,
        ),
      );
    } catch (e) {
      // Firebase delete failed.
      // Restore the transaction.
      emit(
        state.copyWith(
          transactions: previousTransactions,
          isDeleting: false,
          status: TransactionStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  // ============================================================
  // FIRESTORE STREAM UPDATED
  // ============================================================

  void _onTransactionsUpdated(
      TransactionsUpdated event,
      Emitter<TransactionState> emit,
      ) {
    emit(
      state.copyWith(
        status: TransactionStatus.success,
        transactions: event.transactions,
        saveSuccess: false,
        clearError: true,
      ),
    );
  }

  // ============================================================
  // FIRESTORE ERROR
  // ============================================================

  void _onTransactionsError(
      TransactionsError event,
      Emitter<TransactionState> emit,
      ) {
    emit(
      state.copyWith(
        status: TransactionStatus.failure,
        errorMessage: event.message,
      ),
    );
  }

  // ============================================================
  // CLOSE
  // ============================================================

  @override
  Future<void> close() async {
    await _transactionsSubscription?.cancel();

    return super.close();
  }
}