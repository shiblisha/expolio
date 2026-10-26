import '../../domain/entities/category_entity.dart';
import '../../domain/repositories/category_repository.dart';
import '../datasources/category_remote_data_source.dart';
import '../models/category_model.dart';

class CategoryRepositoryImpl
    implements CategoryRepository {
  final CategoryRemoteDataSource remoteDataSource;

  CategoryRepositoryImpl({
    required this.remoteDataSource,
  });

  @override
  Future<List<CategoryEntity>> getCategories() {
    return remoteDataSource.getCategories();
  }

  @override
  Stream<List<CategoryEntity>> watchCategories() {
    return remoteDataSource.watchCategories();
  }

  @override
  Future<void> addCategory(
      CategoryEntity category,
      ) {
    return remoteDataSource.addCategory(
      CategoryModel.fromEntity(category),
    );
  }

  @override
  Future<void> updateCategory(
      CategoryEntity category,
      ) {
    return remoteDataSource.updateCategory(
      CategoryModel.fromEntity(category),
    );
  }

  @override
  Future<void> deleteCategory(
      String categoryId,
      ) {
    return remoteDataSource.deleteCategory(
      categoryId,
    );
  }
}