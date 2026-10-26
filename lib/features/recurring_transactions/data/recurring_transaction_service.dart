import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/enums/app_currency.dart';
import '../../../../core/enums/payment_method.dart';
import '../../../../core/enums/transaction_type.dart';
import '../../../../core/notifications/local_notification_service.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../domain/entities/recurring_transaction_entity.dart';

class RecurringTransactionService {
  RecurringTransactionService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    Uuid? uuid,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _uuid = uuid ?? const Uuid();

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final Uuid _uuid;

  User get _user {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('User is not authenticated');
    }
    return user;
  }

  CollectionReference<Map<String, dynamic>> _collection(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('recurring_transactions');
  }

  CollectionReference<Map<String, dynamic>> _transactionsCollection(
    String userId,
  ) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('transactions');
  }

  Future<List<RecurringTransactionEntity>> getAll() async {
    final user = _user;

    final snapshot = await _collection(user.uid).get();

    final items = snapshot.docs.map((doc) {
      return _fromDocument(doc);
    }).toList();

    items.sort((a, b) {
      if (a.active != b.active) {
        return a.active ? -1 : 1;
      }
      return a.nextDueDate.compareTo(b.nextDueDate);
    });

    return items;
  }

  Future<String> save(RecurringTransactionEntity item) async {
    final user = _user;

    final doc = item.id.isEmpty
        ? _collection(user.uid).doc(_uuid.v4())
        : _collection(user.uid).doc(item.id);

    if (item.userId.isNotEmpty && item.userId != user.uid) {
      throw StateError('You cannot save a recurring transaction for another account');
    }

    final now = DateTime.now();

    final data = {
      'id': doc.id,
      'userId': user.uid,
      'amount': item.amount,
      'type': item.type.name,
      'categoryId': item.categoryId,
      'categoryName': item.categoryName,
      'paymentMethod': item.paymentMethod.name,
      'description': item.description.trim(),
      'walletId': item.walletId,
      'walletName': item.walletName,
      'frequency': item.frequency.value,
      'nextDueDate': Timestamp.fromDate(item.nextDueDate),
      'dayOfMonth': item.dayOfMonth,
      'monthOfYear': item.monthOfYear,
      'active': item.active,
      'createdAt': item.id.isEmpty
          ? Timestamp.fromDate(now)
          : Timestamp.fromDate(item.createdAt),
      'updatedAt': Timestamp.fromDate(now),
      'lastRunAt': item.lastRunAt == null
          ? null
          : Timestamp.fromDate(item.lastRunAt!),
    };

    await doc.set(
      data,
      SetOptions(merge: true),
    );

    // When an existing recurring rule is edited, also sync the
    // latest transaction that was already generated from that rule.
    // Historical occurrences are intentionally left unchanged;
    // future occurrences will use the newly saved recurring values.
    if (item.id.isNotEmpty) {
      await _syncLatestGeneratedTransaction(
        userId: user.uid,
        recurringId: doc.id,
        item: item,
      );
    }

    return doc.id;
  }

  Future<void> _syncLatestGeneratedTransaction({
    required String userId,
    required String recurringId,
    required RecurringTransactionEntity item,
  }) async {
    final snapshot = await _transactionsCollection(userId)
        .where(
          'recurringTransactionId',
          isEqualTo: recurringId,
        )
        .get();

    if (snapshot.docs.isEmpty) {
      return;
    }

    QueryDocumentSnapshot<Map<String, dynamic>>? latest;
    DateTime? latestDate;

    for (final document in snapshot.docs) {
      final data = document.data();
      final rawDate = data['recurringOccurrenceDate'] ?? data['date'];

      DateTime? date;
      if (rawDate is Timestamp) {
        date = rawDate.toDate();
      } else if (rawDate is DateTime) {
        date = rawDate;
      }

      if (latest == null ||
          (date != null &&
              (latestDate == null || date.isAfter(latestDate!)))) {
        latest = document;
        latestDate = date;
      }
    }

    if (latest == null) {
      return;
    }

    await latest.reference.update({
      'amount': item.amount,
      'type': item.type.name,
      'categoryId': item.categoryId,
      'categoryName': item.categoryName,
      'paymentMethod': item.paymentMethod.name,
      'description': item.description.trim(),
      'walletId': item.walletId,
      'walletName': item.walletName,
    });
  }

  Future<void> delete(String id) async {
    final user = _user;

    await _collection(user.uid).doc(id).delete();
  }

  Future<void> setActive({
    required String id,
    required bool active,
  }) async {
    final user = _user;

    await _collection(user.uid).doc(id).update({
      'active': active,
      'updatedAt': Timestamp.now(),
    });
  }

  Future<int> processDueTransactions({
    AppCurrency? currency,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      return 0;
    }

    final snapshot = await _collection(user.uid)
        .where('active', isEqualTo: true)
        .get();

    var createdCount = 0;
    final now = DateTime.now();

    for (final document in snapshot.docs) {
      try {
        // Process each occurrence in its own Firestore transaction.
        // This makes the transaction + nextDueDate update atomic.
        //
        // A cap prevents an accidentally old daily schedule from
        // generating thousands of transactions in one app launch.
        var catchUpCount = 0;
        const maxCatchUpOccurrences = 24;

        while (catchUpCount < maxCatchUpOccurrences) {
          final result = await _processOneDueOccurrence(
            userId: user.uid,
            recurringId: document.id,
            now: now,
          );

          if (result.created) {
            createdCount++;
          }

          if (result.created &&
              result.type == TransactionType.expense) {
            await _handleBudgetNotification(
              userId: user.uid,
              categoryId: result.categoryId,
              categoryName: result.categoryName,
              transactionDate: result.transactionDate!,
              currency: currency,
            );
          }

          if (!result.created) {
            break;
          }

          catchUpCount++;
        }
      } catch (_) {
        // One broken recurring item must not stop the others.
        continue;
      }
    }

    return createdCount;
  }

  Future<_RecurringOccurrenceResult> _processOneDueOccurrence({
    required String userId,
    required String recurringId,
    required DateTime now,
  }) async {
    final recurringRef = _collection(userId).doc(recurringId);
    final transactionCollection = _transactionsCollection(userId);

    var created = false;
    TransactionType? createdType;
    String createdCategoryId = '';
    String createdCategoryName = '';
    DateTime? createdTransactionDate;

    await _firestore.runTransaction((transaction) async {
      final recurringSnapshot = await transaction.get(recurringRef);

      if (!recurringSnapshot.exists) {
        return;
      }

      final data = recurringSnapshot.data();
      if (data == null || data['active'] != true) {
        return;
      }

      final nextDueRaw = data['nextDueDate'];
      if (nextDueRaw is! Timestamp) {
        return;
      }

      final dueDate = nextDueRaw.toDate();

      if (dueDate.isAfter(now)) {
        return;
      }

      final type = _parseTransactionType(
        data['type']?.toString() ?? 'expense',
      );
      final paymentMethod = _parsePaymentMethod(
        data['paymentMethod']?.toString() ?? 'cash',
      );

      final occurrenceId =
          'recurring_${recurringId}_${_occurrenceKey(dueDate)}';

      final transactionRef = transactionCollection.doc(occurrenceId);
      final existingTransaction =
          await transaction.get(transactionRef);

      final nextDueDate = _nextDueDate(
        current: dueDate,
        frequency: RecurringFrequencyX.fromString(
          data['frequency']?.toString() ?? 'monthly',
        ),
        dayOfMonth: (data['dayOfMonth'] as num?)?.toInt() ?? dueDate.day,
        monthOfYear:
            (data['monthOfYear'] as num?)?.toInt() ?? dueDate.month,
      );

      if (!existingTransaction.exists) {
        createdType = type;
        createdCategoryId = data['categoryId']?.toString() ?? '';
        createdCategoryName = data['categoryName']?.toString() ?? '';
        createdTransactionDate = dueDate;

        transaction.set(transactionRef, {
          'id': occurrenceId,
          'userId': userId,
          'amount': (data['amount'] as num?)?.toDouble() ?? 0.0,
          'type': type.name,
          'categoryId': data['categoryId']?.toString() ?? '',
          'categoryName': data['categoryName']?.toString() ?? '',
          'paymentMethod': paymentMethod.name,
          'description': data['description']?.toString() ?? '',
          'date': Timestamp.fromDate(dueDate),
          'createdAt': Timestamp.now(),
          'walletId': data['walletId']?.toString() ?? '',
          'walletName': data['walletName']?.toString() ?? '',
          'isRecurring': true,
          'recurringTransactionId': recurringId,
          'recurringOccurrenceDate':
              Timestamp.fromDate(dueDate),
        });
      }

      transaction.update(recurringRef, {
        'nextDueDate': Timestamp.fromDate(nextDueDate),
        'lastRunAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
        'lastError': null,
      });

      created = !existingTransaction.exists;
    });

    return _RecurringOccurrenceResult(
      created: created,
      type: createdType,
      categoryId: createdCategoryId,
      categoryName: createdCategoryName,
      transactionDate: createdTransactionDate,
    );
  }

  Future<void> _handleBudgetNotification({
    required String userId,
    required String categoryId,
    required String categoryName,
    required DateTime transactionDate,
    required AppCurrency? currency,
  }) async {
    if (categoryId.isEmpty && categoryName.trim().isEmpty) {
      return;
    }

    try {
      final budgetsSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('budgets')
          .get();

      Map<String, dynamic>? matchingBudget;

      for (final doc in budgetsSnapshot.docs) {
        final data = doc.data();
        final monthRaw = data['month'];
        final month = monthRaw is Timestamp
            ? monthRaw.toDate()
            : monthRaw is DateTime
                ? monthRaw
                : null;

        if (month == null ||
            month.year != transactionDate.year ||
            month.month != transactionDate.month) {
          continue;
        }

        final budgetCategoryId = data['categoryId']?.toString() ?? '';
        final budgetCategoryName =
            data['categoryName']?.toString() ?? '';

        final sameId = categoryId.isNotEmpty &&
            budgetCategoryId.isNotEmpty &&
            categoryId == budgetCategoryId;

        final sameName = categoryName.trim().isNotEmpty &&
            categoryName.trim().toLowerCase() ==
                budgetCategoryName.trim().toLowerCase();

        if (sameId || sameName) {
          matchingBudget = data;
          break;
        }
      }

      if (matchingBudget == null) {
        return;
      }

      final budgetAmount =
          (matchingBudget['amount'] as num?)?.toDouble() ?? 0;

      if (budgetAmount <= 0) {
        return;
      }

      final transactionSnapshot = await _transactionsCollection(userId).get();

      double spent = 0;

      for (final doc in transactionSnapshot.docs) {
        final data = doc.data();
        if (data['type']?.toString() != 'expense') {
          continue;
        }

        final dateRaw = data['date'];
        final date = dateRaw is Timestamp
            ? dateRaw.toDate()
            : dateRaw is DateTime
                ? dateRaw
                : null;

        if (date == null ||
            date.year != transactionDate.year ||
            date.month != transactionDate.month) {
          continue;
        }

        final transactionCategoryId =
            data['categoryId']?.toString() ?? '';
        final transactionCategoryName =
            data['categoryName']?.toString() ?? '';

        final sameId = categoryId.isNotEmpty &&
            transactionCategoryId.isNotEmpty &&
            categoryId == transactionCategoryId;

        final sameName = categoryName.trim().isNotEmpty &&
            categoryName.trim().toLowerCase() ==
                transactionCategoryName.trim().toLowerCase();

        if (sameId || sameName) {
          spent += (data['amount'] as num?)?.toDouble() ?? 0;
        }
      }

      final percentage = spent / budgetAmount;
      final stage = _budgetNotificationStage(percentage);

      if (stage == 0) {
        return;
      }

      final categoryKey = (matchingBudget['categoryId']?.toString() ?? '').isNotEmpty
          ? matchingBudget['categoryId'].toString()
          : (matchingBudget['categoryName']?.toString() ?? '')
              .trim()
              .toLowerCase();

      final monthKey =
          '${transactionDate.year}_${transactionDate.month.toString().padLeft(2, '0')}';

      final amountKey = budgetAmount.toStringAsFixed(2);

      final notificationKey =
          'budget_alert_${userId}_${monthKey}_${categoryKey}_$amountKey';

      final preferences = await SharedPreferences.getInstance();
      final lastStage = preferences.getInt(notificationKey) ?? 0;

      if (stage <= lastStage) {
        return;
      }

      final remaining = budgetAmount - spent;
      final budgetCategoryName =
          matchingBudget['categoryName']?.toString() ?? categoryName;

      final title = stage >= 100
          ? 'Budget exceeded'
          : stage >= 90
              ? '90% of budget reached'
              : '80% of budget reached';

      final formattedRemaining = currency == null
          ? remaining.abs().toStringAsFixed(2)
          : CurrencyFormatter.formatCompact(
              remaining.abs(),
              currency,
            );

      final body = stage >= 100
          ? 'Your $budgetCategoryName spending is ${_formatPercentage(percentage)} of your budget. You are over budget by $formattedRemaining.'
          : 'After the recurring expense, $formattedRemaining will remain in your $budgetCategoryName budget.';

      await LocalNotificationService.ensureInitialized();
      await LocalNotificationService.showBudgetAlert(
        id: DateTime.now().millisecondsSinceEpoch.remainder(2147483647),
        title: title,
        body: body,
      );

      await preferences.setInt(notificationKey, stage);
    } catch (_) {
      // Budget notifications must never block recurring transaction processing.
    }
  }

  static int _budgetNotificationStage(double percentage) {
    if (percentage >= 1.0) return 100;
    if (percentage >= 0.90) return 90;
    if (percentage >= 0.80) return 80;
    return 0;
  }

  static String _formatPercentage(double percentage) {
    return '${(percentage * 100).round()}%';
  }

  RecurringTransactionEntity _fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();

    return RecurringTransactionEntity(
      id: document.id,
      userId: data['userId']?.toString() ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      type: _parseTransactionType(
        data['type']?.toString() ?? 'expense',
      ),
      categoryId: data['categoryId']?.toString() ?? '',
      categoryName: data['categoryName']?.toString() ?? '',
      paymentMethod: _parsePaymentMethod(
        data['paymentMethod']?.toString() ?? 'cash',
      ),
      description: data['description']?.toString() ?? '',
      walletId: data['walletId']?.toString() ?? '',
      walletName: data['walletName']?.toString() ?? '',
      frequency: RecurringFrequencyX.fromString(
        data['frequency']?.toString() ?? 'monthly',
      ),
      nextDueDate: _dateFromFirestore(
        data['nextDueDate'],
      ),
      dayOfMonth:
          (data['dayOfMonth'] as num?)?.toInt() ?? 1,
      monthOfYear:
          (data['monthOfYear'] as num?)?.toInt() ?? 1,
      active: data['active'] == true,
      createdAt: _dateFromFirestore(
        data['createdAt'],
        fallback: DateTime.now(),
      ),
      updatedAt: _dateFromFirestore(
        data['updatedAt'],
        fallback: DateTime.now(),
      ),
      lastRunAt: data['lastRunAt'] is Timestamp
          ? (data['lastRunAt'] as Timestamp).toDate()
          : null,
    );
  }

  static DateTime _dateFromFirestore(
    dynamic value, {
    DateTime? fallback,
  }) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    return fallback ?? DateTime.now();
  }

  static TransactionType _parseTransactionType(String value) {
    return TransactionType.values.firstWhere(
      (item) => item.name == value,
      orElse: () => TransactionType.expense,
    );
  }

  static PaymentMethod _parsePaymentMethod(String value) {
    return PaymentMethod.values.firstWhere(
      (item) => item.name == value,
      orElse: () => PaymentMethod.cash,
    );
  }

  static String _occurrenceKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '${y}${m}${d}';
  }

  static DateTime _nextDueDate({
    required DateTime current,
    required RecurringFrequency frequency,
    required int dayOfMonth,
    required int monthOfYear,
  }) {
    switch (frequency) {
      case RecurringFrequency.daily:
        return DateTime(
          current.year,
          current.month,
          current.day + 1,
          current.hour,
          current.minute,
          current.second,
        );

      case RecurringFrequency.weekly:
        return DateTime(
          current.year,
          current.month,
          current.day + 7,
          current.hour,
          current.minute,
          current.second,
        );

      case RecurringFrequency.monthly:
        final targetYear =
            current.month == 12 ? current.year + 1 : current.year;
        final targetMonth =
            current.month == 12 ? 1 : current.month + 1;
        final maxDay =
            DateTime(targetYear, targetMonth + 1, 0).day;

        return DateTime(
          targetYear,
          targetMonth,
          dayOfMonth.clamp(1, maxDay),
          current.hour,
          current.minute,
          current.second,
        );

      case RecurringFrequency.yearly:
        final targetYear = current.year + 1;
        final maxDay =
            DateTime(targetYear, monthOfYear + 1, 0).day;

        return DateTime(
          targetYear,
          monthOfYear.clamp(1, 12),
          dayOfMonth.clamp(1, maxDay),
          current.hour,
          current.minute,
          current.second,
        );
    }
  }
}

class _RecurringOccurrenceResult {
  final bool created;
  final TransactionType? type;
  final String categoryId;
  final String categoryName;
  final DateTime? transactionDate;

  const _RecurringOccurrenceResult({
    required this.created,
    required this.type,
    required this.categoryId,
    required this.categoryName,
    required this.transactionDate,
  });
}

