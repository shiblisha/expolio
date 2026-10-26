import 'package:equatable/equatable.dart';

import '../../domain/entities/transaction_entity.dart';

enum TransactionStatus {
  initial,
  loading,
  success,
  failure,
}

class TransactionState extends Equatable {
  final TransactionStatus status;
  final List<TransactionEntity> transactions;
  final String? errorMessage;

  final bool isSaving;
  final bool isDeleting;

  // Used by AddTransactionPage to know
  // when Firebase successfully saved the transaction.
  final bool saveSuccess;

  const TransactionState({
    this.status = TransactionStatus.initial,
    this.transactions = const [],
    this.errorMessage,
    this.isSaving = false,
    this.isDeleting = false,
    this.saveSuccess = false,
  });

  TransactionState copyWith({
    TransactionStatus? status,
    List<TransactionEntity>? transactions,
    String? errorMessage,
    bool clearError = false,
    bool? isSaving,
    bool? isDeleting,
    bool? saveSuccess,
  }) {
    return TransactionState(
      status: status ?? this.status,
      transactions: transactions ?? this.transactions,
      errorMessage:
      clearError ? null : errorMessage ?? this.errorMessage,
      isSaving: isSaving ?? this.isSaving,
      isDeleting: isDeleting ?? this.isDeleting,
      saveSuccess: saveSuccess ?? this.saveSuccess,
    );
  }

  @override
  List<Object?> get props => [
    status,
    transactions,
    errorMessage,
    isSaving,
    isDeleting,
    saveSuccess,
  ];
}