import 'package:flutter/material.dart';

import '../../../../../app/theme/app_colors.dart';
import '../../../../../core/services/auth_service.dart';
import '../../../../shared/widgets/app_loading_dialog.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authService = AuthService();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _createAccount() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await _runAuthAction(
      message: 'Creating your account...',
      action: () async {
        await _authService.createAccountWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          displayName: _nameController.text.trim(),
        );
      },
    );

    if (success) {
      _closeIfPushed();
    }
  }

  Future<void> _createWithGoogle() async {
    final success = await _runAuthAction(
      message: 'Signing in with Google...',
      action: () async {
        await _authService.signInWithGoogle();
      },
    );

    if (success) {
      _closeIfPushed();
    }
  }

  Future<bool> _runAuthAction({
    required Future<void> Function() action,
    required String message,
  }) async {
    if (_isLoading) return false;

    setState(() {
      _isLoading = true;
    });

    AppLoadingDialog.show(
      context,
      message: message,
    );

    try {
      await action();
      return true;
    } catch (error) {
      if (!mounted) return false;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_authService.messageForException(error)),
          behavior: SnackBarBehavior.floating,
        ),
      );

      return false;
    } finally {
      // Always close the shared loading dialog, even if authentication
      // already navigated away from this page.
      AppLoadingDialog.hide();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _closeIfPushed() {
    if (!mounted) return;

    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Create Account',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 30),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      width: 74,
                      height: 74,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(23),
                      ),
                      child: const Icon(
                        Icons.person_add_alt_1_rounded,
                        color: AppColors.primary,
                        size: 36,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Join MoneyFlow',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create your account and keep your finances in sync.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.textTheme.bodyMedium?.color?.withValues(
                          alpha: 0.60,
                        ),
                      ),
                    ),
                    const SizedBox(height: 26),
                    _buildLabel('Name'),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _nameController,
                      hintText: 'Your name',
                      prefixIcon: Icons.person_outline_rounded,
                      textInputAction: TextInputAction.next,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Enter your name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 18),
                    _buildLabel('Email'),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _emailController,
                      hintText: 'you@example.com',
                      prefixIcon: Icons.mail_outline_rounded,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      validator: (value) {
                        final email = value?.trim() ?? '';
                        if (email.isEmpty) return 'Enter your email';
                        if (!email.contains('@')) return 'Enter a valid email';
                        return null;
                      },
                    ),
                    const SizedBox(height: 18),
                    _buildLabel('Password'),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _passwordController,
                      hintText: 'At least 6 characters',
                      prefixIcon: Icons.lock_outline_rounded,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.next,
                      suffixIcon: IconButton(
                        onPressed: _isLoading
                            ? null
                            : () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.length < 6) {
                          return 'Use at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 18),
                    _buildLabel('Confirm Password'),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _confirmPasswordController,
                      hintText: 'Re-enter your password',
                      prefixIcon: Icons.lock_reset_rounded,
                      obscureText: _obscureConfirmPassword,
                      textInputAction: TextInputAction.done,
                      suffixIcon: IconButton(
                        onPressed: _isLoading
                            ? null
                            : () {
                          setState(() {
                            _obscureConfirmPassword =
                            !_obscureConfirmPassword;
                          });
                        },
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                      validator: (value) {
                        if (value != _passwordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _createAccount,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                          AppColors.primary.withValues(alpha: 0.45),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(17),
                          ),
                        ),
                        child: const Text(
                          'Create Account',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(child: Divider(color: theme.dividerColor)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Text(
                            'OR',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: theme.textTheme.bodySmall?.color
                                  ?.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                        Expanded(child: Divider(color: theme.dividerColor)),
                      ],
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      height: 54,
                      child: OutlinedButton.icon(
                        onPressed: _isLoading ? null : _createWithGoogle,
                        icon: Image.asset("assets/icons/google.png", width: 35, height: 35),
                        label: const Text('Continue with Google'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.textTheme.bodyLarge?.color,
                          side: BorderSide(
                            color: isDark
                                ? AppColors.darkBorder
                                : AppColors.lightBorder,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(17),
                          ),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Already have an account?',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.textTheme.bodyMedium?.color
                                ?.withValues(alpha: 0.65),
                          ),
                        ),
                        TextButton(
                          onPressed: _isLoading
                              ? null
                              : () => Navigator.of(context).pop(),
                          child: const Text(
                            'Sign In',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your account is managed securely by Firebase Authentication.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color?.withValues(
                          alpha: 0.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String label) {
    return Text(
      label,
      style: const TextStyle(fontWeight: FontWeight.w800),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData prefixIcon,
    required String? Function(String?) validator,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      obscureText: obscureText,
      validator: validator,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: Icon(prefixIcon),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: const BorderSide(
            color: AppColors.primary,
            width: 1.4,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: const BorderSide(color: AppColors.expense),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: const BorderSide(
            color: AppColors.expense,
            width: 1.4,
          ),
        ),
      ),
    );
  }
}
