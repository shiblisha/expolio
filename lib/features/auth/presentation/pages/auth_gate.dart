import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../../app/theme/app_colors.dart';
import '../../../../../core/services/auth_service.dart';
import '../../../../shared/widgets/app_loading_indicator.dart';
import 'login_page.dart';

/// Keeps authentication routing separate from the app shell.
///
/// Pass the existing MainShell builder from the place where your app already
/// creates MainShell. This avoids coupling AuthGate to a specific folder path.
class AuthGate extends StatelessWidget {
  final WidgetBuilder authenticatedBuilder;

  const AuthGate({
    super.key,
    required this.authenticatedBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: AppLoadingIndicator(
                color: AppColors.primary,
              ),
            ),
          );
        }

        final user = snapshot.data;

        if (user == null) {
          return const LoginPage();
        }

        return authenticatedBuilder(context);
      },
    );
  }
}
