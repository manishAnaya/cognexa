// Put at: lib/features/auth/presentation/widgets/auth_layout.dart
import 'package:flutter/material.dart';
import 'package:frontend/app/theme/app_theme.dart';

/// Split-screen on wide layouts (brand panel + form), single column on mobile.
class AuthLayout extends StatelessWidget {
  const AuthLayout({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    required this.footer,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final split = constraints.maxWidth >= 900;
          final form = _FormPane(
            title: title,
            subtitle: subtitle,
            footer: footer,
            showBrand: !split,
            child: child,
          );

          if (!split) return SafeArea(child: form);

          return Row(
            children: [
              const Expanded(flex: 11, child: _BrandPanel()),
              Expanded(flex: 9, child: SafeArea(child: form)),
            ],
          );
        },
      ),
    );
  }
}

class _FormPane extends StatelessWidget {
  const _FormPane({
    required this.title,
    required this.subtitle,
    required this.child,
    required this.footer,
    required this.showBrand,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget footer;
  final bool showBrand;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showBrand) ...[
                const Align(
                  alignment: Alignment.centerLeft,
                  child: AuthBrand(),
                ),
                const SizedBox(height: 36),
              ],
              Text(title, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 15,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 28),
              child,
              const SizedBox(height: 20),
              footer,
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────── Brand panel ───────────────────────────

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(48),
      decoration: const BoxDecoration(
        color: AppTheme.ink,
        gradient: RadialGradient(
          center: Alignment.topRight,
          radius: 1.3,
          colors: [Color(0xFF4338CA), Color(0xFF1E1B4B), AppTheme.ink],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AuthBrand(light: true),
          const Spacer(),
          const Text(
            'Your documents,\nanswered.',
            style: TextStyle(
              fontSize: 44,
              height: 1.05,
              fontWeight: FontWeight.w700,
              letterSpacing: -1.8,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Ask a question. Get an answer with the exact source behind it.',
            style: TextStyle(
              fontSize: 15,
              height: 1.5,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 36),
          const _AnswerPreview(),
          const Spacer(),
        ],
      ),
    );
  }
}

/// A small, static example of the product's core promise: answer + citation.
class _AnswerPreview extends StatelessWidget {
  const _AnswerPreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 440),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What are the launch requirements?',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Launch needs SSO, audit logs and a 99.9% uptime target.',
            style: TextStyle(
              fontSize: 15,
              height: 1.45,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SourceChip(
                icon: Icons.picture_as_pdf_outlined,
                label: 'Product Requirements · p.4',
              ),
              _SourceChip(
                icon: Icons.description_outlined,
                label: 'Technical Architecture · §2',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SourceChip extends StatelessWidget {
  const _SourceChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: ShapeDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        shape: const StadiumBorder(),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white.withValues(alpha: 0.85)),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────── Shared widgets ───────────────────────────

class AuthBrand extends StatelessWidget {
  const AuthBrand({super.key, this.light = false});

  final bool light;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 38,
          width: 38,
          decoration: BoxDecoration(
            color: light ? Colors.white : AppTheme.primary,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(
            Icons.auto_awesome,
            color: light ? AppTheme.primary : Colors.white,
            size: 21,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'Cognexa',
          style: TextStyle(
            color: light ? Colors.white : AppTheme.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.7,
          ),
        ),
      ],
    );
  }
}

class AuthField extends StatelessWidget {
  const AuthField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.obscureText = false,
    this.suffix,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.textInputAction,
    this.autofillHints,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffix;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          validator: validator,
          onChanged: onChanged,
          onFieldSubmitted: onSubmitted,
          textInputAction: textInputAction,
          autofillHints: autofillHints,
          style: const TextStyle(fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 20, color: AppTheme.textSecondary),
            suffixIcon: suffix,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
      ],
    );
  }
}

class PasswordToggle extends StatelessWidget {
  const PasswordToggle({
    super.key,
    required this.obscured,
    required this.onPressed,
  });

  final bool obscured;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: obscured ? 'Show password' : 'Hide password',
      onPressed: onPressed,
      icon: Icon(
        obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        size: 20,
        color: AppTheme.textSecondary,
      ),
    );
  }
}

class AuthSubmitButton extends StatelessWidget {
  const AuthSubmitButton({
    super.key,
    required this.label,
    required this.isLoading,
    required this.onPressed,
  });

  final String label;
  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: FilledButton(
        onPressed: isLoading ? null : onPressed,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: isLoading
              ? const SizedBox(
                  key: ValueKey('loading'),
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(label, key: const ValueKey('label')),
        ),
      ),
    );
  }
}

class AuthErrorBanner extends StatelessWidget {
  const AuthErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class AuthFooter extends StatelessWidget {
  const AuthFooter({
    super.key,
    required this.prompt,
    required this.action,
    required this.onPressed,
  });

  final String prompt;
  final String action;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(prompt, style: const TextStyle(color: AppTheme.textSecondary)),
        TextButton(onPressed: onPressed, child: Text(action)),
      ],
    );
  }
}
