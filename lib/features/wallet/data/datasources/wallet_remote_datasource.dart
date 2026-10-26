import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/enums/wallet_type.dart';
import '../../domain/entities/wallet_entity.dart';

abstract class WalletRemoteDataSource {
  Stream<List<WalletEntity>> watchWallets();

  Future<void> addWallet(WalletEntity wallet);

  Future<void> updateWallet(WalletEntity wallet);

  Future<void> deleteWallet(String walletId);
}

class WalletRemoteDataSourceImpl
    implements WalletRemoteDataSource {
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;

  WalletRemoteDataSourceImpl({
    required this.firestore,
    required this.auth,
  });

  String get _userId {
    final user = auth.currentUser;

    if (user == null) {
      throw Exception('User is not authenticated');
    }

    return user.uid;
  }

  CollectionReference<Map<String, dynamic>>
  get _walletsRef {
    return firestore
        .collection('users')
        .doc(_userId)
        .collection('wallets');
  }

  @override
  Stream<List<WalletEntity>> watchWallets() {
    return _walletsRef
        .orderBy('createdAt')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();

        return WalletEntity(
          id: doc.id,
          userId:
          data['userId'] as String? ?? _userId,
          name: data['name'] as String? ?? '',
          type: _parseWalletType(
            data['type'] as String?,
          ),
          initialBalance:
          (data['initialBalance'] as num?)
              ?.toDouble() ??
              0.0,
          createdAt: _parseDate(
            data['createdAt'],
          ),
        );
      }).toList();
    });
  }

  @override
  Future<void> addWallet(
      WalletEntity wallet,
      ) async {
    final document = _walletsRef.doc();

    await document.set({
      'userId': _userId,
      'name': wallet.name,
      'type': wallet.type.name,
      'initialBalance': wallet.initialBalance,
      'createdAt': Timestamp.fromDate(
        wallet.createdAt,
      ),
    });
  }

  @override
  Future<void> updateWallet(
      WalletEntity wallet,
      ) async {
    await _walletsRef.doc(wallet.id).update({
      'name': wallet.name,
      'type': wallet.type.name,
      'initialBalance': wallet.initialBalance,
    });
  }

  @override
  Future<void> deleteWallet(
      String walletId,
      ) async {
    await _walletsRef
        .doc(walletId)
        .delete();
  }

  WalletType _parseWalletType(String? value) {
    switch (value) {
      case 'cash':
        return WalletType.cash;

      case 'bank':
        return WalletType.bank;

      case 'upi':
        return WalletType.upi;

      case 'card':
        return WalletType.card;

      case 'savings':
        return WalletType.savings;

      case 'other':
      default:
        return WalletType.other;
    }
  }

  DateTime _parseDate(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    return DateTime.now();
  }
}