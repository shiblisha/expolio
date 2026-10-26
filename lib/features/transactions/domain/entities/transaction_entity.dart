import 'package:equatable/equatable.dart';

import '../../../../core/enums/payment_method.dart';
import '../../../../core/enums/transaction_type.dart';

class TransactionEntity extends Equatable {
  final String id;
  final String userId;

  final double amount;

  final TransactionType type;

  final String categoryId;
  final String categoryName;

  final PaymentMethod paymentMethod;

  final String description;

  final DateTime date;
  final DateTime createdAt;

  // ------------------------------------------------------------
  // NORMAL TRANSACTION WALLET
  // ------------------------------------------------------------

  final String walletId;
  final String walletName;

  // ------------------------------------------------------------
  // TRANSFER WALLETS
  // ------------------------------------------------------------

  final String fromWalletId;
  final String fromWalletName;

  final String toWalletId;
  final String toWalletName;

  const TransactionEntity({
    required this.id,
    required this.userId,
    required this.amount,
    required this.type,
    required this.categoryId,
    required this.categoryName,
    required this.paymentMethod,
    required this.description,
    required this.date,
    required this.createdAt,
    this.walletId = '',
    this.walletName = '',
    this.fromWalletId = '',
    this.fromWalletName = '',
    this.toWalletId = '',
    this.toWalletName = '',
  });

  TransactionEntity copyWith({
    String? id,
    String? userId,
    double? amount,
    TransactionType? type,
    String? categoryId,
    String? categoryName,
    PaymentMethod? paymentMethod,
    String? description,
    DateTime? date,
    DateTime? createdAt,
    String? walletId,
    String? walletName,
    String? fromWalletId,
    String? fromWalletName,
    String? toWalletId,
    String? toWalletName,
  }) {
    return TransactionEntity(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      categoryId:
      categoryId ?? this.categoryId,
      categoryName:
      categoryName ?? this.categoryName,
      paymentMethod:
      paymentMethod ?? this.paymentMethod,
      description:
      description ?? this.description,
      date: date ?? this.date,
      createdAt:
      createdAt ?? this.createdAt,
      walletId:
      walletId ?? this.walletId,
      walletName:
      walletName ?? this.walletName,
      fromWalletId:
      fromWalletId ?? this.fromWalletId,
      fromWalletName:
      fromWalletName ?? this.fromWalletName,
      toWalletId:
      toWalletId ?? this.toWalletId,
      toWalletName:
      toWalletName ?? this.toWalletName,
    );
  }

  @override
  List<Object?> get props => [
    id,
    userId,
    amount,
    type,
    categoryId,
    categoryName,
    paymentMethod,
    description,
    date,
    createdAt,
    walletId,
    walletName,
    fromWalletId,
    fromWalletName,
    toWalletId,
    toWalletName,
  ];
}