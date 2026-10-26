import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/enums/payment_method.dart';
import '../../../../core/enums/transaction_type.dart';
import '../models/bill_model.dart';

class BillRemoteDataSource {
  final FirebaseFirestore firestore;
  final FirebaseAuth firebaseAuth;

  BillRemoteDataSource({
    FirebaseFirestore? firestore,
    FirebaseAuth? firebaseAuth,
  })  : firestore = firestore ?? FirebaseFirestore.instance,
        firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> _billsCollection(String userId) {
    return firestore
        .collection('users')
        .doc(userId)
        .collection('bills');
  }

  CollectionReference<Map<String, dynamic>> _transactionsCollection(
      String userId,
      ) {
    return firestore
        .collection('users')
        .doc(userId)
        .collection('transactions');
  }

  String _getUserId() {
    final user = firebaseAuth.currentUser;
    if (user == null) {
      throw Exception('User is not authenticated');
    }
    return user.uid;
  }

  Future<List<BillModel>> getBills() async {
    final userId = _getUserId();

    final snapshot = await _billsCollection(userId)
        .orderBy('dueDate')
        .get();

    return snapshot.docs
        .map(BillModel.fromFirestore)
        .toList();
  }

  Future<void> addBill(BillModel bill) async {
    final userId = _getUserId();

    await _billsCollection(userId).add(
      bill.toFirestore(),
    );
  }

  Future<void> updateBill(BillModel bill) async {
    final userId = _getUserId();

    await _billsCollection(userId)
        .doc(bill.id)
        .update(bill.toFirestore());
  }

  Future<void> deleteBill(String billId) async {
    final userId = _getUserId();

    if (billId.isEmpty) {
      throw Exception('Bill ID is required');
    }

    final billRef = _billsCollection(userId).doc(billId);

    // Bill payment transactions use the deterministic ID
    // `bill_<billId>`. Delete both documents together so deleting
    // a bill cannot leave its payment transaction behind.
    final transactionRef = _transactionsCollection(userId)
        .doc('bill_$billId');

    final batch = firestore.batch();

    batch.delete(transactionRef);
    batch.delete(billRef);

    await batch.commit();
  }

  // ============================================================
  // MARK BILL AS PAID + CREATE NEXT RECURRING BILL
  // ============================================================

  Future<void> markBillPaid(BillModel bill) async {
    final userId = _getUserId();

    if (bill.id.isEmpty) {
      throw Exception('Bill ID is required');
    }

    if (bill.walletId == null || bill.walletId!.isEmpty) {
      throw Exception('Payment wallet is required for a bill');
    }

    final now = DateTime.now();

    final billRef = _billsCollection(userId).doc(bill.id);

    // Deterministic transaction ID prevents duplicate expenses on retry.
    final transactionRef = _transactionsCollection(userId)
        .doc('bill_${bill.id}');

    final batch = firestore.batch();

    // ==========================================================
    // 1. CREATE EXPENSE TRANSACTION
    // ==========================================================

    batch.set(transactionRef, {
      'userId': userId,
      'amount': bill.amount,
      'type': TransactionType.expense.name,
      'categoryId': bill.categoryId,
      'categoryName': bill.categoryName,
      'paymentMethod': PaymentMethod.bank.name,
      'description': bill.name,
      'date': Timestamp.fromDate(now),
      'createdAt': Timestamp.fromDate(now),
      'walletId': bill.walletId,
      'walletName': bill.walletName ?? '',
      'fromWalletId': '',
      'fromWalletName': '',
      'toWalletId': '',
      'toWalletName': '',
    });

    // ==========================================================
    // 2. MARK CURRENT BILL AS PAID
    // ==========================================================

    batch.update(billRef, {
      'isPaid': true,
      'paidAt': Timestamp.fromDate(now),
    });

    // ==========================================================
    // 3. CREATE NEXT RECURRING BILL
    // ==========================================================

    if (bill.isRecurring) {
      final nextDueDate = _calculateNextDueDate(
        bill.dueDate,
        bill.recurrence,
      );

      if (nextDueDate != null) {
        // Deterministic ID makes recurring bill creation idempotent.
        final nextBillId = _recurringBillId(
          bill.id,
          nextDueDate,
        );

        final nextBillRef = _billsCollection(userId)
            .doc(nextBillId);

        batch.set(nextBillRef, {
          'userId': userId,
          'name': bill.name,
          'amount': bill.amount,
          'dueDate': Timestamp.fromDate(nextDueDate),
          'categoryId': bill.categoryId,
          'categoryName': bill.categoryName,
          'walletId': bill.walletId,
          'walletName': bill.walletName,
          'isRecurring': true,
          'recurrence': bill.recurrence,
          'isPaid': false,
          'paidAt': null,
          'createdAt': Timestamp.fromDate(now),
        });
      }
    }

    // ==========================================================
    // COMMIT EVERYTHING TOGETHER
    // ==========================================================

    await batch.commit();
  }

  // ============================================================
  // NEXT DUE DATE
  // ============================================================

  DateTime? _calculateNextDueDate(
      DateTime currentDate,
      String recurrence,
      ) {
    switch (recurrence.toLowerCase()) {
      case 'weekly':
        return currentDate.add(
          const Duration(days: 7),
        );

      case 'monthly':
        final targetYear = currentDate.month == 12
            ? currentDate.year + 1
            : currentDate.year;

        final targetMonth = currentDate.month == 12
            ? 1
            : currentDate.month + 1;

        final lastDayOfTargetMonth = DateTime(
          targetYear,
          targetMonth + 1,
          0,
        ).day;

        final targetDay = currentDate.day > lastDayOfTargetMonth
            ? lastDayOfTargetMonth
            : currentDate.day;

        return DateTime(
          targetYear,
          targetMonth,
          targetDay,
        );

      case 'yearly':
        final targetYear = currentDate.year + 1;

        final lastDayOfTargetMonth = DateTime(
          targetYear,
          currentDate.month + 1,
          0,
        ).day;

        final targetDay = currentDate.day > lastDayOfTargetMonth
            ? lastDayOfTargetMonth
            : currentDate.day;

        return DateTime(
          targetYear,
          currentDate.month,
          targetDay,
        );

      default:
        return null;
    }
  }

  String _recurringBillId(
      String billId,
      DateTime dueDate,
      ) {
    final dateKey = '${dueDate.year}_'
        '${dueDate.month.toString().padLeft(2, '0')}_'
        '${dueDate.day.toString().padLeft(2, '0')}';

    return '${billId}_recurring_$dateKey';
  }
}
