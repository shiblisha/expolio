import '../entities/bill_entity.dart';
import '../repositories/bill_repository.dart';

class UpdateBill {
  final BillRepository repository;

  UpdateBill(this.repository);

  Future<void> call(BillEntity bill) {
    return repository.updateBill(bill);
  }
}