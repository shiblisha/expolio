import 'package:equatable/equatable.dart';

class BillEntity extends Equatable {
  final String id;
  final String userId;

  final String name;
  final double amount;

  final DateTime dueDate;

  final String categoryId;
  final String categoryName;

  final String? walletId;
  final String? walletName;

  final bool isRecurring;

  /// Examples:
  /// none
  /// weekly
  /// monthly
  /// yearly
  final String recurrence;

  final bool isPaid;
  final DateTime? paidAt;

  final DateTime createdAt;

  const BillEntity({
    required this.id,
    required this.userId,
    required this.name,
    required this.amount,
    required this.dueDate,
    required this.categoryId,
    required this.categoryName,
    this.walletId,
    this.walletName,
    required this.isRecurring,
    required this.recurrence,
    required this.isPaid,
    this.paidAt,
    required this.createdAt,
  });

  BillEntity copyWith({
    String? id,
    String? userId,
    String? name,
    double? amount,
    DateTime? dueDate,
    String? categoryId,
    String? categoryName,
    String? walletId,
    String? walletName,
    bool? isRecurring,
    String? recurrence,
    bool? isPaid,
    DateTime? paidAt,
    DateTime? createdAt,
    bool clearWallet = false,
    bool clearPaidAt = false,
  }) {
    return BillEntity(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      dueDate: dueDate ?? this.dueDate,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      walletId: clearWallet ? null : walletId ?? this.walletId,
      walletName: clearWallet ? null : walletName ?? this.walletName,
      isRecurring: isRecurring ?? this.isRecurring,
      recurrence: recurrence ?? this.recurrence,
      isPaid: isPaid ?? this.isPaid,
      paidAt: clearPaidAt ? null : paidAt ?? this.paidAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    userId,
    name,
    amount,
    dueDate,
    categoryId,
    categoryName,
    walletId,
    walletName,
    isRecurring,
    recurrence,
    isPaid,
    paidAt,
    createdAt,
  ];
}