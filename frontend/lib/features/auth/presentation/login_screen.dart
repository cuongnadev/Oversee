import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/l10n/app_localizations.dart';
import 'package:frontend/core/routing/route_names.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/features/auth/application/auth_provider.dart';
import 'package:frontend/features/auth/presentation/widgets/auth_modernist_layout.dart';
import 'package:frontend/shared/widgets/widgets.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController(text: 'demo@oversee.local');
  final _passwordController = TextEditingController(text: 'Password123!');
  final _formKey = GlobalKey<FormState>();

  static final RegExp _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (ref.read(authNotifierProvider).isLoading) return;
    ref.read(authNotifierProvider.notifier).clearError();

    if (_formKey.currentState?.validate() ?? false) {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      final success = await ref.read(authNotifierProvider.notifier).login(
            email: email,
            password: password,
          );

      if (success && mounted) {
        context.go(AppRoutes.workspaces);
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
      heroHeadline: 'Clarity across every sprint.',
      heroSubtitle:
          'One structured workspace for issues, Kanban boards, timelines, and team delivery.',
      formTitle: 'Welcome back',
      formSubtitle: 'Sign in to manage your workspaces and projects.',
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
              },
            ),
            AppTextFormField(
              controller: _emailController,
              label: 'Email Address',
              isRequired: true,
              hintText: 'name@example.com',
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              prefixIcon: const Icon(Icons.email_outlined, size: 18.0),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 13.0),
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
            const SizedBox(height: 16.0),
            AppTextFormField(
              controller: _passwordController,
              label: 'Password',
              isRequired: true,
              isPassword: true,
              hintText: '••••••••',
              textInputAction: TextInputAction.done,
              prefixIcon: const Icon(Icons.lock_outline, size: 18.0),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 13.0),
              onFieldSubmitted: authState.isLoading ? null : (_) => _handleLogin(),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your password';
                }
                return null;
              },
            ),
            const SizedBox(height: 24.0),
            AppPrimaryButton(
              label: 'Sign In',
              isFullWidth: true,
              height: 44.0,
              isLoading: authState.isLoading,
              onPressed: _handleLogin,
            ),
          ],
        ),
      ),
      footerChild: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            "Don't have an account? ",
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
              context.go(AppRoutes.register);
            },
            child: Text(context.l10n.signUp),
          ),
        ],
      ),
    );
  }
}
