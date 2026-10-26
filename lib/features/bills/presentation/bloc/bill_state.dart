import 'package:equatable/equatable.dart';

import '../../domain/entities/bill_entity.dart';

enum BillStatus {
  initial,
  loading,
  success,
  failure,
}

class BillState extends Equatable {
  final BillStatus status;
  final List<BillEntity> bills;
  final String? errorMessage;

  final bool isSaving;
  final bool isDeleting;
  final bool isMarkingPaid;

  const BillState({
    this.status = BillStatus.initial,
    this.bills = const [],
    this.errorMessage,
    this.isSaving = false,
    this.isDeleting = false,
    this.isMarkingPaid = false,
  });

  BillState copyWith({
    BillStatus? status,
    List<BillEntity>? bills,
    String? errorMessage,
    bool clearError = false,
    bool? isSaving,
    bool? isDeleting,
    bool? isMarkingPaid,
  }) {
    return BillState(
      status: status ?? this.status,
      bills: bills ?? this.bills,
      errorMessage:
      clearError ? null : errorMessage ?? this.errorMessage,
      isSaving: isSaving ?? this.isSaving,
      isDeleting: isDeleting ?? this.isDeleting,
      isMarkingPaid:
      isMarkingPaid ?? this.isMarkingPaid,
    );
  }

  @override
  List<Object?> get props => [
    status,
    bills,
    errorMessage,
    isSaving,
    isDeleting,
    isMarkingPaid,
  ];
}