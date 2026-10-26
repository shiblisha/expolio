import 'package:equatable/equatable.dart';

import '../../domain/entities/bill_entity.dart';

abstract class BillEvent extends Equatable {
  const BillEvent();

  @override
  List<Object?> get props => [];
}

// ============================================================
// LOAD
// ============================================================

class LoadBills extends BillEvent {
  const LoadBills();
}

// ============================================================
// ADD
// ============================================================

class AddBillEvent extends BillEvent {
  final BillEntity bill;

  const AddBillEvent(this.bill);

  @override
  List<Object?> get props => [bill];
}

// ============================================================
// UPDATE
// ============================================================

class UpdateBillEvent extends BillEvent {
  final BillEntity bill;

  const UpdateBillEvent(this.bill);

  @override
  List<Object?> get props => [bill];
}

// ============================================================
// DELETE
// ============================================================

class DeleteBillEvent extends BillEvent {
  final String billId;

  const DeleteBillEvent(this.billId);

  @override
  List<Object?> get props => [billId];
}

// ============================================================
// MARK PAID
// ============================================================

class MarkBillPaidEvent extends BillEvent {
  final BillEntity bill;

  const MarkBillPaidEvent(this.bill);

  @override
  List<Object?> get props => [bill];
}