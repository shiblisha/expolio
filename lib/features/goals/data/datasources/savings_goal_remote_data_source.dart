import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

import '../models/savings_goal_model.dart';

class SavingsGoalRemoteDataSource {
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;
  final Uuid _uuid;

  SavingsGoalRemoteDataSource({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    Uuid? uuid,
  })  : firestore = firestore ?? FirebaseFirestore.instance,
        auth = auth ?? FirebaseAuth.instance,
        _uuid = uuid ?? const Uuid();

  // ============================================================
  // SAVINGS GOALS COLLECTION
  // ============================================================

  CollectionReference<Map<String, dynamic>> get _collection =>
      firestore.collection('savings_goals');

  // ============================================================
  // CURRENT USER
  // ============================================================

  User get _user {
    final user = auth.currentUser;

    if (user == null) {
      throw StateError('User is not authenticated');
    }

    return user;
  }

  // ============================================================
  // TRANSACTIONS COLLECTION
  // ============================================================

  CollectionReference<Map<String, dynamic>> _transactionsCollection(
      String userId,
      ) {
    return firestore
        .collection('users')
        .doc(userId)
        .collection('transactions');
  }

  // ============================================================
  // LINKED TRANSACTION REFERENCE
  // ============================================================

  DocumentReference<Map<String, dynamic>> _transactionRef({
    required String userId,
    required String contributionId,
  }) {
    return _transactionsCollection(userId).doc(
      'goal_contribution_$contributionId',
    );
  }

  // ============================================================
  // GET GOALS
  // ============================================================

  Future<List<SavingsGoalModel>> getGoals() async {
    final user = _user;

    final snapshot = await _collection
        .where(
      'userId',
      isEqualTo: user.uid,
    )
        .get();

    final goals = snapshot.docs
        .map(
      SavingsGoalModel.fromFirestore,
    )
        .toList();

    goals.sort((a, b) {
      final statusOrder =
      _statusRank(a).compareTo(_statusRank(b));

      if (statusOrder != 0) {
        return statusOrder;
      }

      final targetOrder =
      a.targetDate.compareTo(b.targetDate);

      if (targetOrder != 0) {
        return targetOrder;
      }

      return a.name
          .toLowerCase()
          .compareTo(
        b.name.toLowerCase(),
      );
    });

    return goals;
  }

  // ============================================================
  // ADD GOAL
  // ============================================================

  Future<void> addGoal(
      SavingsGoalModel goal,
      ) async {
    final user = _user;

    final doc = goal.id.isNotEmpty
        ? _collection.doc(goal.id)
        : _collection.doc();

    if (goal.userId != user.uid) {
      throw StateError(
        'You cannot create a goal for another account',
      );
    }

    final model = SavingsGoalModel(
      id: doc.id,
      userId: user.uid,
      name: goal.name,
      targetAmount: goal.targetAmount,
      currentAmount: goal.currentAmount,
      targetDate: goal.targetDate,
      description: goal.description,
      iconCodePoint: goal.iconCodePoint,
      colorValue: goal.colorValue,
      createdAt: goal.createdAt,
      updatedAt: DateTime.now(),
      contributions: goal.contributions,
    );

    await doc.set(
      model.toMap(),
    );
  }

  // ============================================================
  // UPDATE GOAL
  // ============================================================

  Future<void> updateGoal(
      SavingsGoalModel goal,
      ) async {
    final user = _user;

    final ref = _collection.doc(goal.id);

    final snapshot = await ref.get();

    if (!snapshot.exists ||
        snapshot.data()?['userId'] != user.uid) {
      throw StateError(
        'Savings goal not found',
      );
    }

    final existing =
    SavingsGoalModel.fromFirestore(
      snapshot,
    );

    final existingContributions =
    snapshot.data()?['contributions'];

    await ref.update({
      'name': goal.name,
      'targetAmount': goal.targetAmount,
      'targetDate': Timestamp.fromDate(
        goal.targetDate,
      ),
      'description': goal.description,
      'iconCodePoint': goal.iconCodePoint,
      'colorValue': goal.colorValue,
      'updatedAt': Timestamp.now(),

      // IMPORTANT:
      // Server-side contribution data is preserved.
      'currentAmount':
      existing.currentAmount,

      'contributions':
      existingContributions is List
          ? existingContributions
          .whereType<Map>()
          .map(
            (item) =>
        Map<String, dynamic>.from(
          item,
        ),
      )
          .toList()
          : const [],
    });
  }

  // ============================================================
  // DELETE GOAL + LINKED TRANSACTIONS ATOMICALLY
  // ============================================================

