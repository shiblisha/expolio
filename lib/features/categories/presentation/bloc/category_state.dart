import 'package:equatable/equatable.dart';

import '../../domain/entities/category_entity.dart';

enum CategoryStatus {
  initial,
  loading,
  success,
  failure,
}

class CategoryState extends Equatable {
  final CategoryStatus status;
  final List<CategoryEntity> categories;
  final bool isSaving;
  final bool isDeleting;
  final String? errorMessage;

  const CategoryState({
    this.status = CategoryStatus.initial,
    this.categories = const [],
    this.isSaving = false,
    this.isDeleting = false,
    this.errorMessage,
  });

  CategoryState copyWith({
    CategoryStatus? status,
    List<CategoryEntity>? categories,
    bool? isSaving,
    bool? isDeleting,
    String? errorMessage,
    bool clearError = false,
  }) {
    return CategoryState(
      status: status ?? this.status,
      categories:
      categories ?? this.categories,
      isSaving:
      isSaving ?? this.isSaving,
      isDeleting:
      isDeleting ?? this.isDeleting,
      errorMessage: clearError
          ? null
          : errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    status,
    categories,
    isSaving,
    isDeleting,
    errorMessage,
  ];
}