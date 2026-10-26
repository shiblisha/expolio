import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';

class SendAgainSection extends StatelessWidget {
  const SendAgainSection({super.key});

  @override
  Widget build(BuildContext context) {
    final users = [
      const _ContactData(
        name: 'Ameen',
        initials: 'AM',
      ),
      const _ContactData(
        name: 'Fahad',
        initials: 'FH',
      ),
      const _ContactData(
        name: 'Rahul',
        initials: 'RK',
      ),
      const _ContactData(
        name: 'Nihal',
        initials: 'NH',
      ),
      const _ContactData(
        name: 'Arjun',
        initials: 'AJ',
      ),
    ];

    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: users.length,
        separatorBuilder: (_, _) => const SizedBox(width: 18),
        itemBuilder: (context, index) {
          final user = users[index];

          return SizedBox(
            width: 58,
            child: Column(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      user.initials,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  user.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ContactData {
  final String name;
  final String initials;

  const _ContactData({
    required this.name,
    required this.initials,
  });
}