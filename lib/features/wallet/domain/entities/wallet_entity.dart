import 'package:equatable/equatable.dart';

import '../../../../../core/enums/wallet_type.dart';

class WalletEntity extends Equatable {
  final String id;
  final String userId;
  final String name;
  final WalletType type;
  final double initialBalance;
  final DateTime createdAt;

  const WalletEntity({
    required this.id,
    required this.userId,
    required this.name,
    required this.type,
    required this.initialBalance,
    required this.createdAt,
  });

  WalletEntity copyWith({
    String? id,
    String? userId,
    String? name,
    WalletType? type,
    double? initialBalance,
    DateTime? createdAt,
  }) {
    return WalletEntity(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      type: type ?? this.type,
      initialBalance:
      initialBalance ?? this.initialBalance,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    userId,
    name,
    type,
    initialBalance,
    createdAt,
  ];
}