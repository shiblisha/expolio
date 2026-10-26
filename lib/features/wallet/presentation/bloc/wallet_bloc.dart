import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/wallet_entity.dart';
import '../../domain/repositories/wallet_repository.dart';
import 'wallet_event.dart';
import 'wallet_state.dart';

class WalletBloc
    extends Bloc<WalletEvent, WalletState> {
  final WalletRepository repository;

  StreamSubscription<List<WalletEntity>>?
  _walletsSubscription;

  WalletBloc({
    required this.repository,
  }) : super(const WalletState()) {
    on<LoadWallets>(_onLoadWallets);
    on<AddWalletEvent>(_onAddWallet);
    on<UpdateWalletEvent>(_onUpdateWallet);
    on<DeleteWalletEvent>(_onDeleteWallet);

    on<WalletsUpdated>(_onWalletsUpdated);
    on<WalletsError>(_onWalletsError);
  }

  Future<void> _onLoadWallets(
      LoadWallets event,
      Emitter<WalletState> emit,
      ) async {
    emit(
      state.copyWith(
        status: WalletStatus.loading,
        clearError: true,
      ),
    );

    await _walletsSubscription?.cancel();

    _walletsSubscription =
        repository.watchWallets().listen(
              (wallets) {
            add(
              WalletsUpdated(wallets),
            );
          },
          onError: (error) {
            add(
              WalletsError(
                error.toString(),
              ),
            );
          },
        );
  }

  Future<void> _onAddWallet(
      AddWalletEvent event,
      Emitter<WalletState> emit,
      ) async {
    emit(
      state.copyWith(
        isSaving: true,
        saveSuccess: false,
        clearError: true,
      ),
    );

    try {
      await repository.addWallet(
        event.wallet,
      );

      emit(
        state.copyWith(
          isSaving: false,
          saveSuccess: true,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          isSaving: false,
          saveSuccess: false,
          status: WalletStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> _onUpdateWallet(
      UpdateWalletEvent event,
      Emitter<WalletState> emit,
      ) async {
    emit(
      state.copyWith(
        isSaving: true,
        saveSuccess: false,
        clearError: true,
      ),
    );

    try {
      await repository.updateWallet(
        event.wallet,
      );

      emit(
        state.copyWith(
          isSaving: false,
          saveSuccess: true,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          isSaving: false,
          saveSuccess: false,
          status: WalletStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> _onDeleteWallet(
      DeleteWalletEvent event,
      Emitter<WalletState> emit,
      ) async {
    final previousWallets =
    List.of(state.wallets);

    final updatedWallets =
    previousWallets
        .where(
          (wallet) =>
      wallet.id !=
          event.walletId,
    )
        .toList();

    emit(
      state.copyWith(
        wallets: updatedWallets,
        isDeleting: true,
        clearError: true,
      ),
    );

    try {
      await repository.deleteWallet(
        event.walletId,
      );

      emit(
        state.copyWith(
          isDeleting: false,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          wallets: previousWallets,
          isDeleting: false,
          status: WalletStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  void _onWalletsUpdated(
      WalletsUpdated event,
      Emitter<WalletState> emit,
      ) {
    emit(
      state.copyWith(
        status: WalletStatus.success,
        wallets: event.wallets,
        saveSuccess: false,
        clearError: true,
      ),
    );
  }

  void _onWalletsError(
      WalletsError event,
      Emitter<WalletState> emit,
      ) {
    emit(
      state.copyWith(
        status: WalletStatus.failure,
        errorMessage: event.message,
      ),
    );
  }

  @override
  Future<void> close() async {
    await _walletsSubscription?.cancel();
    return super.close();
  }
}