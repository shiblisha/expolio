import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/enums/category_type.dart';
import '../../domain/entities/category_entity.dart';

class CategoryModel extends CategoryEntity {
  const CategoryModel({
    required super.id,
    required super.userId,
    required super.name,
    required super.type,
    required super.iconCodePoint,
    required super.colorValue,
    required super.isDefault,
    required super.createdAt,
  });

  factory CategoryModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc,
      ) {
    final data = doc.data() ?? {};

    final typeString =
        data['type'] as String? ?? 'expense';

    return CategoryModel(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      name: data['name'] as String? ?? '',
      type: CategoryType.values.firstWhere(
            (type) => type.name == typeString,
        orElse: () => CategoryType.expense,
      ),
      iconCodePoint:
      (data['iconCodePoint'] as num?)?.toInt() ??
          0,
      colorValue:
      (data['colorValue'] as num?)?.toInt() ??
          0xFF2F7E79,
      isDefault:
      data['isDefault'] as bool? ?? false,
      createdAt:
      (data['createdAt'] as Timestamp?)
          ?.toDate() ??
          DateTime.now(),
    );
  }

  factory CategoryModel.fromEntity(
      CategoryEntity category,
      ) {
    return CategoryModel(
      id: category.id,
      userId: category.userId,
      name: category.name,
      type: category.type,
      iconCodePoint:
      category.iconCodePoint,
      colorValue:
      category.colorValue,
      isDefault:
      category.isDefault,
      createdAt:
      category.createdAt,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'name': name,
      'type': type.name,
      'iconCodePoint': iconCodePoint,
      'colorValue': colorValue,
      'isDefault': isDefault,
      'createdAt':
      Timestamp.fromDate(createdAt),
    };
  }
}