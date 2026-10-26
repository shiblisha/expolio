import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/bill_entity.dart';

class BillModel extends BillEntity {
  const BillModel({
    required super.id,
    required super.userId,
    required super.name,
    required super.amount,
    required super.dueDate,
    required super.categoryId,
    required super.categoryName,
    super.walletId,
    super.walletName,
    required super.isRecurring,
    required super.recurrence,
    required super.isPaid,
    super.paidAt,
    required super.createdAt,
  });

  factory BillModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> document,
      ) {
    final data = document.data() ?? <String, dynamic>{};

    return BillModel(
      id: document.id,
      userId: data['userId'] as String? ?? '',
      name: data['name'] as String? ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      dueDate: _dateFromFirestore(data['dueDate']),
      categoryId: data['categoryId'] as String? ?? '',
      categoryName: data['categoryName'] as String? ?? '',
      walletId: data['walletId'] as String?,
      walletName: data['walletName'] as String?,
      isRecurring: data['isRecurring'] as bool? ?? false,
      recurrence: data['recurrence'] as String? ?? 'none',
      isPaid: data['isPaid'] as bool? ?? false,
      paidAt: _nullableDateFromFirestore(data['paidAt']),
      createdAt: _dateFromFirestore(data['createdAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'name': name,
      'amount': amount,
      'dueDate': Timestamp.fromDate(dueDate),
      'categoryId': categoryId,
      'categoryName': categoryName,
      'walletId': walletId,
      'walletName': walletName,
      'isRecurring': isRecurring,
      'recurrence': recurrence,
      'isPaid': isPaid,
      'paidAt': paidAt == null
          ? null
          : Timestamp.fromDate(paidAt!),
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  static DateTime _dateFromFirestore(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return DateTime.now();
  }

  static DateTime? _nullableDateFromFirestore(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return null;
  }
}