import '../entities/category_entity.dart';
import '../repositories/category_repository.dart';

class AddCategory {
  final CategoryRepository repository;

  const AddCategory(this.repository);

  Future<void> call(
      CategoryEntity category,
      ) {
    return repository.addCategory(
      category,
    );
  }
}