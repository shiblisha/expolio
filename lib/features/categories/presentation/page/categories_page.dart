import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/enums/category_type.dart';
import '../../domain/entities/category_entity.dart';
import '../bloc/category_bloc.dart';
import '../bloc/category_event.dart';
import '../bloc/category_state.dart';

class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key});

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  CategoryType get _selectedType {
    return _tabController.index == 0
        ? CategoryType.expense
        : CategoryType.income;
  }

  @override
  void initState() {
    super.initState();

    _tabController = TabController(
      length: 2,
      vsync: this,
    );

    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Categories',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _showCategoryEditor(
            context,
            type: _selectedType,
          );
        },
        backgroundColor: AppColors.navPurple,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Add Category',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: BlocListener<CategoryBloc, CategoryState>(
        listenWhen: (previous, current) {
          return previous.status != current.status;
        },
        listener: (context, state) {
          if (state.status == CategoryStatus.failure &&
              state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage!),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        child: Column(
          children: [
            const SizedBox(height: 8),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Organize your income and expenses',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.textTheme.bodyMedium?.color
                        ?.withValues(alpha: 0.55),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 18),

            // Expense / Income selector
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                height: 58,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkSurface
                      : AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? AppColors.darkBorder
                        : AppColors.lightBorder,
                  ),
                ),
                child:TabBar(
                  controller: _tabController,
                  dividerColor: Colors.transparent,
                  indicator: BoxDecoration(
                    color: _selectedType == CategoryType.expense
                        ? AppColors.expense
                        : AppColors.income,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: Colors.white,
                  unselectedLabelColor:
                  theme.textTheme.bodyMedium?.color?.withValues(
                    alpha: 0.6,
                  ),
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w800,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                  tabs: const [
                    Tab(
                      icon: Icon(
                        Icons.arrow_downward_rounded,
                        size: 18,
                      ),
                      text: 'Expenses',
                    ),
                    Tab(
                      icon: Icon(
                        Icons.arrow_upward_rounded,
                        size: 18,
                      ),
                      text: 'Income',
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 18),

            Expanded(
              child: BlocBuilder<CategoryBloc, CategoryState>(
                builder: (context, state) {
                  if (state.status == CategoryStatus.loading &&
                      state.categories.isEmpty) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  final categories = state.categories
                      .where(
                        (category) => category.type == _selectedType,
                  )
                      .toList();

                  if (categories.isEmpty) {
                    return _EmptyCategories(
                      type: _selectedType,
                      onAdd: () {
                        _showCategoryEditor(
                          context,
                          type: _selectedType,
                        );
                      },
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () async {
                      context.read<CategoryBloc>().add(
                        const LoadCategories(),
                      );

                      await Future.delayed(
                        const Duration(milliseconds: 500),
                      );
                    },
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: const EdgeInsets.fromLTRB(
                        20,
                        0,
                        20,
                        120,
                      ),
                      itemCount: categories.length,
                      separatorBuilder: (_, __) {
                        return const SizedBox(height: 12);
                      },
                      itemBuilder: (context, index) {
                        final category = categories[index];

                        return _CategoryCard(
                          category: category,
                          onEdit: () {
                            _showCategoryEditor(
                              context,
                              category: category,
                            );
                          },
                          onDelete: category.isDefault
                              ? null
                              : () {
                            _confirmDelete(
                              context,
                              category,
                            );
                          },
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCategoryEditor(
      BuildContext context, {
        CategoryEntity? category,
        CategoryType? type,
      }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) {
        return _CategoryEditorSheet(
          category: category,
          initialType: type ?? CategoryType.expense,
        );
      },
    );
  }

  Future<void> _confirmDelete(
      BuildContext context,
      CategoryEntity category,
      ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Delete Category?',
            style: TextStyle(
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            'The app will first check whether "${category.name}" is used by transactions, budgets, or bills. If it is in use, deletion will be blocked.',
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.expense,
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    // The datasource performs the final integrity check before deletion.
    // Success/failure feedback is handled by CategoryBloc's listener.
    context.read<CategoryBloc>().add(
      DeleteCategoryEvent(category.id),
    );
  }
}

// ============================================================
// CATEGORY EDITOR SHEET
// ============================================================

class _CategoryEditorSheet extends StatefulWidget {
  final CategoryEntity? category;
  final CategoryType initialType;

  const _CategoryEditorSheet({
    required this.category,
    required this.initialType,
  });

  @override
  State<_CategoryEditorSheet> createState() =>
      _CategoryEditorSheetState();
}

class _CategoryEditorSheetState extends State<_CategoryEditorSheet> {
  late final TextEditingController _nameController;
  late CategoryType _selectedType;
  late Color _selectedColor;
  late IconData _selectedIcon;

  final _formKey = GlobalKey<FormState>();

  bool get _isEditing => widget.category != null;

  @override
  void initState() {
    super.initState();

    final category = widget.category;

    _nameController = TextEditingController(
      text: category?.name ?? '',
    );

    _selectedType = category?.type ?? widget.initialType;

    _selectedColor = Color(
      category?.colorValue ??
          (_selectedType == CategoryType.expense
              ? AppColors.expense.value
              : AppColors.income.value),
    );

    _selectedIcon = category != null
        ? IconData(
      category.iconCodePoint,
      fontFamily: 'MaterialIcons',
    )
        : (_selectedType == CategoryType.expense
        ? Icons.shopping_bag_rounded
        : Icons.payments_rounded);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(top: 50),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkBackground
            : AppColors.lightBackground,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(30),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 10,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 2),

                  Center(
                    child: Container(
                      width: 42,
                      height: 5,
                      decoration: BoxDecoration(
                        color: theme.dividerColor.withValues(
                          alpha: 0.5,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _isEditing
                              ? 'Edit Category'
                              : 'Add Category',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        icon: const Icon(
                          Icons.close_rounded,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // Preview
                  Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: _selectedColor.withValues(
                          alpha: 0.12,
                        ),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Icon(
                        _selectedIcon,
                        size: 34,
                        color: _selectedColor,
                      ),
                    ),
                  ),

                  const SizedBox(height: 22),

                  Text(
                    'Category Name',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  const SizedBox(height: 8),

                  TextFormField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      hintText: 'e.g. Food, Salary, Travel',
                      prefixIcon: const Icon(
                        Icons.edit_rounded,
                      ),
                      filled: true,
                      fillColor: isDark
                          ? AppColors.darkSurface
                          : AppColors.lightSurface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: isDark
                              ? AppColors.darkBorder
                              : AppColors.lightBorder,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: _selectedType ==
                              CategoryType.expense
                              ? AppColors.expense
                              : AppColors.income,
                          width: 1.5,
                        ),
                      ),
                    ),
                    validator: (value) {
                      final name = value?.trim() ?? '';

                      if (name.isEmpty) {
                        return 'Enter a category name';
                      }

                      if (name.length < 2) {
                        return 'Category name is too short';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 20),

                  Text(
                    'Category Type',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(
                        child: _TypeChoice(
                          title: 'Expense',
                          icon: Icons.arrow_downward_rounded,
                          color: AppColors.expense,
                          selected:
                          _selectedType == CategoryType.expense,
                          onTap: () {
                            setState(() {
                              _selectedType = CategoryType.expense;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _TypeChoice(
                          title: 'Income',
                          icon: Icons.arrow_upward_rounded,
                          color: AppColors.income,
                          selected:
                          _selectedType == CategoryType.income,
                          onTap: () {
                            setState(() {
                              _selectedType = CategoryType.income;
                            });
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 22),

                  Text(
                    'Choose Icon',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  const SizedBox(height: 10),

                  _IconPicker(
                    selectedIcon: _selectedIcon,
                    selectedColor: _selectedColor,
                    onSelected: (icon) {
                      setState(() {
                        _selectedIcon = icon;
                      });
                    },
                  ),

                  const SizedBox(height: 22),

                  Text(
                    'Choose Color',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  const SizedBox(height: 10),

                  _ColorPicker(
                    selectedColor: _selectedColor,
                    onSelected: (color) {
                      setState(() {
                        _selectedColor = color;
                      });
                    },
                  ),

                  const SizedBox(height: 26),

                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _saveCategory,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                        _selectedType == CategoryType.expense
                            ? AppColors.expense
                            : AppColors.income,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: Text(
                        _isEditing
                            ? 'Update Category'
                            : 'Create Category',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _saveCategory() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in first.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final now = DateTime.now();
    final existingCategory = widget.category;

    final category = CategoryEntity(
      id: existingCategory?.id ?? '',
      userId: user.uid,
      name: _nameController.text.trim(),
      type: _selectedType,
      iconCodePoint: _selectedIcon.codePoint,
      colorValue: _selectedColor.value,
      isDefault: existingCategory?.isDefault ?? false,
      createdAt: existingCategory?.createdAt ?? now,
    );

    final bloc = context.read<CategoryBloc>();

    if (_isEditing) {
      bloc.add(
        UpdateCategoryEvent(category),
      );
    } else {
      bloc.add(
        AddCategoryEvent(category),
      );
    }

    Navigator.pop(context);
  }
}

// ============================================================
// CATEGORY CARD
// ============================================================

class _CategoryCard extends StatelessWidget {
  final CategoryEntity category;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;

  const _CategoryCard({
    required this.category,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final categoryColor = Color(category.colorValue);

    final icon = IconData(
      category.iconCodePoint,
      fontFamily: 'MaterialIcons',
    );

    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.darkSurface
              : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isDark
                ? AppColors.darkBorder
                : AppColors.lightBorder,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onEdit,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: categoryColor.withValues(
                      alpha: 0.12,
                    ),
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: Icon(
                    icon,
                    color: categoryColor,
                    size: 26,
                  ),
                ),

                const SizedBox(width: 14),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                        theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),

                      const SizedBox(height: 5),

                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: category.type ==
                                  CategoryType.expense
                                  ? AppColors.expense
                                  : AppColors.income,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            category.type ==
                                CategoryType.expense
                                ? 'Expense'
                                : 'Income',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(
                              color: theme
                                  .textTheme.bodySmall?.color
                                  ?.withValues(alpha: 0.55),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (category.isDefault) ...[
                            const SizedBox(width: 10),
                            Container(
                              padding:
                              const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: categoryColor.withValues(
                                  alpha: 0.10,
                                ),
                                borderRadius:
                                BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Default',
                                style: TextStyle(
                                  color: categoryColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      onEdit();
                    } else if (value == 'delete' &&
                        onDelete != null) {
                      onDelete!();
                    }
                  },
                  itemBuilder: (context) {
                    return [
                      const PopupMenuItem<String>(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(
                              Icons.edit_rounded,
                              size: 20,
                            ),
                            SizedBox(width: 10),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      if (onDelete != null)
                        const PopupMenuItem<String>(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete_outline_rounded,
                                size: 20,
                              ),
                              SizedBox(width: 10),
                              Text('Delete'),
                            ],
                          ),
                        ),
                    ];
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// TYPE CHOICE
// ============================================================

class _TypeChoice extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _TypeChoice({
    required this.title,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.12)
                : isDark
                ? AppColors.darkSurface
                : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? color
                  : isDark
                  ? AppColors.darkBorder
                  : AppColors.lightBorder,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: selected
                    ? color
                    : theme.iconTheme.color?.withValues(
                  alpha: 0.6,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: selected ? color : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// ICON PICKER
// ============================================================

class _IconPicker extends StatelessWidget {
  final IconData selectedIcon;
  final Color selectedColor;
  final ValueChanged<IconData> onSelected;

  const _IconPicker({
    required this.selectedIcon,
    required this.selectedColor,
    required this.onSelected,
  });

  static const List<IconData> _icons = [
    Icons.restaurant_rounded,
    Icons.shopping_bag_rounded,
    Icons.shopping_cart_rounded,
    Icons.local_grocery_store_rounded,
    Icons.directions_car_rounded,
    Icons.local_taxi_rounded,
    Icons.flight_rounded,
    Icons.home_rounded,
    Icons.house_rounded,
    Icons.receipt_long_rounded,
    Icons.lightbulb_rounded,
    Icons.water_drop_rounded,
    Icons.wifi_rounded,
    Icons.phone_android_rounded,
    Icons.school_rounded,
    Icons.medical_services_rounded,
    Icons.fitness_center_rounded,
    Icons.sports_soccer_rounded,
    Icons.movie_rounded,
    Icons.music_note_rounded,
    Icons.coffee_rounded,
    Icons.fastfood_rounded,
    Icons.pets_rounded,
    Icons.work_rounded,
    Icons.business_center_rounded,
    Icons.account_balance_rounded,
    Icons.account_balance_wallet_rounded,
    Icons.payments_rounded,
    Icons.money_rounded,
    Icons.savings_rounded,
    Icons.card_giftcard_rounded,
    Icons.wallet_rounded,
    Icons.category_rounded,
    Icons.more_horiz_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurface
            : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? AppColors.darkBorder
              : AppColors.lightBorder,
        ),
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _icons.length,
        gridDelegate:
        const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7,
          mainAxisSpacing: 10,
          crossAxisSpacing: 8,
          childAspectRatio: 1,
        ),
        itemBuilder: (context, index) {
          final icon = _icons[index];

          final isSelected =
              icon.codePoint == selectedIcon.codePoint;

          return InkWell(
            onTap: () => onSelected(icon),
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              decoration: BoxDecoration(
                color: isSelected
                    ? selectedColor.withValues(alpha: 0.13)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: isSelected
                    ? Border.all(
                  color: selectedColor,
                  width: 1.5,
                )
                    : null,
              ),
              child: Icon(
                icon,
                size: 22,
                color: isSelected
                    ? selectedColor
                    : theme.iconTheme.color?.withValues(
                  alpha: 0.65,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ============================================================
// COLOR PICKER
// ============================================================

class _ColorPicker extends StatelessWidget {
  final Color selectedColor;
  final ValueChanged<Color> onSelected;

  const _ColorPicker({
    required this.selectedColor,
    required this.onSelected,
  });

  static const List<Color> _colors = [
    Color(0xFF2F7E79),
    Color(0xFF1B5C58),
    Color(0xFF25A969),
    Color(0xFFF95B51),
    Color(0xFF6B3DF5),
    Color(0xFF3F6BFF),
    Color(0xFFFF9F43),
    Color(0xFFF2C94C),
    Color(0xFFE74C3C),
    Color(0xFF9B59B6),
    Color(0xFF3498DB),
    Color(0xFF1ABC9C),
    Color(0xFF16A085),
    Color(0xFF27AE60),
    Color(0xFF2980B9),
    Color(0xFF8E44AD),
    Color(0xFFD35400),
    Color(0xFFC0392B),
    Color(0xFF34495E),
    Color(0xFF607D8B),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurface
            : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? AppColors.darkBorder
              : AppColors.lightBorder,
        ),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: _colors.map((color) {
          final selected =
              color.toARGB32() == selectedColor.toARGB32();

          return GestureDetector(
            onTap: () => onSelected(color),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: selected
                    ? Border.all(
                  color: theme.colorScheme.onSurface,
                  width: 3,
                )
                    : null,
              ),
              child: selected
                  ? const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 20,
              )
                  : null,
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ============================================================
// EMPTY STATE
// ============================================================

class _EmptyCategories extends StatelessWidget {
  final CategoryType type;
  final VoidCallback onAdd;

  const _EmptyCategories({
    required this.type,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final isExpense = type == CategoryType.expense;
    final color =
    isExpense ? AppColors.expense : AppColors.income;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isExpense
                    ? Icons.receipt_long_rounded
                    : Icons.payments_rounded,
                color: color,
                size: 40,
              ),
            ),

            const SizedBox(height: 22),

            Text(
              isExpense
                  ? 'No expense categories'
                  : 'No income categories',
              textAlign: TextAlign.center,
              style:
              theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              isExpense
                  ? 'Create categories like Food, Travel or Shopping to organize your expenses.'
                  : 'Create categories like Salary, Freelance or Business to organize your income.',
              textAlign: TextAlign.center,
              style:
              theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodyMedium?.color
                    ?.withValues(alpha: 0.55),
              ),
            ),

            const SizedBox(height: 24),

            ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'Create Category',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}