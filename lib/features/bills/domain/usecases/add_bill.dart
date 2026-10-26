import '../entities/bill_entity.dart';
import '../repositories/bill_repository.dart';

class AddBill {
  final BillRepository repository;

  AddBill(this.repository);

  Future<void> call(BillEntity bill) {
    return repository.addBill(bill);
  }
}