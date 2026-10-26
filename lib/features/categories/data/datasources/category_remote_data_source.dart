import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/category_model.dart';

abstract class CategoryRemoteDataSource {
  Future<List<CategoryModel>> getCategories();

  Stream<List<CategoryModel>> watchCategories();

  Future<void> addCategory(
      CategoryModel category,
      );

  Future<void> updateCategory(
      CategoryModel category,
      );

  Future<void> deleteCategory(
      String categoryId,
      );
}

class CategoryRemoteDataSourceImpl
    implements CategoryRemoteDataSource {
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;

  CategoryRemoteDataSourceImpl({
    required this.firestore,
    required this.auth,
  });

  CollectionReference<Map<String, dynamic>> get _categoriesRef {
    final user = auth.currentUser;

    if (user == null) {
      throw Exception(
        'User is not authenticated',
      );
    }

    return firestore
        .collection('users')
        .doc(user.uid)
        .collection('categories');
  }

  CollectionReference<Map<String, dynamic>> _userCollection(
      String collection,
      ) {
    final user = auth.currentUser;

    if (user == null) {
      throw Exception(
        'User is not authenticated',
      );
    }

    return firestore
        .collection('users')
        .doc(user.uid)
        .collection(collection);
  }

  @override
  Future<List<CategoryModel>> getCategories() async {
    final snapshot = await _categoriesRef
        .orderBy('name')
        .get();

    return snapshot.docs
        .map(
          (doc) => CategoryModel.fromFirestore(doc),
    )
        .toList();
  }

  @override
  Stream<List<CategoryModel>> watchCategories() {
    return _categoriesRef
        .orderBy('name')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
          .map(
            (doc) => CategoryModel.fromFirestore(doc),
      )
          .toList(),
    );
  }

  @override
  Future<void> addCategory(
      CategoryModel category,
      ) async {
    await _categoriesRef.add(
      category.toFirestore(),
    );
  }

  @override
  Future<void> updateCategory(
      CategoryModel category,
      ) async {
    if (category.id.isEmpty) {
      throw Exception(
        'Category ID is required for update',
      );
    }

    await _categoriesRef
        .doc(category.id)
        .update(
      category.toFirestore(),
    );
  }

  @override
  Future<void> deleteCategory(
      String categoryId,
      ) async {
    if (categoryId.isEmpty) {
      throw Exception(
        'Category ID is required',
      );
    }

    final categoryRef = _categoriesRef.doc(categoryId);
    final categorySnapshot = await categoryRef.get();

    if (!categorySnapshot.exists) {
      throw Exception(
        'Category not found',
      );
    }

    final categoryData = categorySnapshot.data();
    final categoryName =
    (categoryData?['name'] as String? ?? '').trim();
    final isDefault = categoryData?['isDefault'] == true;

    // Default categories are protected at the data layer too.
    // This prevents accidental deletion even if another screen calls the
    // datasource directly.
    if (isDefault) {
      throw Exception(
        'Default categories cannot be deleted',
      );
    }

    final usage = await _getCategoryUsage(
      categoryId: categoryId,
      categoryName: categoryName,
    );

    if (usage.total > 0) {
      final parts = <String>[];

      if (usage.transactions > 0) {
        parts.add(
          '${usage.transactions} transaction${usage.transactions == 1 ? '' : 's'}',
        );
      }

      if (usage.budgets > 0) {
        parts.add(
          '${usage.budgets} budget${usage.budgets == 1 ? '' : 's'}',
        );
      }

      if (usage.bills > 0) {
        parts.add(
          '${usage.bills} bill${usage.bills == 1 ? '' : 's'}',
        );
      }

      throw Exception(
        'Cannot delete \"$categoryName\" because it is used by ${parts.join(', ')}. Keeping it protects your existing financial history.',
      );
    }

    await categoryRef.delete();
  }

  Future<_CategoryUsage> _getCategoryUsage({
    required String categoryId,
    required String categoryName,
  }) async {
    final transactionIds = <String>{};
    final budgetIds = <String>{};
    final billIds = <String>{};

    Future<void> collectIds({
      required String collection,
      required Set<String> target,
      required String field,
      required String value,
    }) async {
      if (value.isEmpty) {
        return;
      }

      final snapshot = await _userCollection(collection)
          .where(field, isEqualTo: value)
          .get();

      for (final doc in snapshot.docs) {
        target.add(doc.id);
      }
    }

    // Match the real category ID first.
    await collectIds(
      collection: 'transactions',
      target: transactionIds,
      field: 'categoryId',
      value: categoryId,
    );

    await collectIds(
      collection: 'budgets',
      target: budgetIds,
      field: 'categoryId',
      value: categoryId,
    );

    await collectIds(
      collection: 'bills',
      target: billIds,
      field: 'categoryId',
      value: categoryId,
    );

    // Name fallback keeps older records safe when they were created before
    // categoryId was stored consistently. Sets prevent double counting.
    if (categoryName.isNotEmpty) {
      await collectIds(
        collection: 'transactions',
        target: transactionIds,
        field: 'categoryName',
        value: categoryName,
      );

      await collectIds(
        collection: 'budgets',
        target: budgetIds,
        field: 'categoryName',
        value: categoryName,
      );

      await collectIds(
        collection: 'bills',
        target: billIds,
        field: 'categoryName',
        value: categoryName,
      );
    }

    return _CategoryUsage(
      transactions: transactionIds.length,
      budgets: budgetIds.length,
      bills: billIds.length,
    );
  }
}

class _CategoryUsage {
  final int transactions;
  final int budgets;
  final int bills;

  const _CategoryUsage({
    required this.transactions,
    required this.budgets,
    required this.bills,
  });

  int get total => transactions + budgets + bills;
}
