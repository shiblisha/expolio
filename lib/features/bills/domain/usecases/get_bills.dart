import '../entities/bill_entity.dart';
import '../repositories/bill_repository.dart';

class GetBills {
  final BillRepository repository;

  GetBills(this.repository);

  Future<List<BillEntity>> call() {
    return repository.getBills();
  }
}