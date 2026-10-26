import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/budget_model.dart';

abstract class BudgetRemoteDataSource {
  Future<List<BudgetModel>> getBudgets();

  Stream<List<BudgetModel>> watchBudgets();

  Future<void> addBudget(BudgetModel budget);

  Future<void> updateBudget(BudgetModel budget);

  Future<void> deleteBudget(String budgetId);
}

class BudgetRemoteDataSourceImpl implements BudgetRemoteDataSource {
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;

  BudgetRemoteDataSourceImpl({
    required this.firestore,
    required this.auth,
  });

  CollectionReference<Map<String, dynamic>> get _budgetsRef {
    final user = auth.currentUser;

    if (user == null) {
      throw Exception('User is not authenticated');
    }

    return firestore
        .collection('users')
        .doc(user.uid)
        .collection('budgets');
  }

  @override
  Future<List<BudgetModel>> getBudgets() async {
    final snapshot = await _budgetsRef
        .orderBy('month', descending: true)
        .get();

    return snapshot.docs
        .map(
          (doc) => BudgetModel.fromFirestore(doc),
    )
        .toList();
  }

  @override
  Stream<List<BudgetModel>> watchBudgets() {
    return _budgetsRef
        .orderBy('month', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
          .map(
            (doc) => BudgetModel.fromFirestore(doc),
      )
          .toList(),
    );
  }

  @override
  Future<void> addBudget(BudgetModel budget) async {
    await _budgetsRef.add(
      budget.toFirestore(),
    );
  }

  @override
  Future<void> updateBudget(BudgetModel budget) async {
    if (budget.id.isEmpty) {
      throw Exception('Budget ID is required for update');
    }

    await _budgetsRef.doc(budget.id).update(
      budget.toFirestore(),
    );
  }

  @override
  Future<void> deleteBudget(String budgetId) async {
    if (budgetId.isEmpty) {
      throw Exception('Budget ID is required');
    }

    await _budgetsRef.doc(budgetId).delete();
  }
}