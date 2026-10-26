import '../../domain/entities/wallet_entity.dart';
import '../../domain/repositories/wallet_repository.dart';
import '../datasources/wallet_remote_datasource.dart';

class WalletRepositoryImpl
    implements WalletRepository {
  final WalletRemoteDataSource remoteDataSource;

  WalletRepositoryImpl({
    required this.remoteDataSource,
  });

  @override
  Stream<List<WalletEntity>> watchWallets() {
    return remoteDataSource.watchWallets();
  }

  @override
  Future<void> addWallet(
      WalletEntity wallet,
      ) {
    return remoteDataSource.addWallet(wallet);
  }

  @override
  Future<void> updateWallet(
      WalletEntity wallet,
      ) {
    return remoteDataSource.updateWallet(wallet);
  }

  @override
  Future<void> deleteWallet(
      String walletId,
      ) {
    return remoteDataSource.deleteWallet(
      walletId,
    );
  }
}