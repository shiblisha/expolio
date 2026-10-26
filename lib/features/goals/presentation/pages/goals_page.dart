import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'add_goal_money_page.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/currency/currency_state.dart';
import '../../../../core/currency/currency_cubit.dart';
import '../../../../core/enums/app_currency.dart';
import '../../../../shared/widgets/currency_text.dart';
import '../../domain/entities/savings_goal_entity.dart';
import '../bloc/savings_goal_bloc.dart';
import '../bloc/savings_goal_event.dart';
import '../bloc/savings_goal_state.dart';
import '../widgets/goal_progress_card.dart';

class GoalsPage extends StatefulWidget {
  const GoalsPage({super.key});

  @override
  State<GoalsPage> createState() => _GoalsPageState();
}

enum _GoalFilter { active, completed, all }

class _GoalsPageState extends State<GoalsPage> {
  _GoalFilter _filter = _GoalFilter.active;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Savings Goals',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Create goal',
            onPressed: () => _showGoalEditor(context),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: BlocConsumer<SavingsGoalBloc, SavingsGoalState>(
        listener: (context, state) {
          if (state.errorMessage != null &&
              state.status != SavingsGoalStatusState.error) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage!),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state.status == SavingsGoalStatusState.loading &&
              state.goals.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          if (state.status == SavingsGoalStatusState.error &&
              state.goals.isEmpty) {
            return _ErrorState(
              message: state.errorMessage ?? 'Unable to load savings goals.',
              onRetry: () =>
                  context.read<SavingsGoalBloc>().add(const LoadSavingsGoals()),
            );
          }

          final visibleGoals = _filteredGoals(state.goals);
          final totalTarget = state.goals.fold<double>(
            0,
            (sum, goal) => sum + goal.targetAmount,
          );
          final totalSaved = state.goals.fold<double>(
            0,
            (sum, goal) => sum + goal.currentAmount,
          );
          final totalRemaining = state.goals.fold<double>(
            0,
            (sum, goal) => sum + goal.remainingAmount,
          );
          final overallProgress = totalTarget > 0
              ? (totalSaved / totalTarget).clamp(0.0, 1.0).toDouble()
              : 0.0;

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async {
              context.read<SavingsGoalBloc>().add(const LoadSavingsGoals());
              await Future.delayed(const Duration(milliseconds: 450));
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
              children: [
                _buildOverview(
                  context,
                  totalTarget,
                  totalSaved,
                  totalRemaining,
                  overallProgress,
                ),
                const SizedBox(height: 18),
                _buildFilter(context, state.goals),
                const SizedBox(height: 16),
                if (visibleGoals.isEmpty)
                  _buildEmpty(context, state.goals.isEmpty)
                else
                  ...visibleGoals.map(
                    (goal) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: GoalProgressCard(
                        goal: goal,
                        onTap: () => _openDetails(goal),
                        onContribute: () =>
                            _showContributionDialog(context, goal),
                        onMore: () => _openDetails(goal),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showGoalEditor(context),
        icon: const Icon(Icons.flag_rounded),
        label: const Text('New Goal'),
      ),
    );
  }

  List<SavingsGoalEntity> _filteredGoals(List<SavingsGoalEntity> goals) {
    switch (_filter) {
      case _GoalFilter.active:
        return goals.where((g) => !g.isCompleted).toList();
      case _GoalFilter.completed:
        return goals.where((g) => g.isCompleted).toList();
      case _GoalFilter.all:
        return goals;
    }
  }

  Widget _buildOverview(
    BuildContext context,
    double totalTarget,
    double totalSaved,
    double totalRemaining,
    double progress,
  ) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primaryDark, AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(Icons.savings_rounded, color: Colors.white),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Savings progress',
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Build towards what matters',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          CurrencyText(
            totalSaved,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              const Text('saved of ', style: TextStyle(color: Colors.white70)),
              CurrencyText(
                totalTarget,
                style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: LinearProgressIndicator(
              minHeight: 9,
              value: progress,
              backgroundColor: Colors.white.withValues(alpha: 0.14),
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                '${(progress * 100).round()}% complete',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              const Text('Remaining ', style: TextStyle(color: Colors.white70)),
              CurrencyText(
                totalRemaining,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilter(BuildContext context, List<SavingsGoalEntity> goals) {
    final counts = {
      _GoalFilter.active: goals.where((g) => !g.isCompleted).length,
      _GoalFilter.completed: goals.where((g) => g.isCompleted).length,
      _GoalFilter.all: goals.length,
    };

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _GoalFilter.values.map((filter) {
          final selected = _filter == filter;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              selected: selected,
              label: Text('${_filterLabel(filter)} ${counts[filter]}'),
              onSelected: (_) => setState(() => _filter = filter),
              selectedColor: AppColors.primary,
              labelStyle: TextStyle(
                color: selected ? Colors.white : null,
                fontWeight: FontWeight.w700,
              ),
              side: BorderSide.none,
            ),
          );
        }).toList(),
      ),
    );
  }

  String _filterLabel(_GoalFilter filter) {
    switch (filter) {
      case _GoalFilter.active:
        return 'Active';
      case _GoalFilter.completed:
        return 'Completed';
      case _GoalFilter.all:
        return 'All';
    }
  }

  Widget _buildEmpty(BuildContext context, bool noGoalsAtAll) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? AppColors.darkSurface
            : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.flag_rounded,
              color: AppColors.primary,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            noGoalsAtAll ? 'No savings goals yet' : 'Nothing in this filter',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            noGoalsAtAll
                ? 'Create a goal and start tracking your progress.'
                : 'Try another filter to see your goals.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.55),
            ),
          ),
          if (noGoalsAtAll) ...[
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: () => _showGoalEditor(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create Goal'),
            ),
          ],
        ],
      ),
    );
  }

  void _openDetails(SavingsGoalEntity goal) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => GoalDetailsPage(goalId: goal.id)));
  }

  Future<void> _showGoalEditor(
    BuildContext context, {
    SavingsGoalEntity? existing,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => _GoalEditorDialog(existing: existing),
    );
    if (result == true && mounted) {
      context.read<SavingsGoalBloc>().add(const LoadSavingsGoals());
    }
  }

  Future<void> _showContributionDialog(
      BuildContext context,
      SavingsGoalEntity goal,
      ) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddGoalMoneyPage(
          initialGoalId: goal.id,
        ),
      ),
    );
  }
}

