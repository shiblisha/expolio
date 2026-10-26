import '../entities/category_entity.dart';

abstract class CategoryRepository {
  Future<List<CategoryEntity>> getCategories();

  Stream<List<CategoryEntity>> watchCategories();

  Future<void> addCategory(
      CategoryEntity category,
      );

  Future<void> updateCategory(
      CategoryEntity category,
      );

  Future<void> deleteCategory(
      String categoryId,
      );
}