  Future<void> deleteGoal(
      String goalId,
      ) async {
    final user = _user;

    final goalRef =
    _collection.doc(goalId);

    await firestore.runTransaction(
          (transaction) async {
        final snapshot =
        await transaction.get(goalRef);

        final data = snapshot.data();

        if (!snapshot.exists ||
            data == null) {
          return;
        }

        if (data['userId'] != user.uid) {
          throw StateError(
            'You cannot delete another user\'s goal',
          );
        }

        final raw =
        data['contributions'];

        if (raw is List) {
          for (final item in raw) {
            if (item is! Map) {
              continue;
            }

            final contributionId =
                item['id']?.toString() ?? '';

            if (contributionId.isEmpty) {
              continue;
            }

            transaction.delete(
              _transactionRef(
                userId: user.uid,
                contributionId:
                contributionId,
              ),
            );
          }
        }

        transaction.delete(
          goalRef,
        );
      },
    );
  }

  // ============================================================
  // ADD CONTRIBUTION
  //
  // GOAL UPDATE + TRANSACTION CREATION
  // HAPPEN IN ONE FIRESTORE TRANSACTION.
  // ============================================================

  Future<void> addContribution({
    required String goalId,
    required double amount,
    required String walletId,
    String note = '',
  }) async {
    if (amount <= 0) {
      throw StateError(
        'Contribution amount must be greater than zero',
      );
    }

    final user = _user;

    final goalRef =
    _collection.doc(goalId);

    final walletRef = firestore
        .collection('users')
        .doc(user.uid)
        .collection('wallets')
        .doc(walletId);

    // One unique ID is shared by:
    //
    // contribution
    // linked transaction
    //
    // This makes them directly traceable.
    final contributionId =
    _uuid.v4();

    final linkedTransactionRef =
    _transactionRef(
      userId: user.uid,
      contributionId:
      contributionId,
    );

    // ==========================================================
    // ATOMIC OPERATION
    // ==========================================================

    await firestore.runTransaction(
          (transaction) async {
        // ------------------------------------------------------
        // READ GOAL
        // ------------------------------------------------------

        final goalSnapshot =
        await transaction.get(
          goalRef,
        );

        // ------------------------------------------------------
        // READ WALLET
        // ------------------------------------------------------

        final walletSnapshot =
        await transaction.get(
          walletRef,
        );

        final goalData =
        goalSnapshot.data();

        final walletData =
        walletSnapshot.data();

        // ------------------------------------------------------
        // VALIDATE GOAL
        // ------------------------------------------------------

        if (!goalSnapshot.exists ||
            goalData == null ||
            goalData['userId'] !=
                user.uid) {
          throw StateError(
            'Savings goal not found',
          );
        }

        // ------------------------------------------------------
        // VALIDATE WALLET
        // ------------------------------------------------------

        if (!walletSnapshot.exists ||
            walletData == null ||
            walletData['userId'] !=
                user.uid) {
          throw StateError(
            'Selected wallet not found',
          );
        }

        // ------------------------------------------------------
        // CURRENT GOAL AMOUNT
        // ------------------------------------------------------

        final current =
            (goalData['currentAmount']
            as num?)
                ?.toDouble() ??
                0.0;

        // ------------------------------------------------------
        // TARGET AMOUNT
        // ------------------------------------------------------

        final target =
        (goalData['targetAmount']
        as num?)
            ?.toDouble();

        final nextAmount =
            current + amount;

        // ------------------------------------------------------
        // DON'T ALLOW OVERFUNDING
        // ------------------------------------------------------

        if (target != null &&
            nextAmount > target) {
          throw StateError(
            'Amount exceeds the remaining goal amount',
          );
        }

        // ------------------------------------------------------
        // EXISTING CONTRIBUTIONS
        // ------------------------------------------------------

        final raw =
        goalData['contributions'];

        final contributions =
        <Map<String, dynamic>>[];

        if (raw is List) {
          for (final item in raw) {
            if (item is Map) {
              contributions.add(
                Map<String, dynamic>.from(
                  item,
                ),
              );
            }
          }
        }

        // ------------------------------------------------------
        // BASIC DATA
        // ------------------------------------------------------

        final now =
        Timestamp.now();

        final cleanNote =
        note.trim();

        final goalName =
            goalData['name']
                ?.toString() ??
                'Savings Goal';

        final walletName =
            walletData['name']
                ?.toString() ??
                'Wallet';

        final walletType =
            walletData['type']
                ?.toString()
                .toLowerCase() ??
                '';

        // ------------------------------------------------------
        // ADD CONTRIBUTION
        // ------------------------------------------------------

        contributions.add({
          'id': contributionId,
          'amount': amount,
          'date': now,
          'note': cleanNote,

          // WALLET CONNECTION
          'walletId': walletId,
          'walletName': walletName,
        });

        // ======================================================
        // CREATE LINKED TRANSACTION
        // ======================================================
        //
        // IMPORTANT:
        //
        // This is TRANSFER, NOT EXPENSE.
        //
        // The wallet page already handles:
        //
        // fromWalletId -> balance - amount
        //
        // Therefore the selected wallet will decrease
        // automatically after this transaction is created.
        //
        // ======================================================

        transaction.set(
          linkedTransactionRef,
          {
            'id': linkedTransactionRef.id,

            'userId': user.uid,

            'amount': amount,

            // IMPORTANT
            'type': 'transfer',

            'categoryId':
            'savings_goal',

            'categoryName':
            'Savings Goal',

            'paymentMethod':
            _paymentMethodFromWalletType(
              walletType,
            ),

            'description':
            cleanNote.isEmpty
                ? 'Goal: $goalName'
                : cleanNote,

            'date': now,

            'createdAt': now,

            // ==================================================
            // SOURCE WALLET
            // ==================================================

            'fromWalletId':
            walletId,

            'fromWalletName':
            walletName,

            // ==================================================
            // NO DESTINATION WALLET
            // ==================================================
            //
            // The destination is the savings goal.
            //
            'toWalletId': null,
            'toWalletName': null,

            // ==================================================
            // GOAL LINK
            // ==================================================

            'isGoalContribution':
            true,

            'goalId':
            goalId,

            'goalName':
            goalName,

            'goalContributionId':
            contributionId,
          },
        );

        // ======================================================
        // UPDATE GOAL
        // ======================================================

        transaction.update(
          goalRef,
          {
            'currentAmount':
            nextAmount,

            'contributions':
            contributions,

            'updatedAt':
            now,
          },
        );
      },
    );
  }

