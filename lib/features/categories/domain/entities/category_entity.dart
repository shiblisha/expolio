import 'package:equatable/equatable.dart';

import '../../../../core/enums/category_type.dart';

class CategoryEntity extends Equatable {
  final String id;
  final String userId;
  final String name;
  final CategoryType type;

  // IconData is not directly stored in Firestore.
  // We store the IconData codePoint instead.
  final int iconCodePoint;

  // Store color as integer ARGB value.
  final int colorValue;

  final bool isDefault;
  final DateTime createdAt;

  const CategoryEntity({
    required this.id,
    required this.userId,
    required this.name,
    required this.type,
    required this.iconCodePoint,
    required this.colorValue,
    required this.isDefault,
    required this.createdAt,
  });

  CategoryEntity copyWith({
    String? id,
    String? userId,
    String? name,
    CategoryType? type,
    int? iconCodePoint,
    int? colorValue,
    bool? isDefault,
    DateTime? createdAt,
  }) {
    return CategoryEntity(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      type: type ?? this.type,
      iconCodePoint:
      iconCodePoint ?? this.iconCodePoint,
      colorValue:
      colorValue ?? this.colorValue,
      isDefault:
      isDefault ?? this.isDefault,
      createdAt:
      createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    userId,
    name,
    type,
    iconCodePoint,
    colorValue,
    isDefault,
    createdAt,
  ];
}