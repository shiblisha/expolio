import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../shared/widgets/currency_text.dart';
import '../../domain/entities/savings_goal_entity.dart';
import '../bloc/savings_goal_bloc.dart';
import '../bloc/savings_goal_state.dart';
import '../pages/goals_page.dart';

class SavingsGoalsDashboardCard extends StatelessWidget {
  const SavingsGoalsDashboardCard({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SavingsGoalBloc, SavingsGoalState>(
      builder: (context, state) {
        final goals = state.goals.where((goal) => !goal.isCompleted).toList();
        if (goals.isEmpty) return const SizedBox.shrink();
        goals.sort((a, b) => b.progress.compareTo(a.progress));
        final goal = goals.first;
        final theme = Theme.of(context);
        final color = Color(goal.colorValue);

        return GestureDetector(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GoalsPage())),
          child: Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: theme.brightness == Brightness.dark ? AppColors.darkSurface : AppColors.lightSurface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: theme.brightness == Brightness.dark ? AppColors.darkBorder : AppColors.lightBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(width: 42, height: 42, decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle), child: Icon(Icons.flag_rounded, color: color)),
                  const SizedBox(width: 11),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Savings Goals', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)), const SizedBox(height: 2), Text(goal.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall?.copyWith(color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.55)))])),
                  const Icon(Icons.chevron_right_rounded),
                ]),
                const SizedBox(height: 18),
                Row(children: [CurrencyText(goal.currentAmount, style: theme.textTheme.titleMedium?.copyWith(color: color, fontWeight: FontWeight.w800)), const Spacer(), Text('${(goal.progress * 100).round()}%', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800))]),
                const SizedBox(height: 8),
                ClipRRect(borderRadius: BorderRadius.circular(30), child: LinearProgressIndicator(minHeight: 8, value: goal.progress, backgroundColor: color.withValues(alpha: 0.10), color: color)),
                const SizedBox(height: 8),
                Row(children: [const Text('Remaining '), CurrencyText(goal.remainingAmount, style: const TextStyle(fontWeight: FontWeight.w700)), const Spacer(), Text(goal.isOverdue ? 'Overdue' : '${goal.daysRemaining} days left', style: TextStyle(color: goal.isOverdue ? AppColors.expense : AppColors.primary, fontWeight: FontWeight.w700, fontSize: 11))]),
              ],
            ),
          ),
        );
      },
    );
  }
}