  // ============================================================
  // REMOVE CONTRIBUTION
  //
  // GOAL UPDATE + LINKED TRANSACTION DELETE
  // ARE ATOMIC.
  // ============================================================

  Future<void> removeContribution({
    required String goalId,
    required String contributionId,
  }) async {
    final user = _user;

    final goalRef =
    _collection.doc(goalId);

    final linkedTransactionRef =
    _transactionRef(
      userId: user.uid,
      contributionId:
      contributionId,
    );

    await firestore.runTransaction(
          (transaction) async {
        // ------------------------------------------------------
        // READ GOAL
        // ------------------------------------------------------

        final goalSnapshot =
        await transaction.get(
          goalRef,
        );

        final data =
        goalSnapshot.data();

        if (!goalSnapshot.exists ||
            data == null ||
            data['userId'] !=
                user.uid) {
          throw StateError(
            'Savings goal not found',
          );
        }

        // ------------------------------------------------------
        // FIND CONTRIBUTION
        // ------------------------------------------------------

        final raw =
        data['contributions'];

        final kept =
        <Map<String, dynamic>>[];

        double removedAmount = 0.0;

        if (raw is List) {
          for (final item in raw) {
            if (item is! Map) {
              continue;
            }

            final map =
            Map<String, dynamic>.from(
              item,
            );

            final id =
                map['id']?.toString() ??
                    '';

            if (id ==
                contributionId) {
              removedAmount =
                  (map['amount'] as num?)
                      ?.toDouble() ??
                      0.0;
            } else {
              kept.add(map);
            }
          }
        }

        // ------------------------------------------------------
        // VALIDATE CONTRIBUTION
        // ------------------------------------------------------

        if (removedAmount <= 0) {
          throw StateError(
            'Contribution not found',
          );
        }

        // ------------------------------------------------------
        // CURRENT GOAL AMOUNT
        // ------------------------------------------------------

        final current =
            (data['currentAmount']
            as num?)
                ?.toDouble() ??
                0.0;

        final nextAmount =
        (current - removedAmount)
            .clamp(
          0.0,
          double.infinity,
        )
            .toDouble();

        // ======================================================
        // DELETE LINKED TRANSACTION
        // ======================================================
        //
        // Because wallet balance is derived from transactions,
        // deleting this transfer restores the wallet balance.
        //
        // ======================================================

        transaction.delete(
          linkedTransactionRef,
        );

        // ======================================================
        // UPDATE GOAL
        // ======================================================

        transaction.update(
          goalRef,
          {
            'currentAmount':
            nextAmount,

            'contributions':
            kept,

            'updatedAt':
            Timestamp.now(),
          },
        );
      },
    );
  }

  // ============================================================
  // PAYMENT METHOD FROM WALLET TYPE
  // ============================================================

  String _paymentMethodFromWalletType(
      String walletType,
      ) {
    switch (walletType) {
      case 'cash':
        return 'cash';

      case 'card':
        return 'card';

      case 'upi':
        return 'upi';

      case 'bank':
        return 'bank';

      default:
        return 'bank';
    }
  }

  // ============================================================
  // GOAL STATUS SORT
  // ============================================================

  int _statusRank(
      SavingsGoalModel goal,
      ) {
    if (goal.isCompleted) {
      return 0;
    }

    if (goal.isOverdue) {
      return 2;
    }

    return 1;
  }
}