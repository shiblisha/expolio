import 'package:flutter/material.dart';

import '../../../core/enums/category_type.dart';
import 'entities/category_entity.dart';

class DefaultCategories {
  DefaultCategories._();

  static List<CategoryEntity> forUser(String userId) {
    final now = DateTime.now();

    return [
      // ==========================================================
      // EXPENSE CATEGORIES
      // ==========================================================

      CategoryEntity(
        id: 'default_expense_food',
        userId: userId,
        name: 'Food',
        type: CategoryType.expense,
        iconCodePoint: Icons.restaurant_rounded.codePoint,
        colorValue: const Color(0xFFFF7043).value,
        isDefault: true,
        createdAt: now,
      ),

      CategoryEntity(
        id: 'default_expense_shopping',
        userId: userId,
        name: 'Shopping',
        type: CategoryType.expense,
        iconCodePoint: Icons.shopping_bag_rounded.codePoint,
        colorValue: const Color(0xFF6B3DF5).value,
        isDefault: true,
        createdAt: now,
      ),

      CategoryEntity(
        id: 'default_expense_transport',
        userId: userId,
        name: 'Transport',
        type: CategoryType.expense,
        iconCodePoint: Icons.directions_car_rounded.codePoint,
        colorValue: const Color(0xFF3F6BFF).value,
        isDefault: true,
        createdAt: now,
      ),

      CategoryEntity(
        id: 'default_expense_bills',
        userId: userId,
        name: 'Bills',
        type: CategoryType.expense,
        iconCodePoint: Icons.receipt_long_rounded.codePoint,
        colorValue: const Color(0xFFE74C3C).value,
        isDefault: true,
        createdAt: now,
      ),

      CategoryEntity(
        id: 'default_expense_health',
        userId: userId,
        name: 'Health',
        type: CategoryType.expense,
        iconCodePoint: Icons.medical_services_rounded.codePoint,
        colorValue: const Color(0xFF25A969).value,
        isDefault: true,
        createdAt: now,
      ),

      CategoryEntity(
        id: 'default_expense_entertainment',
        userId: userId,
        name: 'Entertainment',
        type: CategoryType.expense,
        iconCodePoint: Icons.movie_rounded.codePoint,
        colorValue: const Color(0xFF9B59B6).value,
        isDefault: true,
        createdAt: now,
      ),

      CategoryEntity(
        id: 'default_expense_education',
        userId: userId,
        name: 'Education',
        type: CategoryType.expense,
        iconCodePoint: Icons.school_rounded.codePoint,
        colorValue: const Color(0xFF3498DB).value,
        isDefault: true,
        createdAt: now,
      ),

      CategoryEntity(
        id: 'default_expense_home',
        userId: userId,
        name: 'Home',
        type: CategoryType.expense,
        iconCodePoint: Icons.home_rounded.codePoint,
        colorValue: const Color(0xFF607D8B).value,
        isDefault: true,
        createdAt: now,
      ),

      // ==========================================================
      // INCOME CATEGORIES
      // ==========================================================

      CategoryEntity(
        id: 'default_income_salary',
        userId: userId,
        name: 'Salary',
        type: CategoryType.income,
        iconCodePoint: Icons.account_balance_wallet_rounded.codePoint,
        colorValue: const Color(0xFF25A969).value,
        isDefault: true,
        createdAt: now,
      ),

      CategoryEntity(
        id: 'default_income_freelance',
        userId: userId,
        name: 'Freelance',
        type: CategoryType.income,
        iconCodePoint: Icons.work_rounded.codePoint,
        colorValue: const Color(0xFF3F6BFF).value,
        isDefault: true,
        createdAt: now,
      ),

      CategoryEntity(
        id: 'default_income_business',
        userId: userId,
        name: 'Business',
        type: CategoryType.income,
        iconCodePoint: Icons.business_center_rounded.codePoint,
        colorValue: const Color(0xFF6B3DF5).value,
        isDefault: true,
        createdAt: now,
      ),

      CategoryEntity(
        id: 'default_income_investment',
        userId: userId,
        name: 'Investment',
        type: CategoryType.income,
        iconCodePoint: Icons.trending_up_rounded.codePoint,
        colorValue: const Color(0xFF2F7E79).value,
        isDefault: true,
        createdAt: now,
      ),
    ];
  }
}