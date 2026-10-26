import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/budget_entity.dart';

class BudgetModel extends BudgetEntity {
  const BudgetModel({
    required super.id,
    required super.userId,
    required super.categoryId,
    required super.categoryName,
    required super.amount,
    required super.month,
    required super.createdAt,
  });

  factory BudgetModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc,
      ) {
    final data = doc.data() ?? {};

    return BudgetModel(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      categoryId: data['categoryId'] as String? ?? '',
      categoryName: data['categoryName'] as String? ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      month: (data['month'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdAt:
      (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'categoryId': categoryId,
      'categoryName': categoryName,
      'amount': amount,
      'month': Timestamp.fromDate(month),
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory BudgetModel.fromEntity(BudgetEntity budget) {
    return BudgetModel(
      id: budget.id,
      userId: budget.userId,
      categoryId: budget.categoryId,
      categoryName: budget.categoryName,
      amount: budget.amount,
      month: budget.month,
      createdAt: budget.createdAt,
    );
  }
}