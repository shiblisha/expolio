import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../core/theme/theme_settings.dart';

import '../core/currency/currency_cubit.dart';

// ============================================================
// CATEGORIES
// ============================================================

import '../features/categories/data/datasources/category_remote_data_source.dart';
import '../features/categories/data/repositories/category_repository_impl.dart';
import '../features/categories/domain/usecases/add_category.dart';
import '../features/categories/domain/usecases/delete_category.dart';
import '../features/categories/domain/usecases/get_categories.dart';
import '../features/categories/domain/usecases/seed_default_categories.dart';
import '../features/categories/domain/usecases/update_category.dart';
import '../features/categories/presentation/bloc/category_bloc.dart';
import '../features/categories/presentation/bloc/category_event.dart';

// ============================================================
// SAVINGS GOALS
// ============================================================

import '../features/goals/data/datasources/savings_goal_remote_data_source.dart';
import '../features/goals/data/repositories/savings_goal_repository_impl.dart';
import '../features/goals/domain/usecases/add_goal_contribution.dart';
import '../features/goals/domain/usecases/add_savings_goal.dart';
import '../features/goals/domain/usecases/delete_savings_goal.dart';
import '../features/goals/domain/usecases/get_savings_goals.dart';
import '../features/goals/domain/usecases/remove_goal_contribution.dart';
import '../features/goals/domain/usecases/update_savings_goal.dart';
import '../features/goals/presentation/bloc/savings_goal_bloc.dart';
import '../features/goals/presentation/bloc/savings_goal_event.dart';

// ============================================================
// BUDGET
// ============================================================

import '../features/budget/data/datasources/budget_remote_datasource.dart';
import '../features/budget/data/repositories/budget_repository_impl.dart';
import '../features/budget/domain/usecases/add_budget.dart';
import '../features/budget/domain/usecases/delete_budget.dart';
import '../features/budget/domain/usecases/get_budgets.dart';
import '../features/budget/domain/usecases/update_budget.dart';
import '../features/budget/presentation/bloc/budget_bloc.dart';
import '../features/budget/presentation/bloc/budget_event.dart';

// ============================================================
// BILLS
// ============================================================

import '../features/bills/data/datasources/bill_remote_data_source.dart';
import '../features/bills/data/repositories/bill_repository_impl.dart';
import '../features/bills/domain/usecases/add_bill.dart';
import '../features/bills/domain/usecases/delete_bill.dart';
import '../features/bills/domain/usecases/get_bills.dart';
import '../features/bills/domain/usecases/mark_bill_paid.dart';
import '../features/bills/domain/usecases/update_bill.dart';
import '../features/bills/presentation/bloc/bill_bloc.dart';
import '../features/bills/presentation/bloc/bill_event.dart';

// ============================================================
// DASHBOARD
// ============================================================

import '../features/dashboard/presentation/pages/main_shell.dart';
import '../features/auth/presentation/pages/auth_gate.dart';

// ============================================================
// TRANSACTIONS
// ============================================================

import '../features/transactions/data/datasources/transaction_remote_datasource.dart';
import '../features/transactions/data/repositories/transaction_repository_impl.dart';
import '../features/transactions/presentation/bloc/transaction_bloc.dart';
import '../features/transactions/presentation/bloc/transaction_event.dart';

// ============================================================
// WALLET
// ============================================================

import '../features/wallet/data/datasources/wallet_remote_datasource.dart';
import '../features/wallet/data/repositories/wallet_repository_impl.dart';
import '../features/wallet/presentation/bloc/wallet_bloc.dart';
import '../features/wallet/presentation/bloc/wallet_event.dart';

import 'theme/dark_theme.dart';
import 'theme/light_theme.dart';

class IncomeExpenseApp extends StatefulWidget {
  const IncomeExpenseApp({
    super.key,
  });

  @override
  State<IncomeExpenseApp> createState() =>
      _IncomeExpenseAppState();
}

