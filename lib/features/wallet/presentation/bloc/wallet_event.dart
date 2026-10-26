import 'package:equatable/equatable.dart';

import '../../domain/entities/wallet_entity.dart';

abstract class WalletEvent extends Equatable {
  const WalletEvent();

  @override
  List<Object?> get props => [];
}

class LoadWallets extends WalletEvent {
  const LoadWallets();
}

class AddWalletEvent extends WalletEvent {
  final WalletEntity wallet;

  const AddWalletEvent(this.wallet);

  @override
  List<Object?> get props => [wallet];
}

class UpdateWalletEvent extends WalletEvent {
  final WalletEntity wallet;

  const UpdateWalletEvent(this.wallet);

  @override
  List<Object?> get props => [wallet];
}

class DeleteWalletEvent extends WalletEvent {
  final String walletId;

  const DeleteWalletEvent(this.walletId);

  @override
  List<Object?> get props => [walletId];
}

class WalletsUpdated extends WalletEvent {
  final List<WalletEntity> wallets;

  const WalletsUpdated(this.wallets);

  @override
  List<Object?> get props => [wallets];
}

class WalletsError extends WalletEvent {
  final String message;

  const WalletsError(this.message);

  @override
  List<Object?> get props => [message];
}