class GoalDetailsPage extends StatelessWidget {
  final String goalId;
  const GoalDetailsPage({super.key, required this.goalId});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SavingsGoalBloc, SavingsGoalState>(
      builder: (context, state) {
        SavingsGoalEntity? goal;
        for (final item in state.goals) {
          if (item.id == goalId) {
            goal = item;
            break;
          }
        }
        if (goal == null) {
          return const Scaffold(body: Center(child: Text('Goal not found')));
        }

        final theme = Theme.of(context);
        final color = Color(goal.colorValue);

        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'Goal Details',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            actions: [
              IconButton(
                tooltip: 'Edit',
                onPressed: () => _edit(context, goal!),
                icon: const Icon(Icons.edit_rounded),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'delete') _delete(context, goal!);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'delete', child: Text('Delete goal')),
                ],
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.brightness == Brightness.dark
                      ? AppColors.darkSurface
                      : AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: theme.brightness == Brightness.dark
                        ? AppColors.darkBorder
                        : AppColors.lightBorder,
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        IconData(
                          goal.iconCodePoint,
                          fontFamily: 'MaterialIcons',
                        ),
                        color: color,
                        size: 30,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      goal.name,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (goal.description.trim().isNotEmpty) ...[
                      const SizedBox(height: 7),
                      Text(
                        goal.description,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.textTheme.bodySmall?.color?.withValues(
                            alpha: 0.55,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    CurrencyText(
                      goal.currentAmount,
                      style: theme.textTheme.displaySmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('of '),
                        CurrencyText(
                          goal.targetAmount,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: LinearProgressIndicator(
                        minHeight: 10,
                        value: goal.progress,
                        backgroundColor: color.withValues(alpha: 0.10),
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${(goal.progress * 100).round()}% complete',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _buildMetrics(context, goal),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: goal.isCompleted
                    ? null
                    : () => _addMoney(context, goal!),
                icon: const Icon(Icons.add_rounded),
                label: Text(goal.isCompleted ? 'Goal Completed' : 'Add Money'),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Contribution History',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    '${goal.contributions.length}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (goal.contributions.isEmpty)
                _emptyHistory(context)
              else
                ...goal.contributions.reversed.map(
                  (item) => _contributionTile(context, goal!, item),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetrics(BuildContext context, SavingsGoalEntity goal) {
    final theme = Theme.of(context);
    final items = <_MetricData>[
      _MetricData(
        'Target date',
        _dateLabel(goal.targetDate),
        Icons.event_rounded,
      ),
      _MetricData(
        'Monthly needed',
        '',
        Icons.calendar_month_rounded,
        amount: goal.requiredMonthlyAmount,
      ),
      _MetricData(
        'Weekly needed',
        '',
        Icons.date_range_rounded,
        amount: goal.requiredWeeklyAmount,
      ),
      _MetricData(
        'Daily needed',
        '',
        Icons.today_rounded,
        amount: goal.requiredDailyAmount,
      ),
    ];

    if (goal.isCompleted) {
      items[1] = const _MetricData(
        'Status',
        'Completed 🎉',
        Icons.celebration_rounded,
      );
      items[2] = const _MetricData(
        'Days left',
        'Done',
        Icons.check_circle_rounded,
      );
      items[3] = const _MetricData(
        'Contributions',
        '',
        Icons.savings_rounded,
        rawText: null,
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        mainAxisExtent: 94,
      ),
      itemBuilder: (_, index) {
        final item = items[index];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.brightness == Brightness.dark
                ? AppColors.darkSurface
                : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: theme.brightness == Brightness.dark
                  ? AppColors.darkBorder
                  : AppColors.lightBorder,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(item.icon, size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item.title,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color?.withValues(
                          alpha: 0.55,
                        ),
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 3),
                    if (item.amount != null)
                      CurrencyText(
                        item.amount!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      )
                    else
                      Text(
                        item.value ?? '${goal.contributions.length}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _contributionTile(
    BuildContext context,
    SavingsGoalEntity goal,
    GoalContribution item,
  ) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? AppColors.darkSurface
            : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(17),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.income.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.savings_rounded,
              color: AppColors.income,
              size: 20,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CurrencyText(
                  item.amount,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.income,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.note.trim().isEmpty
                      ? _dateLabel(item.date)
                      : '${item.note} • ${_dateLabel(item.date)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.textTheme.bodySmall?.color?.withValues(
                      alpha: 0.55,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remove contribution',
            onPressed: () => _removeContribution(context, goal, item),
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: AppColors.expense,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyHistory(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? AppColors.darkSurface
            : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        'No contributions yet. Add money to start building a saving history.',
        textAlign: TextAlign.center,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.55),
        ),
      ),
    );
  }

  Future<void> _edit(BuildContext context, SavingsGoalEntity goal) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => _GoalEditorDialog(existing: goal),
    );
    if (result == true && context.mounted) {
      context.read<SavingsGoalBloc>().add(const LoadSavingsGoals());
    }
  }

  Future<void> _addMoney(
      BuildContext context,
      SavingsGoalEntity goal,
      ) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddGoalMoneyPage(
          initialGoalId: goal.id,
        ),
      ),
    );
  }

  Future<void> _removeContribution(
    BuildContext context,
    SavingsGoalEntity goal,
    GoalContribution item,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(
          'Remove contribution?',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: const Text(
          'This will subtract the contribution from the goal total.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      context.read<SavingsGoalBloc>().add(
        RemoveGoalContributionEvent(goalId: goal.id, contributionId: item.id),
      );
    }
  }

  Future<void> _delete(BuildContext context, SavingsGoalEntity goal) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(
          'Delete savings goal?',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Text('Delete "${goal.name}" and its contribution history?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.expense,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      context.read<SavingsGoalBloc>().add(DeleteSavingsGoalEvent(goal.id));
      Navigator.pop(context);
    }
  }

  String _dateLabel(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')} ${_month(value.month)} ${value.year}';
  String _month(int month) => const [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ][month - 1];
}

class _MetricData {
  final String title;
  final String? value;
  final IconData icon;
  final double? amount;
  final String? rawText;

  const _MetricData(
    this.title,
    this.value,
    this.icon, {
    this.amount,
    this.rawText,
  });
}

class _GoalEditorDialog extends StatefulWidget {
  final SavingsGoalEntity? existing;
  const _GoalEditorDialog({this.existing});
  @override
  State<_GoalEditorDialog> createState() => _GoalEditorDialogState();
}

class _GoalEditorDialogState extends State<_GoalEditorDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _targetController;
  late final TextEditingController _startingController;
  late final TextEditingController _descriptionController;
  late DateTime _targetDate;
  late int _iconCodePoint;
  late int _colorValue;
  bool _saving = false;

  static const _icons = [
    Icons.laptop_mac_rounded,
    Icons.directions_car_rounded,
    Icons.home_rounded,
    Icons.flight_takeoff_rounded,
    Icons.favorite_rounded,
    Icons.school_rounded,
    Icons.phone_iphone_rounded,
    Icons.emergency_rounded,
    Icons.savings_rounded,
    Icons.card_giftcard_rounded,
  ];

  static const _colors = [
    0xFF6B3DF5,
    0xFF2F7E79,
    0xFF3F6BFF,
    0xFFFF8A3D,
    0xFFE85D8B,
    0xFF25A969,
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameController = TextEditingController(text: e?.name ?? '');
    _targetController = TextEditingController(
      text: e == null ? '' : e.targetAmount.toString(),
    );
    _startingController = TextEditingController(
      text: e == null ? '' : e.currentAmount.toString(),
    );
    _descriptionController = TextEditingController(text: e?.description ?? '');
    _targetDate =
        e?.targetDate ??
        DateTime(
          DateTime.now().year,
          DateTime.now().month + 3,
          DateTime.now().day,
        );
    _iconCodePoint = e?.iconCodePoint ?? _icons.first.codePoint;
    _colorValue = e?.colorValue ?? _colors.first;
    if (e != null) _startingController.text = e.currentAmount.toString();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
    _startingController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.existing != null;

    return AlertDialog(
      title: Text(
        isEditing ? 'Edit Savings Goal' : 'Create Savings Goal',
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _label('Goal name'),
              TextField(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                decoration: _input('e.g. New Laptop', Icons.flag_rounded),
              ),
              const SizedBox(height: 14),
              _label('Target amount'),
              BlocBuilder<CurrencyCubit, CurrencyState>(
                builder: (context, currency) => TextField(
                  controller: _targetController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: _input(
                    '0.00',
                    Icons.payments_rounded,
                    prefix: '${currency.currency.symbol} ',
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _label(isEditing ? 'Saved amount' : 'Already saved (optional)'),
              BlocBuilder<CurrencyCubit, CurrencyState>(
                builder: (context, currency) => TextField(
                  controller: _startingController,
                  enabled: !isEditing,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: _input(
                    '0.00',
                    Icons.savings_rounded,
                    prefix: '${currency.currency.symbol} ',
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _label('Target date'),
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.event_rounded),
                label: Row(
                  children: [
                    Text(_dateLabel(_targetDate)),
                    const Spacer(),
                    const Icon(Icons.keyboard_arrow_down_rounded),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _label('Goal icon'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _icons.map((icon) {
                  final selected = icon.codePoint == _iconCodePoint;
                  return InkWell(
                    onTap: () =>
                        setState(() => _iconCodePoint = icon.codePoint),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: selected
                            ? Color(_colorValue).withValues(alpha: 0.16)
                            : theme.brightness == Brightness.dark
                            ? AppColors.darkSurface
                            : AppColors.lightSurface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: selected
                              ? Color(_colorValue)
                              : Colors.transparent,
                        ),
                      ),
                      child: Icon(
                        icon,
                        color: selected ? Color(_colorValue) : null,
                        size: 21,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              _label('Accent color'),
              Wrap(
                spacing: 10,
                children: _colors
                    .map(
                      (value) => InkWell(
                        onTap: () => setState(() => _colorValue = value),
                        borderRadius: BorderRadius.circular(30),
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: Color(value),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _colorValue == value
                                  ? Colors.white
                                  : Colors.transparent,
                              width: 3,
                            ),
                            boxShadow: _colorValue == value
                                ? [
                                    BoxShadow(
                                      color: Color(value)
                                          .withValues(alpha: 0.35),
                                      blurRadius: 0,
                                      spreadRadius: 2,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 14),
              _label('Description (optional)'),
              TextField(
                controller: _descriptionController,
                minLines: 2,
                maxLines: 4,
                decoration: _input(
                  'Why are you saving for this?',
                  Icons.notes_rounded,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(isEditing ? 'Update' : 'Create'),
        ),
      ],
    );
  }

  InputDecoration _input(String hint, IconData icon, {String? prefix}) =>
      InputDecoration(
        prefixText: prefix,
        hintText: hint,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: Theme.of(context).brightness == Brightness.dark
            ? AppColors.darkSurface
            : AppColors.lightSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      );
  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
  );
  String _dateLabel(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')} ${const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][value.month - 1]} ${value.year}';

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate:
          _targetDate.isBefore(DateTime.now()) && widget.existing == null
          ? DateTime.now().add(const Duration(days: 1))
          : _targetDate,
      firstDate: widget.existing == null ? DateTime.now() : DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _targetDate = picked);
  }

  Future<void> _save() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final name = _nameController.text.trim();
    final target = double.tryParse(_targetController.text.trim());
    final starting = double.tryParse(_startingController.text.trim()) ?? 0;

    if (name.isEmpty) {
      _snack('Enter a goal name');
      return;
    }
    if (target == null || target <= 0) {
      _snack('Enter a valid target amount');
      return;
    }
    if (starting < 0 || starting > target) {
      _snack('Already saved must be between 0 and the target amount');
      return;
    }

    final now = DateTime.now();
    final existing = widget.existing;
    final goal = SavingsGoalEntity(
      id: existing?.id ?? '',
      userId: user.uid,
      name: name,
      targetAmount: target,
      currentAmount: existing?.currentAmount ?? starting,
      targetDate: _targetDate,
      description: _descriptionController.text.trim(),
      iconCodePoint: _iconCodePoint,
      colorValue: _colorValue,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
      contributions: existing?.contributions ?? const [],
    );

    setState(() => _saving = true);
    final bloc = context.read<SavingsGoalBloc>();
    bloc.add(
      existing == null
          ? AddSavingsGoalEvent(goal)
          : UpdateSavingsGoalEvent(goal),
    );
    await Future.delayed(const Duration(milliseconds: 100));
    if (mounted) Navigator.pop(context, true);
  }

  void _snack(String text) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
  );
}


class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: 54,
            color: AppColors.primary,
          ),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ],
      ),
    ),
  );
}