class _IncomeExpenseAppState
    extends State<IncomeExpenseApp> {
  ThemeMode get _themeMode => ThemeSettings.instance.mode;

  // ==========================================================
  // REPOSITORIES
  // ==========================================================

  late final TransactionRepositoryImpl
  _transactionRepository;

  late final BudgetRepositoryImpl
  _budgetRepository;

  late final WalletRepositoryImpl
  _walletRepository;

  late final BillRepositoryImpl
  _billRepository;

  late final CategoryRepositoryImpl
  _categoryRepository;

  late final SavingsGoalRepositoryImpl
  _savingsGoalRepository;

  // ==========================================================
  // INIT
  // ==========================================================

  @override
  void initState() {
    super.initState();
    ThemeSettings.instance.load();

    final firestore =
        FirebaseFirestore.instance;

    final auth =
        FirebaseAuth.instance;

    // ========================================================
    // TRANSACTIONS
    // ========================================================

    final transactionDataSource =
    TransactionRemoteDataSourceImpl(
      firestore: firestore,
      auth: auth,
    );

    _transactionRepository =
        TransactionRepositoryImpl(
          remoteDataSource:
          transactionDataSource,
        );

    // ========================================================
    // BUDGETS
    // ========================================================

    final budgetDataSource =
    BudgetRemoteDataSourceImpl(
      firestore: firestore,
      auth: auth,
    );

    _budgetRepository =
        BudgetRepositoryImpl(
          remoteDataSource:
          budgetDataSource,
        );

    // ========================================================
    // WALLETS
    // ========================================================

    final walletDataSource =
    WalletRemoteDataSourceImpl(
      firestore: firestore,
      auth: auth,
    );

    _walletRepository =
        WalletRepositoryImpl(
          remoteDataSource:
          walletDataSource,
        );

    // ========================================================
    // BILLS
    // ========================================================

    final billDataSource =
    BillRemoteDataSource(
      firestore: firestore,
      firebaseAuth: auth,
    );

    _billRepository =
        BillRepositoryImpl(
          remoteDataSource:
          billDataSource,
        );

    // ========================================================
    // CATEGORIES
    // ========================================================

    final categoryDataSource =
    CategoryRemoteDataSourceImpl(
      firestore: firestore,
      auth: auth,
    );

    _categoryRepository =
        CategoryRepositoryImpl(
          remoteDataSource:
          categoryDataSource,
        );


    // ========================================================
    // SAVINGS GOALS
    // ========================================================

    final savingsGoalDataSource = SavingsGoalRemoteDataSource(
      firestore: firestore,
      auth: auth,
    );

    _savingsGoalRepository = SavingsGoalRepositoryImpl(
      remoteDataSource: savingsGoalDataSource,
    );
  }

  // ==========================================================
  // THEME TOGGLE
  // ==========================================================
  Future<void> _toggleTheme() async {
    await ThemeSettings.instance.toggleManualMode();
  }


  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
animation: ThemeSettings.instance,
builder: (context, _) {
return MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'MoneyFlow',
        theme: LightTheme.theme,
        darkTheme: DarkTheme.theme,
        themeMode: _themeMode,
      
        // Keep one root Navigator for the application.
        // AuthGate controls which page is shown inside that Navigator.
        home: AuthGate(
          authenticatedBuilder: (_) => MainShell(
            onThemeToggle: _toggleTheme,
          ),
        ),
      
        // IMPORTANT:
        // MaterialApp.builder is above the root Navigator. By putting
        // the authenticated BLoC scope here, every pushed route, dialog,
        // bottom sheet, and page can access the same BLoCs.
        builder: (context, child) {
          return _AuthenticatedBlocScope(
            transactionRepository: _transactionRepository,
            budgetRepository: _budgetRepository,
            walletRepository: _walletRepository,
            billRepository: _billRepository,
            categoryRepository: _categoryRepository,
            savingsGoalRepository: _savingsGoalRepository,
            child: child ?? const SizedBox.shrink(),
          );
        },
      );}
    );
  }
}

// ============================================================
// AUTHENTICATED BLOC SCOPE
// ============================================================

/// Places all user-scoped BLoCs ABOVE MaterialApp's root Navigator.
///
/// This is the important part of the auth integration:
///
///   MaterialApp
///     -> builder
///       -> AuthenticatedBlocScope
///         -> root Navigator
///           -> AuthGate
///             -> MainShell / LoginPage
///
/// When the user is signed out, the BLoCs are not created. When the
/// user signs in, the same root Navigator is wrapped by the BLoCs so
/// every route can access them. When the user signs out, the BLoCs are
/// disposed and the next signed-in session gets fresh user-scoped state.
class _AuthenticatedBlocScope extends StatelessWidget {
  const _AuthenticatedBlocScope({
    required this.transactionRepository,
    required this.budgetRepository,
    required this.walletRepository,
    required this.billRepository,
    required this.categoryRepository,
    required this.savingsGoalRepository,
    required this.child,
  });

