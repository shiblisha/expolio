import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../shared/widgets/currency_text.dart';
import '../../domain/entities/savings_goal_entity.dart';

class GoalProgressCard extends StatelessWidget {
  final SavingsGoalEntity goal;
  final VoidCallback onTap;
  final VoidCallback onContribute;
  final VoidCallback onMore;

  const GoalProgressCard({
    super.key,
    required this.goal,
    required this.onTap,
    required this.onContribute,
    required this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = Color(goal.colorValue);
    final statusColor = _statusColor(goal.status);
    final statusLabel = _statusLabel(goal.status);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: theme.brightness == Brightness.dark
                ? AppColors.darkSurface
                : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: theme.brightness == Brightness.dark
                  ? AppColors.darkBorder
                  : AppColors.lightBorder,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(
                      IconData(goal.iconCodePoint, fontFamily: 'MaterialIcons'),
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          goal.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        CurrencyText(goal.targetAmount,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.55),
                            fontWeight: FontWeight.w600,
                          ),


                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'contribute') onContribute();
                      if (value == 'more') onMore();
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'contribute',
                        child: Row(
                          children: [
                            Icon(Icons.add_circle_outline_rounded, size: 19),
                            SizedBox(width: 10),
                            Text('Add money'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'more',
                        child: Row(
                          children: [
                            Icon(Icons.open_in_new_rounded, size: 19),
                            SizedBox(width: 10),
                            Text('Open goal'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  CurrencyText(
                    goal.currentAmount,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${(goal.progress * 100).round()}%',
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: LinearProgressIndicator(
                  minHeight: 9,
                  value: goal.progress,
                  backgroundColor: color.withValues(alpha: 0.10),
                  color: color,
                ),
              ),
              const SizedBox(height: 9),
              Row(
                children: [
                  Expanded(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (goal.isCompleted)
                          const Text('Goal completed 🎉')
                        else ...[
                          CurrencyText(goal.remainingAmount,
                            style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(width: 4),
                          const Text('remaining'),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (!goal.isCompleted)
                    Text(
                      goal.isOverdue
                          ? 'Overdue'
                          : goal.daysRemaining == 1
                              ? '1 day left'
                              : '${goal.daysRemaining} days left',
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(SavingsGoalStatus status) {
    switch (status) {
      case SavingsGoalStatus.completed:
        return AppColors.income;
      case SavingsGoalStatus.overdue:
        return AppColors.expense;
      case SavingsGoalStatus.active:
        return AppColors.primary;
    }
  }

  String _statusLabel(SavingsGoalStatus status) {
    switch (status) {
      case SavingsGoalStatus.completed:
        return 'Completed';
      case SavingsGoalStatus.overdue:
        return 'Overdue';
      case SavingsGoalStatus.active:
        return 'Active';
    }
  }
}
