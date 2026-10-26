import '../entities/bill_entity.dart';
import '../repositories/bill_repository.dart';

class MarkBillPaid {
  final BillRepository repository;

  MarkBillPaid(this.repository);

  Future<void> call(BillEntity bill) {
    return repository.markBillPaid(
      bill: bill,
    );
  }
}