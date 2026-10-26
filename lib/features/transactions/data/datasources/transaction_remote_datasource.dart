import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/enums/payment_method.dart';
import '../../../../core/enums/transaction_type.dart';
import '../../domain/entities/transaction_entity.dart';

abstract class TransactionRemoteDataSource {
  Stream<List<TransactionEntity>> watchTransactions();

  Future<void> addTransaction(
      TransactionEntity transaction,
      );

  Future<void> updateTransaction(
      TransactionEntity transaction,
      );

  Future<void> deleteTransaction(
      String transactionId,
      );
}

class TransactionRemoteDataSourceImpl
    implements TransactionRemoteDataSource {
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;

  TransactionRemoteDataSourceImpl({
    required this.firestore,
    required this.auth,
  });

  String get _userId {
    final user = auth.currentUser;

    if (user == null) {
      throw Exception(
        'User is not authenticated',
      );
    }

    return user.uid;
  }

  CollectionReference<Map<String, dynamic>>
  get _transactionsRef {
    return firestore
        .collection('users')
        .doc(_userId)
        .collection('transactions');
  }

  CollectionReference<Map<String, dynamic>>
  get _billsRef {
    return firestore
        .collection('users')
        .doc(_userId)
        .collection('bills');
  }

  // ============================================================
  // WATCH TRANSACTIONS
  // ============================================================

  @override
  Stream<List<TransactionEntity>> watchTransactions() {
    return _transactionsRef
        .orderBy(
      'date',
      descending: true,
    )
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();

        return TransactionEntity(
          id: doc.id,
          userId: data['userId'] as String? ?? _userId,

          amount:
          (data['amount'] as num?)?.toDouble() ?? 0.0,

          type: _parseTransactionType(
            data['type'] as String?,
          ),

          categoryId:
          data['categoryId'] as String? ?? '',

          categoryName:
          data['categoryName'] as String? ?? '',

          paymentMethod:
          _parsePaymentMethod(
            data['paymentMethod'] as String?,
          ),

          description:
          data['description'] as String? ?? '',

          date: _parseDate(
            data['date'],
          ),

          createdAt: _parseDate(
            data['createdAt'],
          ),

          walletId:
          data['walletId'] as String? ?? '',

          walletName:
          data['walletName'] as String? ?? '',

          fromWalletId:
          data['fromWalletId'] as String? ?? '',

          fromWalletName:
          data['fromWalletName'] as String? ?? '',

          toWalletId:
          data['toWalletId'] as String? ?? '',

          toWalletName:
          data['toWalletName'] as String? ?? '',
        );
      }).toList();
    });
  }

  // ============================================================
  // ADD TRANSACTION
  // ============================================================

  @override
  Future<void> addTransaction(
      TransactionEntity transaction,
      ) async {
    // ----------------------------------------------------------
    // USE PROVIDED ID WHEN AVAILABLE
    // ----------------------------------------------------------
    //
    // Normal transactions:
    //   id == '' → Firestore generates a new document ID
    //
    // Bill payment transactions:
    //   id == 'bill_<billId>'
    //   → Firestore reuses the same document on retry
    //

    final document = transaction.id.isNotEmpty
        ? _transactionsRef.doc(transaction.id)
        : _transactionsRef.doc();

    await document.set({
      'userId': _userId,

      'amount': transaction.amount,

      'type': transaction.type.name,

      'categoryId': transaction.categoryId,

      'categoryName': transaction.categoryName,

      'paymentMethod': transaction.paymentMethod.name,

      'description': transaction.description,

      'date': Timestamp.fromDate(
        transaction.date,
      ),

      'createdAt': Timestamp.fromDate(
        transaction.createdAt,
      ),

      // --------------------------------------------------------
      // WALLET
      // --------------------------------------------------------

      'walletId': transaction.walletId,

      'walletName': transaction.walletName,

      // --------------------------------------------------------
      // TRANSFER
      // --------------------------------------------------------

      'fromWalletId': transaction.fromWalletId,

      'fromWalletName': transaction.fromWalletName,

      'toWalletId': transaction.toWalletId,

      'toWalletName': transaction.toWalletName,
    });
  }

  // ============================================================
  // UPDATE TRANSACTION
  // ============================================================

  @override
  Future<void> updateTransaction(
      TransactionEntity transaction,
      ) async {
    if (transaction.id.isEmpty) {
      throw Exception(
        'Transaction ID is required for update',
      );
    }

    await _transactionsRef
        .doc(transaction.id)
        .update({
      'userId': _userId,

      'amount': transaction.amount,

      'type': transaction.type.name,

      'categoryId': transaction.categoryId,

      'categoryName': transaction.categoryName,

      'paymentMethod': transaction.paymentMethod.name,

      'description': transaction.description,

      'date': Timestamp.fromDate(
        transaction.date,
      ),

      // Keep original createdAt
      'createdAt': Timestamp.fromDate(
        transaction.createdAt,
      ),

      // --------------------------------------------------------
      // WALLET
      // --------------------------------------------------------

      'walletId': transaction.walletId,

      'walletName': transaction.walletName,

      // --------------------------------------------------------
      // TRANSFER
      // --------------------------------------------------------

      'fromWalletId': transaction.fromWalletId,

      'fromWalletName': transaction.fromWalletName,

      'toWalletId': transaction.toWalletId,

      'toWalletName': transaction.toWalletName,
    });
  }

  // ============================================================
  // DELETE TRANSACTION
  // ============================================================

  @override
  Future<void> deleteTransaction(
      String transactionId,
      ) async {
    if (transactionId.isEmpty) {
      throw Exception(
        'Transaction ID is required for delete',
      );
    }

    final transactionRef =
    _transactionsRef.doc(transactionId);

    // ----------------------------------------------------------
    // BILL PAYMENT TRANSACTION
    // ----------------------------------------------------------
    //
    // Bill payment transaction IDs are:
    //
    //   bill_<billId>
    //
    // Example:
    //   bill_abc123
    //
    // When this transaction is deleted, also delete:
    //
    //   users/{userId}/bills/abc123
    //
    // Both operations are committed together in one batch.
    //

    if (transactionId.startsWith('bill_')) {
      final billId = transactionId.substring(5);

      if (billId.isEmpty) {
        throw Exception(
          'Invalid bill transaction ID',
        );
      }

      final billRef = _billsRef.doc(billId);

      final batch = firestore.batch();

      // Delete linked bill
      batch.delete(billRef);

      // Delete linked transaction
      batch.delete(transactionRef);

      await batch.commit();

      return;
    }

    // ----------------------------------------------------------
    // NORMAL TRANSACTION
    // ----------------------------------------------------------

    await transactionRef.delete();
  }

  // ============================================================
  // PARSE TRANSACTION TYPE
  // ============================================================

  TransactionType _parseTransactionType(
      String? value,
      ) {
    switch (value) {
      case 'income':
        return TransactionType.income;

      case 'transfer':
        return TransactionType.transfer;

      case 'expense':
      default:
        return TransactionType.expense;
    }
  }

  // ============================================================
  // PARSE PAYMENT METHOD
  // ============================================================

  PaymentMethod _parsePaymentMethod(
      String? value,
      ) {
    switch (value) {
      case 'card':
        return PaymentMethod.card;

      case 'bank':
        return PaymentMethod.bank;

      case 'upi':
        return PaymentMethod.upi;

      case 'cash':
      default:
        return PaymentMethod.cash;
    }
  }

  // ============================================================
  // PARSE DATE
  // ============================================================

  DateTime _parseDate(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    return DateTime.now();
  }
}