import '../entities/bill_entity.dart';

abstract class BillRepository {
  Future<List<BillEntity>> getBills();

  Future<void> addBill(BillEntity bill);

  Future<void> updateBill(BillEntity bill);

  Future<void> deleteBill(String billId);

  Future<void> markBillPaid({
    required BillEntity bill,
  });
}