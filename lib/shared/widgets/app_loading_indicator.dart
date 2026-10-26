import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

/// Reusable MoneyFlow loading indicator.
///
/// Use this instead of raw CircularProgressIndicator where a full-page
/// loading state is required. The animation stays lightweight and follows
/// the existing MoneyFlow color system.
class AppLoadingIndicator extends StatelessWidget {
  final double size;
  final double strokeWidth;
  final Color? color;
  final String? message;

  const AppLoadingIndicator({
    super.key,
    this.size = 34,
    this.strokeWidth = 3,
    this.color,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedColor = color ?? AppColors.primary;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              strokeWidth: strokeWidth,
              valueColor: AlwaysStoppedAnimation<Color>(resolvedColor),
              backgroundColor: resolvedColor.withValues(alpha: 0.12),
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 14),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.color
                        ?.withValues(alpha: 0.58),
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Small inline loader for buttons and compact cards.
class AppInlineLoadingIndicator extends StatelessWidget {
  final double size;
  final double strokeWidth;
  final Color color;

  const AppInlineLoadingIndicator({
    super.key,
    this.size = 20,
    this.strokeWidth = 2.2,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: strokeWidth,
        valueColor: AlwaysStoppedAnimation<Color>(color),
      ),
    );
  }
}
