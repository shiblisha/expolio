import '../repositories/bill_repository.dart';

class DeleteBill {
  final BillRepository repository;

  DeleteBill(this.repository);

  Future<void> call(String billId) {
    return repository.deleteBill(billId);
  }
}