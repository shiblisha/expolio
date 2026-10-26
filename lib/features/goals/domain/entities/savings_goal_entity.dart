import 'package:equatable/equatable.dart';

class GoalContribution extends Equatable {
  final String id;
  final double amount;
  final DateTime date;
  final String note;

  const GoalContribution({
    required this.id,
    required this.amount,
    required this.date,
    required this.note,
  });

  @override
  List<Object?> get props => [id, amount, date, note];
}

enum SavingsGoalStatus { active, completed, overdue }

class SavingsGoalEntity extends Equatable {
  final String id;
  final String userId;
  final String name;
  final double targetAmount;
  final double currentAmount;
  final DateTime targetDate;
  final String description;
  final int iconCodePoint;
  final int colorValue;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<GoalContribution> contributions;

  const SavingsGoalEntity({
    required this.id,
    required this.userId,
    required this.name,
    required this.targetAmount,
    required this.currentAmount,
    required this.targetDate,
    this.description = '',
    this.iconCodePoint = 0xe6d1,
    this.colorValue = 0xFF6B3DF5,
    required this.createdAt,
    required this.updatedAt,
    this.contributions = const [],
  });

  double get progress {
    if (targetAmount <= 0) return 0;
    return (currentAmount / targetAmount).clamp(0.0, 1.0).toDouble();
  }

  double get remainingAmount => (targetAmount - currentAmount).clamp(0, double.infinity).toDouble();

  bool get isCompleted => currentAmount >= targetAmount && targetAmount > 0;

  bool get isOverdue => !isCompleted && DateTime.now().isAfter(_endOfDay(targetDate));

  SavingsGoalStatus get status {
    if (isCompleted) return SavingsGoalStatus.completed;
    if (isOverdue) return SavingsGoalStatus.overdue;
    return SavingsGoalStatus.active;
  }

  int get daysRemaining {
    if (isCompleted) return 0;
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final end = DateTime(targetDate.year, targetDate.month, targetDate.day);
    return end.difference(today).inDays;
  }

  double get requiredMonthlyAmount {
    if (isCompleted || remainingAmount <= 0) return 0;
    final months = _monthsUntil(targetDate);
    if (months <= 0) return remainingAmount;
    return remainingAmount / months;
  }

  double get requiredWeeklyAmount {
    if (isCompleted || remainingAmount <= 0) return 0;
    final weeks = (daysRemaining / 7).ceil();
    if (weeks <= 0) return remainingAmount;
    return remainingAmount / weeks;
  }

  double get requiredDailyAmount {
    if (isCompleted || remainingAmount <= 0) return 0;
    final days = daysRemaining;
    if (days <= 0) return remainingAmount;
    return remainingAmount / days;
  }

  double get averageContributionAmount {
    if (contributions.isEmpty) return 0;
    return contributions.fold<double>(0, (sum, item) => sum + item.amount) / contributions.length;
  }

  double get averageMonthlyContribution {
    if (contributions.isEmpty) return 0;
    final dates = contributions.map((e) => e.date).toList()..sort();
    final first = dates.first;
    final last = dates.last;
    final monthSpan = ((last.year - first.year) * 12 + last.month - first.month) + 1;
    final months = monthSpan.clamp(1, 120000);
    final contributed = contributions.fold<double>(0, (sum, item) => sum + item.amount);
    return contributed / months;
  }

  DateTime? get estimatedCompletionDate {
    if (isCompleted) return DateTime.now();
    final pace = averageMonthlyContribution;
    if (pace <= 0 || remainingAmount <= 0) return null;
    final monthsNeeded = (remainingAmount / pace).ceil();
    return DateTime(DateTime.now().year, DateTime.now().month + monthsNeeded, DateTime.now().day);
  }

  SavingsGoalEntity copyWith({
    String? id,
    String? userId,
    String? name,
    double? targetAmount,
    double? currentAmount,
    DateTime? targetDate,
    String? description,
    int? iconCodePoint,
    int? colorValue,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<GoalContribution>? contributions,
  }) {
    return SavingsGoalEntity(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      targetDate: targetDate ?? this.targetDate,
      description: description ?? this.description,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      colorValue: colorValue ?? this.colorValue,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      contributions: contributions ?? this.contributions,
    );
  }

  static DateTime _endOfDay(DateTime date) => DateTime(date.year, date.month, date.day, 23, 59, 59);

  static int _monthsUntil(DateTime target) {
    final now = DateTime.now();
    return ((target.year - now.year) * 12 + target.month - now.month + (target.day >= now.day ? 1 : 0)).clamp(1, 120000);
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        name,
        targetAmount,
        currentAmount,
        targetDate,
        description,
        iconCodePoint,
        colorValue,
        createdAt,
        updatedAt,
        contributions,
      ];
}
