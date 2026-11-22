import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/routing/route_names.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/features/auth/application/auth_provider.dart';
import 'package:frontend/features/auth/presentation/widgets/auth_modernist_layout.dart';
import 'package:frontend/shared/widgets/widgets.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String? _emailServerError;

  static final RegExp _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (ref.read(authNotifierProvider).isLoading) return;
    ref.read(authNotifierProvider.notifier).clearError();
    setState(() => _emailServerError = null);

    if (_formKey.currentState?.validate() ?? false) {
      final name = _nameController.text.trim();
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      final success = await ref.read(authNotifierProvider.notifier).register(
            email: email,
            password: password,
            fullName: name,
          );

      if (success && mounted) {
        AppFeedback.showSuccess(
          context,
          'Account created successfully! Please sign in.',
        );
        context.go(AppRoutes.login);
      } else if (mounted) {
        final errorMsg = ref.read(authNotifierProvider).errorMessage;
        if (errorMsg != null && errorMsg.toLowerCase().contains('email')) {
          setState(() {
            _emailServerError = errorMsg;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authState = ref.watch(authNotifierProvider);
    final accentColor = AppColors.accentFor(isDark);
    final textSecondary = AppColors.textSecondaryFor(isDark);

    return AuthModernistLayout(
      heroHeadline: 'Built for structured delivery.',
      heroSubtitle:
          'Organize workspaces, plan sprints, and track every milestone with complete visibility.',
      formTitle: 'Create an Account',
      formSubtitle: 'Get started with Oversee project management.',
      formChild: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthErrorBanner(
              message: authState.hasError ? authState.errorMessage : null,
              onDismiss: () {
                ref.read(authNotifierProvider.notifier).clearError();
                setState(() => _emailServerError = null);
              },
            ),
            AppTextFormField(
              controller: _nameController,
              label: 'Full Name',
              isRequired: true,
              hintText: 'John Doe',
              textInputAction: TextInputAction.next,
              prefixIcon: const Icon(Icons.person_outline_rounded, size: 18.0),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 13.0),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your full name';
                }
                if (value.trim().length > 255) {
                  return 'Full name cannot exceed 255 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 14.0),
            AppTextFormField(
              controller: _emailController,
              label: 'Email Address',
              isRequired: true,
              hintText: 'name@example.com',
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              prefixIcon: const Icon(Icons.email_outlined, size: 18.0),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 13.0),
              errorText: _emailServerError,
              onChanged: (_) {
                if (_emailServerError != null) {
                  setState(() => _emailServerError = null);
                }
              },
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your email address';
                }
                if (!_emailRegex.hasMatch(value.trim())) {
                  return 'Please enter a valid email address';
                }
                return null;
              },
            ),
            const SizedBox(height: 14.0),
            AppTextFormField(
              controller: _passwordController,
              label: 'Password',
              isRequired: true,
              isPassword: true,
              hintText: '••••••••',
              textInputAction: TextInputAction.next,
              prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18.0),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 13.0),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a password';
                }
                if (value.length < 8) {
                  return 'Password must be at least 8 characters';
                }
                if (value.length > 128) {
                  return 'Password must not exceed 128 characters';
                }
                if (!RegExp(r'[A-Z]').hasMatch(value)) {
                  return 'Password must contain at least one uppercase letter';
                }
                if (!RegExp(r'[a-z]').hasMatch(value)) {
                  return 'Password must contain at least one lowercase letter';
                }
                if (!RegExp(r'\d').hasMatch(value)) {
                  return 'Password must contain at least one digit';
                }
                return null;
              },
            ),
            const SizedBox(height: 8.0),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _passwordController,
              builder: (context, value, _) {
                return _PasswordCriteriaStrip(password: value.text, isDark: isDark);
              },
            ),
            const SizedBox(height: 14.0),
            AppTextFormField(
              controller: _confirmPasswordController,
              label: 'Confirm Password',
              isRequired: true,
              isPassword: true,
              hintText: '••••••••',
              textInputAction: TextInputAction.done,
              prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18.0),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 13.0),
              onFieldSubmitted: authState.isLoading ? null : (_) => _handleRegister(),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please confirm your password';
                }
                if (value != _passwordController.text) {
                  return 'Passwords do not match';
                }
                return null;
              },
            ),
            const SizedBox(height: 22.0),
            AppPrimaryButton(
              label: 'Create Account',
              isFullWidth: true,
              height: 44.0,
              isLoading: authState.isLoading,
              onPressed: _handleRegister,
            ),
          ],
        ),
      ),
      footerChild: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            'Already have an account? ',
            style: TextStyle(fontSize: 12.5, color: textSecondary),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: accentColor,
              padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 4.0),
              minimumSize: const Size(0, 32.0),
              textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
            onPressed: () {
              ref.read(authNotifierProvider.notifier).clearError();
              context.go(AppRoutes.login);
            },
            child: const Text('Sign In'),
          ),
        ],
      ),
    );
  }
}

/// Minimal 4-segment password requirements meter aligned with registration rules.
class _PasswordCriteriaStrip extends StatelessWidget {
  final String password;
  final bool isDark;

  const _PasswordCriteriaStrip({
    required this.password,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final hasLength = password.length >= 8;
    final hasUpper = RegExp(r'[A-Z]').hasMatch(password);
    final hasLower = RegExp(r'[a-z]').hasMatch(password);
    final hasDigit = RegExp(r'\d').hasMatch(password);
    final score = (hasLength ? 1 : 0) +
        (hasUpper ? 1 : 0) +
        (hasLower ? 1 : 0) +
        (hasDigit ? 1 : 0);

    final trackColor = AppColors.borderSoftFor(isDark);
    final activeColor = score == 4
        ? AppColors.successFor(isDark)
        : score >= 2
            ? AppColors.accentSolidFor(isDark)
            : AppColors.warningFor(isDark);

    return Semantics(
      label: '$score of 4 password requirements met',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: List.generate(4, (index) {
              final filled = index < score;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: index < 3 ? 5.0 : 0.0),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    height: 3.0,
                    decoration: BoxDecoration(
                      color: filled ? activeColor : trackColor,
                      borderRadius: BorderRadius.circular(2.0),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 6.0),
          Text(
            'Min 8 chars with uppercase, lowercase & number',
            style: TextStyle(
              fontSize: 11.0,
              height: 1.35,
              color: score == 4
                  ? AppColors.successFor(isDark)
                  : AppColors.textMutedFor(isDark),
            ),
          ),
        ],
      ),
    );
  }
}
