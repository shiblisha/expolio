import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/add_category.dart';
import '../../domain/usecases/delete_category.dart';
import '../../domain/usecases/get_categories.dart';
import '../../domain/usecases/seed_default_categories.dart';
import '../../domain/usecases/update_category.dart';

import 'category_event.dart';
import 'category_state.dart';

class CategoryBloc extends Bloc<CategoryEvent, CategoryState> {
  final GetCategories getCategories;
  final AddCategory addCategory;
  final UpdateCategory updateCategory;
  final DeleteCategory deleteCategory;
  final SeedDefaultCategories seedDefaultCategories;

  CategoryBloc({
    required this.getCategories,
    required this.addCategory,
    required this.updateCategory,
    required this.deleteCategory,
    required this.seedDefaultCategories,
  }) : super(const CategoryState()) {
    on<LoadCategories>(_onLoadCategories);
    on<AddCategoryEvent>(_onAddCategory);
    on<UpdateCategoryEvent>(_onUpdateCategory);
    on<DeleteCategoryEvent>(_onDeleteCategory);
  }

  Future<void> _onLoadCategories(
      LoadCategories event,
      Emitter<CategoryState> emit,
      ) async {
    emit(
      state.copyWith(
        status: CategoryStatus.loading,
        clearError: true,
      ),
    );

    try {
      var categories = await getCategories();

      // ==========================================================
      // CREATE DEFAULT CATEGORIES FOR NEW USERS
      // ==========================================================

      if (categories.isEmpty) {
        final user = FirebaseAuth.instance.currentUser;

        if (user != null) {
          await seedDefaultCategories(user.uid);

          categories = await getCategories();
        }
      }

      emit(
        state.copyWith(
          status: CategoryStatus.success,
          categories: categories,
          clearError: true,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: CategoryStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> _onAddCategory(
      AddCategoryEvent event,
      Emitter<CategoryState> emit,
      ) async {
    emit(
      state.copyWith(
        isSaving: true,
        clearError: true,
      ),
    );

    try {
      await addCategory(event.category);

      final categories = await getCategories();

      emit(
        state.copyWith(
          status: CategoryStatus.success,
          categories: categories,
          isSaving: false,
          clearError: true,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: CategoryStatus.failure,
          isSaving: false,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> _onUpdateCategory(
      UpdateCategoryEvent event,
      Emitter<CategoryState> emit,
      ) async {
    emit(
      state.copyWith(
        isSaving: true,
        clearError: true,
      ),
    );

    try {
      await updateCategory(event.category);

      final categories = await getCategories();

      emit(
        state.copyWith(
          status: CategoryStatus.success,
          categories: categories,
          isSaving: false,
          clearError: true,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: CategoryStatus.failure,
          isSaving: false,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> _onDeleteCategory(
      DeleteCategoryEvent event,
      Emitter<CategoryState> emit,
      ) async {
    emit(
      state.copyWith(
        isDeleting: true,
        clearError: true,
      ),
    );

    try {
      await deleteCategory(event.categoryId);

      final categories = await getCategories();

      emit(
        state.copyWith(
          status: CategoryStatus.success,
          categories: categories,
          isDeleting: false,
          clearError: true,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: CategoryStatus.failure,
          isDeleting: false,
          errorMessage: e.toString(),
        ),
      );
    }
  }
}