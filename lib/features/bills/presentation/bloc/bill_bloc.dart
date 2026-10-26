import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/bill_entity.dart';
import '../../domain/usecases/add_bill.dart';
import '../../domain/usecases/delete_bill.dart';
import '../../domain/usecases/get_bills.dart';
import '../../domain/usecases/mark_bill_paid.dart';
import '../../domain/usecases/update_bill.dart';

import 'bill_event.dart';
import 'bill_state.dart';

class BillBloc extends Bloc<BillEvent, BillState> {
  final GetBills getBills;
  final AddBill addBill;
  final UpdateBill updateBill;
  final DeleteBill deleteBill;
  final MarkBillPaid markBillPaid;

  BillBloc({
    required this.getBills,
    required this.addBill,
    required this.updateBill,
    required this.deleteBill,
    required this.markBillPaid,
  }) : super(const BillState()) {
    on<LoadBills>(_onLoadBills);
    on<AddBillEvent>(_onAddBill);
    on<UpdateBillEvent>(_onUpdateBill);
    on<DeleteBillEvent>(_onDeleteBill);
    on<MarkBillPaidEvent>(_onMarkBillPaid);
  }

  // ============================================================
  // LOAD
  // ============================================================

  Future<void> _onLoadBills(
      LoadBills event,
      Emitter<BillState> emit,
      ) async {
    emit(
      state.copyWith(
        status: BillStatus.loading,
        clearError: true,
      ),
    );

    try {
      final bills = await getBills();

      emit(
        state.copyWith(
          status: BillStatus.success,
          bills: bills,
          clearError: true,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: BillStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  // ============================================================
  // ADD
  // ============================================================

  Future<void> _onAddBill(
      AddBillEvent event,
      Emitter<BillState> emit,
      ) async {
    emit(
      state.copyWith(
        isSaving: true,
        clearError: true,
      ),
    );

    try {
      await addBill(event.bill);

      final bills = await getBills();

      emit(
        state.copyWith(
          status: BillStatus.success,
          bills: bills,
          isSaving: false,
          clearError: true,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: BillStatus.failure,
          isSaving: false,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  // ============================================================
  // UPDATE
  // ============================================================

  Future<void> _onUpdateBill(
      UpdateBillEvent event,
      Emitter<BillState> emit,
      ) async {
    emit(
      state.copyWith(
        isSaving: true,
        clearError: true,
      ),
    );

    try {
      await updateBill(event.bill);

      final bills = await getBills();

      emit(
        state.copyWith(
          status: BillStatus.success,
          bills: bills,
          isSaving: false,
          clearError: true,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: BillStatus.failure,
          isSaving: false,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  // ============================================================
  // DELETE
  // ============================================================

  Future<void> _onDeleteBill(
      DeleteBillEvent event,
      Emitter<BillState> emit,
      ) async {
    final previousBills = List<BillEntity>.from(
      state.bills,
    );

    final updatedBills = previousBills
        .where(
          (bill) => bill.id != event.billId,
    )
        .toList();

    emit(
      state.copyWith(
        bills: updatedBills,
        isDeleting: true,
        clearError: true,
      ),
    );

    try {
      await deleteBill(event.billId);

      emit(
        state.copyWith(
          isDeleting: false,
          status: BillStatus.success,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          bills: previousBills,
          isDeleting: false,
          status: BillStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  // ============================================================
  // MARK AS PAID
  // ============================================================

  Future<void> _onMarkBillPaid(
      MarkBillPaidEvent event,
      Emitter<BillState> emit,
      ) async {
    // Prevent multiple simultaneous requests.
    if (state.isMarkingPaid) {
      return;
    }

    // Check current state.
    final existingIndex = state.bills.indexWhere(
          (item) => item.id == event.bill.id,
    );

    if (existingIndex != -1 &&
        state.bills[existingIndex].isPaid) {
      return;
    }

    // Event itself says it is already paid.
    if (event.bill.isPaid) {
      return;
    }

    // A bill without a wallet cannot be paid.
    if (event.bill.walletId == null ||
        event.bill.walletId!.isEmpty) {
      emit(
        state.copyWith(
          status: BillStatus.failure,
          errorMessage: 'Payment wallet is required before marking the bill as paid.',
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        isMarkingPaid: true,
        clearError: true,
      ),
    );

    try {
      // ========================================================
      // ATOMIC OPERATION
      //
      // The MarkBillPaid use case handles:
      // 1. Expense transaction creation
      // 2. Current bill payment
      // 3. Next recurring bill creation, when enabled
      // ========================================================

      await markBillPaid(event.bill);

      // Reload so the newly created recurring bill appears
      // immediately in the Bills page.
      final bills = await getBills();

      emit(
        state.copyWith(
          bills: bills,
          isMarkingPaid: false,
          status: BillStatus.success,
          clearError: true,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          isMarkingPaid: false,
          status: BillStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }
}
