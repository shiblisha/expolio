import 'package:flutter/foundation.dart';

import '../../../../core/enums/payment_method.dart';
import '../../../../core/enums/transaction_type.dart';

enum RecurringFrequency {
  daily,
  weekly,
  monthly,
  yearly,
}

extension RecurringFrequencyX on RecurringFrequency {
  String get value => name;

  String get label {
    switch (this) {
      case RecurringFrequency.daily:
        return 'Daily';
      case RecurringFrequency.weekly:
        return 'Weekly';
      case RecurringFrequency.monthly:
        return 'Monthly';
      case RecurringFrequency.yearly:
        return 'Yearly';
    }
  }

  static RecurringFrequency fromString(String value) {
    return RecurringFrequency.values.firstWhere(
      (item) => item.name == value,
      orElse: () => RecurringFrequency.monthly,
    );
  }
}

@immutable
class RecurringTransactionEntity {
  final String id;
  final String userId;
  final double amount;
  final TransactionType type;
  final String categoryId;
  final String categoryName;
  final PaymentMethod paymentMethod;
  final String description;
  final String walletId;
  final String walletName;
  final RecurringFrequency frequency;
  final DateTime nextDueDate;
  final int dayOfMonth;
  final int monthOfYear;
  final bool active;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastRunAt;

  const RecurringTransactionEntity({
    required this.id,
    required this.userId,
    required this.amount,
    required this.type,
    required this.categoryId,
    required this.categoryName,
    required this.paymentMethod,
    required this.description,
    required this.walletId,
    required this.walletName,
    required this.frequency,
    required this.nextDueDate,
    required this.dayOfMonth,
    required this.monthOfYear,
    required this.active,
    required this.createdAt,
    required this.updatedAt,
    required this.lastRunAt,
  });

  RecurringTransactionEntity copyWith({
    String? id,
    String? userId,
    double? amount,
    TransactionType? type,
    String? categoryId,
    String? categoryName,
    PaymentMethod? paymentMethod,
    String? description,
    String? walletId,
    String? walletName,
    RecurringFrequency? frequency,
    DateTime? nextDueDate,
    int? dayOfMonth,
    int? monthOfYear,
    bool? active,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastRunAt,
    bool clearLastRunAt = false,
  }) {
    return RecurringTransactionEntity(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      description: description ?? this.description,
      walletId: walletId ?? this.walletId,
      walletName: walletName ?? this.walletName,
      frequency: frequency ?? this.frequency,
      nextDueDate: nextDueDate ?? this.nextDueDate,
      dayOfMonth: dayOfMonth ?? this.dayOfMonth,
      monthOfYear: monthOfYear ?? this.monthOfYear,
      active: active ?? this.active,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastRunAt: clearLastRunAt ? null : (lastRunAt ?? this.lastRunAt),
    );
  }
}