  final TransactionRepositoryImpl transactionRepository;
  final BudgetRepositoryImpl budgetRepository;
  final WalletRepositoryImpl walletRepository;
  final BillRepositoryImpl billRepository;
  final CategoryRepositoryImpl categoryRepository;
  final SavingsGoalRepositoryImpl savingsGoalRepository;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // While Firebase resolves the current session, let AuthGate
        // show its loading state. No user-scoped BLoCs are created yet.
        if (snapshot.connectionState == ConnectionState.waiting) {
          return child;
        }

        final user = snapshot.data;

        // Signed out -> keep the login route, but do not expose any
        // user-scoped BLoCs.
        if (user == null) {
          return child;
        }

        // Signed in -> all providers sit ABOVE the root Navigator.
        return MultiBlocProvider(
          providers: [
            // ======================================================
            // TRANSACTION BLOC
            // ======================================================
            BlocProvider<TransactionBloc>(
              create: (_) => TransactionBloc(
                repository: transactionRepository,
              )..add(
                const LoadTransactions(),
              ),
            ),

            // ======================================================
            // BUDGET BLOC
            // ======================================================
            BlocProvider<BudgetBloc>(
              create: (_) => BudgetBloc(
                getBudgets: GetBudgets(
                  budgetRepository,
                ),
                addBudget: AddBudget(
                  budgetRepository,
                ),
                updateBudget: UpdateBudget(
                  budgetRepository,
                ),
                deleteBudget: DeleteBudget(
                  budgetRepository,
                ),
              )..add(
                const LoadBudgets(),
              ),
            ),

            // ======================================================
            // WALLET BLOC
            // ======================================================
            BlocProvider<WalletBloc>(
              create: (_) => WalletBloc(
                repository: walletRepository,
              )..add(
                const LoadWallets(),
              ),
            ),

            // ======================================================
            // BILL BLOC
            // ======================================================
            BlocProvider<BillBloc>(
              create: (_) => BillBloc(
                getBills: GetBills(
                  billRepository,
                ),
                addBill: AddBill(
                  billRepository,
                ),
                updateBill: UpdateBill(
                  billRepository,
                ),
                deleteBill: DeleteBill(
                  billRepository,
                ),
                markBillPaid: MarkBillPaid(
                  billRepository,
                ),
              )..add(
                const LoadBills(),
              ),
            ),

            // ======================================================
            // CATEGORY BLOC
            // ======================================================
            BlocProvider<CategoryBloc>(
              create: (_) => CategoryBloc(
                getCategories: GetCategories(
                  categoryRepository,
                ),
                addCategory: AddCategory(
                  categoryRepository,
                ),
                updateCategory: UpdateCategory(
                  categoryRepository,
                ),
                deleteCategory: DeleteCategory(
                  categoryRepository,
                ),
                seedDefaultCategories: SeedDefaultCategories(
                  categoryRepository,
                ),
              )..add(
                const LoadCategories(),
              ),
            ),

            // ======================================================
            // SAVINGS GOALS BLOC
            // ======================================================
            BlocProvider<SavingsGoalBloc>(
              create: (_) => SavingsGoalBloc(
                getSavingsGoals: GetSavingsGoals(savingsGoalRepository),
                addSavingsGoal: AddSavingsGoal(savingsGoalRepository),
                updateSavingsGoal: UpdateSavingsGoal(savingsGoalRepository),
                deleteSavingsGoal: DeleteSavingsGoal(savingsGoalRepository),
                addGoalContribution: AddGoalContribution(savingsGoalRepository),
                removeGoalContribution: RemoveGoalContribution(savingsGoalRepository),
              )..add(
                const LoadSavingsGoals(),
              ),
            ),

            // ======================================================
            // CURRENCY CUBIT
            // ======================================================
            BlocProvider<CurrencyCubit>(
              create: (_) => CurrencyCubit()..loadCurrency(),
            ),
          ],
          child: child,
        );
      },
    );
  }
}
