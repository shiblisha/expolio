import '../../domain/entities/bill_entity.dart';
import '../../domain/repositories/bill_repository.dart';
import '../datasources/bill_remote_data_source.dart';
import '../models/bill_model.dart';

class BillRepositoryImpl implements BillRepository {
  final BillRemoteDataSource remoteDataSource;

  BillRepositoryImpl({
    required this.remoteDataSource,
  });

  @override
  Future<List<BillEntity>> getBills() {
    return remoteDataSource.getBills();
  }

  @override
  Future<void> addBill(BillEntity bill) {
    return remoteDataSource.addBill(
      BillModel(
        id: bill.id,
        userId: bill.userId,
        name: bill.name,
        amount: bill.amount,
        dueDate: bill.dueDate,
        categoryId: bill.categoryId,
        categoryName: bill.categoryName,
        walletId: bill.walletId,
        walletName: bill.walletName,
        isRecurring: bill.isRecurring,
        recurrence: bill.recurrence,
        isPaid: bill.isPaid,
        paidAt: bill.paidAt,
        createdAt: bill.createdAt,
      ),
    );
  }

  @override
  Future<void> updateBill(BillEntity bill) {
    return remoteDataSource.updateBill(
      BillModel(
        id: bill.id,
        userId: bill.userId,
        name: bill.name,
        amount: bill.amount,
        dueDate: bill.dueDate,
        categoryId: bill.categoryId,
        categoryName: bill.categoryName,
        walletId: bill.walletId,
        walletName: bill.walletName,
        isRecurring: bill.isRecurring,
        recurrence: bill.recurrence,
        isPaid: bill.isPaid,
        paidAt: bill.paidAt,
        createdAt: bill.createdAt,
      ),
    );
  }

  @override
  Future<void> deleteBill(String billId) {
    return remoteDataSource.deleteBill(billId);
  }

  @override
  Future<void> markBillPaid({
    required BillEntity bill,
  }) {
    return remoteDataSource.markBillPaid(
      BillModel(
        id: bill.id,
        userId: bill.userId,
        name: bill.name,
        amount: bill.amount,
        dueDate: bill.dueDate,
        categoryId: bill.categoryId,
        categoryName: bill.categoryName,
        walletId: bill.walletId,
        walletName: bill.walletName,
        isRecurring: bill.isRecurring,
        recurrence: bill.recurrence,
        isPaid: true,
        paidAt: DateTime.now(),
        createdAt: bill.createdAt,
      ),
    );
  }
}