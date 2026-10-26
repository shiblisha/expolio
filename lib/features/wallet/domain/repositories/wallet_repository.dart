import '../entities/wallet_entity.dart';

abstract class WalletRepository {
  Stream<List<WalletEntity>> watchWallets();

  Future<void> addWallet(WalletEntity wallet);

  Future<void> updateWallet(WalletEntity wallet);

  Future<void> deleteWallet(String walletId);
}