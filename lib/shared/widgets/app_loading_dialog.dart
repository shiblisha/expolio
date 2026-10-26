import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

class AppLoadingDialog {
  static bool _isShowing = false;
  static BuildContext? _dialogContext;

  static void show(
      BuildContext context, {
        String message = 'Please wait...',
      }) {
    if (_isShowing || !context.mounted) return;

    _isShowing = true;
    _dialogContext = null;

    showDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (dialogContext) {
        _dialogContext = dialogContext;
        final theme = Theme.of(dialogContext);

        return PopScope(
          canPop: false,
          child: Dialog(
            elevation: 0,
            insetPadding: const EdgeInsets.symmetric(horizontal: 44),
            backgroundColor: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 24,
              ),
              decoration: BoxDecoration(
                color: theme.dialogTheme.backgroundColor ??
                    theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                    blurRadius: 30,
                    spreadRadius: 2,
                    offset: Offset(0, 12),
                    color: Colors.black26,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.10),
                      shape: BoxShape.circle,
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(15),
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ).whenComplete(() {
      _dialogContext = null;
      _isShowing = false;
    });
  }

  static void hide() {
    if (!_isShowing) return;

    final dialogContext = _dialogContext;

    if (dialogContext != null && dialogContext.mounted) {
      Navigator.of(dialogContext, rootNavigator: true).pop();
    }

    _dialogContext = null;
    _isShowing = false;
  }
}
