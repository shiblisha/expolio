import '../entities/category_entity.dart';
import '../repositories/category_repository.dart';

class UpdateCategory {
  final CategoryRepository repository;

  const UpdateCategory(this.repository);

  Future<void> call(
      CategoryEntity category,
      ) {
    return repository.updateCategory(
      category,
    );
  }
}