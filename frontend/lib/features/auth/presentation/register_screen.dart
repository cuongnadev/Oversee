import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/routing/route_names.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/features/auth/application/auth_provider.dart';
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
    // Clear previous errors
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final authState = ref.watch(authNotifierProvider);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440.0),
            child: AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 36.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Brand Logo
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8.0),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                          child: const Icon(Icons.hub_rounded, color: Colors.white, size: 28.0),
                        ),
                        const SizedBox(width: 12.0),
                        Text(
                          'Oversee',
                          style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20.0),
                    Text(
                      'Create an Account',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6.0),
                    Text(
                      'Get started with Oversee project management',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(height: 24.0),

                    // Error Alert Banner
                    if (authState.hasError) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
                        decoration: BoxDecoration(
                          color: AppColors.errorLight.withValues(alpha: isDark ? 0.2 : 0.8),
                          borderRadius: BorderRadius.circular(8.0),
                          border: Border.all(
                            color: AppColors.error.withValues(alpha: 0.5),
                            width: 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              color: AppColors.error,
                              size: 20.0,
                            ),
                            const SizedBox(width: 10.0),
                            Expanded(
                              child: Text(
                                authState.errorMessage!,
                                style: TextStyle(
                                  fontSize: 13.0,
                                  color: isDark ? const Color(0xFFFCA5A5) : AppColors.error,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, size: 16.0),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () {
                                ref.read(authNotifierProvider.notifier).clearError();
                                setState(() => _emailServerError = null);
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16.0),
                    ],

                    // Full Name Field
                    AppTextFormField(
                      controller: _nameController,
                      label: 'Full Name',
                      isRequired: true,
                      hintText: 'John Doe',
                      textInputAction: TextInputAction.next,
                      prefixIcon: const Icon(Icons.person_outline_rounded, size: 20.0),
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
                    const SizedBox(height: 16.0),

                    // Email Address Field
                    AppTextFormField(
                      controller: _emailController,
                      label: 'Email Address',
                      isRequired: true,
                      hintText: 'name@example.com',
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      prefixIcon: const Icon(Icons.email_outlined, size: 20.0),
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
                    const SizedBox(height: 16.0),

                    // Password Field
                    AppTextFormField(
                      controller: _passwordController,
                      label: 'Password',
                      isRequired: true,
                      isPassword: true,
                      hintText: '••••••••',
                      helperText: 'Min 8 chars with uppercase, lowercase & number',
                      textInputAction: TextInputAction.next,
                      prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20.0),
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
                    const SizedBox(height: 16.0),

                    // Confirm Password Field
                    AppTextFormField(
                      controller: _confirmPasswordController,
                      label: 'Confirm Password',
                      isRequired: true,
                      isPassword: true,
                      hintText: '••••••••',
                      textInputAction: TextInputAction.done,
                      prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20.0),
                      onFieldSubmitted: (_) => _handleRegister(),
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
                    const SizedBox(height: 24.0),

                    // Submit Button
                    AppPrimaryButton(
                      label: 'Create Account',
                      isFullWidth: true,
                      isLoading: authState.isLoading,
                      onPressed: _handleRegister,
                    ),
                    const SizedBox(height: 20.0),

                    // Link back to Login
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'Already have an account? ',
                          style: theme.textTheme.bodySmall,
                        ),
                        TextButton(
                          onPressed: () {
                            ref.read(authNotifierProvider.notifier).clearError();
                            context.go(AppRoutes.login);
                          },
                          child: const Text('Sign In'),
                        ),
                      ],
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
}
