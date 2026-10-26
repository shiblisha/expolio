import 'package:equatable/equatable.dart';

import '../../domain/entities/wallet_entity.dart';

enum WalletStatus {
  initial,
  loading,
  success,
  failure,
}

class WalletState extends Equatable {
  final WalletStatus status;
  final List<WalletEntity> wallets;
  final String? errorMessage;
  final bool isSaving;
  final bool isDeleting;
  final bool saveSuccess;

  const WalletState({
    this.status = WalletStatus.initial,
    this.wallets = const [],
    this.errorMessage,
    this.isSaving = false,
    this.isDeleting = false,
    this.saveSuccess = false,
  });

  WalletState copyWith({
    WalletStatus? status,
    List<WalletEntity>? wallets,
    String? errorMessage,
    bool clearError = false,
    bool? isSaving,
    bool? isDeleting,
    bool? saveSuccess,
  }) {
    return WalletState(
      status: status ?? this.status,
      wallets: wallets ?? this.wallets,
      errorMessage:
      clearError
          ? null
          : errorMessage ?? this.errorMessage,
      isSaving:
      isSaving ?? this.isSaving,
      isDeleting:
      isDeleting ?? this.isDeleting,
      saveSuccess:
      saveSuccess ?? this.saveSuccess,
    );
  }

  @override
  List<Object?> get props => [
    status,
    wallets,
    errorMessage,
    isSaving,
    isDeleting,
    saveSuccess,
  ];
}