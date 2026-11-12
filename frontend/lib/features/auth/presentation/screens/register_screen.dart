import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/app/theme/app_theme.dart';
import 'package:frontend/features/auth/presentation/providers/auth_providers.dart';
import 'auth_layout.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String _getErrorMessage(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['detail'] != null) {
        return data['detail'].toString();
      }
      if (error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.connectionTimeout) {
        return 'Unable to connect to the server. Please try again.';
      }
    }
    return 'Unable to create your account. Please try again.';
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ref
          .read(authRepositoryProvider)
          .register(
            fullName: _nameController.text.trim(),
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account created successfully. Please sign in.'),
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        setState(() => _errorMessage = _getErrorMessage(error));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      title: 'Create your account',
      subtitle: 'Upload your documents and start asking questions in minutes.',
      footer: AuthFooter(
        prompt: 'Already have an account?',
        action: 'Sign in',
        onPressed: () => Navigator.of(context).pop(),
      ),
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AuthField(
                controller: _nameController,
                label: 'Full name',
                hint: 'Your full name',
                icon: Icons.person_outline_rounded,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Full name is required.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 18),
              AuthField(
                controller: _emailController,
                label: 'Email address',
                hint: 'you@example.com',
                icon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                validator: (value) {
                  final email = value?.trim() ?? '';
                  if (email.isEmpty) return 'Email is required.';
                  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
                    return 'Enter a valid email address.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 18),
              AuthField(
                controller: _passwordController,
                label: 'Password',
                hint: 'At least 8 characters',
                icon: Icons.lock_outline_rounded,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                onChanged: (_) => setState(() {}),
                suffix: PasswordToggle(
                  obscured: _obscurePassword,
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Password is required.';
                  }
                  if (value.length < 8) {
                    return 'Password must be at least 8 characters.';
                  }
                  return null;
                },
              ),
              _PasswordStrength(password: _passwordController.text),
              const SizedBox(height: 18),
              AuthField(
                controller: _confirmPasswordController,
                label: 'Confirm password',
                hint: 'Re-enter your password',
                icon: Icons.lock_outline_rounded,
                obscureText: _obscureConfirmPassword,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _isLoading ? null : _register(),
                suffix: PasswordToggle(
                  obscured: _obscureConfirmPassword,
                  onPressed: () => setState(
                    () => _obscureConfirmPassword = !_obscureConfirmPassword,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please confirm your password.';
                  }
                  if (value != _passwordController.text) {
                    return 'Passwords do not match.';
                  }
                  return null;
                },
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                AuthErrorBanner(message: _errorMessage!),
              ],
              const SizedBox(height: 26),
              AuthSubmitButton(
                label: 'Create account',
                isLoading: _isLoading,
                onPressed: _register,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Four-segment meter. Hidden until the user starts typing.
class _PasswordStrength extends StatelessWidget {
  const _PasswordStrength({required this.password});

  final String password;

  int get _score {
    if (password.isEmpty) return 0;
    var score = 0;
    if (password.length >= 8) score++;
    if (password.length >= 12) score++;
    if (RegExp(r'[A-Z]').hasMatch(password) &&
        RegExp(r'[a-z]').hasMatch(password)) {
      score++;
    }
    if (RegExp(r'\d').hasMatch(password) &&
        RegExp(r'[^A-Za-z0-9]').hasMatch(password)) {
      score++;
    }
    return score.clamp(1, 4);
  }

  @override
  Widget build(BuildContext context) {
    final score = _score;
    final labels = ['', 'Weak', 'Fair', 'Good', 'Strong'];
    final colors = [
      AppTheme.border,
      const Color(0xFFEF4444),
      const Color(0xFFF59E0B),
      const Color(0xFF84CC16),
      AppTheme.success,
    ];

    return AnimatedSize(
      duration: const Duration(milliseconds: 180),
      alignment: Alignment.topCenter,
      child: password.isEmpty
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                children: [
                  for (var i = 1; i <= 4; i++) ...[
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 4,
                        decoration: BoxDecoration(
                          color: i <= score ? colors[score] : AppTheme.border,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    if (i < 4) const SizedBox(width: 4),
                  ],
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 48,
                    child: Text(
                      labels[score],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colors[score],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
