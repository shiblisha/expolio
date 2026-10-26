import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/savings_goal_entity.dart';

class SavingsGoalModel extends SavingsGoalEntity {
  const SavingsGoalModel({
    required super.id,
    required super.userId,
    required super.name,
    required super.targetAmount,
    required super.currentAmount,
    required super.targetDate,
    super.description,
    super.iconCodePoint,
    super.colorValue,
    required super.createdAt,
    required super.updatedAt,
    super.contributions,
  });

  factory SavingsGoalModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? <String, dynamic>{};
    return SavingsGoalModel.fromMap(snapshot.id, data);
  }

  factory SavingsGoalModel.fromMap(String id, Map<String, dynamic> data) {
    final rawContributions = data['contributions'];
    final contributions = <GoalContribution>[];

    if (rawContributions is List) {
      for (final raw in rawContributions) {
        if (raw is! Map) continue;
        final map = Map<String, dynamic>.from(raw);
        contributions.add(
          GoalContribution(
            id: map['id']?.toString() ?? '',
            amount: (map['amount'] as num?)?.toDouble() ?? 0,
            date: _dateFromValue(map['date']) ?? DateTime.now(),
            note: map['note']?.toString() ?? '',
          ),
        );
      }
    }

    return SavingsGoalModel(
      id: id,
      userId: data['userId']?.toString() ?? '',
      name: data['name']?.toString() ?? '',
      targetAmount: (data['targetAmount'] as num?)?.toDouble() ?? 0,
      currentAmount: (data['currentAmount'] as num?)?.toDouble() ?? 0,
      targetDate: _dateFromValue(data['targetDate']) ?? DateTime.now(),
      description: data['description']?.toString() ?? '',
      iconCodePoint: (data['iconCodePoint'] as num?)?.toInt() ?? 0xe6d1,
      colorValue: (data['colorValue'] as num?)?.toInt() ?? 0xFF6B3DF5,
      createdAt: _dateFromValue(data['createdAt']) ?? DateTime.now(),
      updatedAt: _dateFromValue(data['updatedAt']) ?? DateTime.now(),
      contributions: contributions,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name,
      'targetAmount': targetAmount,
      'currentAmount': currentAmount,
      'targetDate': Timestamp.fromDate(targetDate),
      'description': description,
      'iconCodePoint': iconCodePoint,
      'colorValue': colorValue,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'contributions': contributions
          .map(
            (item) => {
              'id': item.id,
              'amount': item.amount,
              'date': Timestamp.fromDate(item.date),
              'note': item.note,
            },
          )
          .toList(),
    };
  }

  static DateTime? _dateFromValue(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
