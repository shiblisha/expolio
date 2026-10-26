import '../default_categories.dart';
import '../entities/category_entity.dart';
import '../repositories/category_repository.dart';

class SeedDefaultCategories {
  final CategoryRepository repository;

  const SeedDefaultCategories(this.repository);

  Future<void> call(String userId) async {
    final defaults = DefaultCategories.forUser(userId);

    for (final category in defaults) {
      await repository.addCategory(category);
    }
  }
}