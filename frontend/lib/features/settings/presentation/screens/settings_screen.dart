import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/app/theme/app_theme.dart';
import 'package:frontend/features/auth/presentation/providers/auth_providers.dart';
import 'package:frontend/features/auth/presentation/widgets/logout_button.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 650;
        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: narrow ? 16 : 32,
            vertical: narrow ? 20 : 28,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Account',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Your profile and sign-in details.',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  userAsync.when(
                    loading: () => Container(
                      height: 240,
                      decoration: AppTheme.panelDecoration,
                      child: const Center(
                        child: SizedBox(
                          width: 26,
                          height: 26,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                      ),
                    ),
                    error: (error, stackTrace) => _StateCard(
                      icon: Icons.cloud_off_outlined,
                      title: 'Account unavailable',
                      subtitle:
                          'We couldn’t load your profile. Check your '
                          'connection and try again.',
                      action: OutlinedButton.icon(
                        onPressed: () => ref.invalidate(currentUserProvider),
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Retry'),
                      ),
                    ),
                    data: (user) {
                      if (user == null) {
                        return const _StateCard(
                          icon: Icons.person_off_outlined,
                          title: 'No active account',
                          subtitle: 'Sign in again to load account details.',
                        );
                      }

                      final name = user.fullName.trim();
                      final initial = name.isEmpty
                          ? '?'
                          : name[0].toUpperCase();

                      return Column(
                        children: [
                          _ProfilePanel(
                            initial: initial,
                            fullName: user.fullName,
                            email: user.email,
                            isActive: user.isActive,
                            narrow: narrow,
                          ),
                          const SizedBox(height: 16),
                          _SessionPanel(narrow: narrow),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────── Profile ───────────────────────────────

class _ProfilePanel extends StatelessWidget {
  const _ProfilePanel({
    required this.initial,
    required this.fullName,
    required this.email,
    required this.isActive,
    required this.narrow,
  });

  final String initial;
  final String fullName;
  final String email;
  final bool isActive;
  final bool narrow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: AppTheme.panelDecoration,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner echoes the dashboard hero / auth panel.
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                height: 96,
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: AppTheme.ink,
                  gradient: RadialGradient(
                    center: Alignment.topRight,
                    radius: 1.6,
                    colors: [
                      Color(0xFF4338CA),
                      Color(0xFF1E1B4B),
                      AppTheme.ink,
                    ],
                    stops: [0.0, 0.55, 1.0],
                  ),
                ),
              ),
              Positioned(
                left: 24,
                bottom: -36,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: AppTheme.surface,
                    shape: BoxShape.circle,
                  ),
                  child: CircleAvatar(
                    radius: 32,
                    backgroundColor: AppTheme.primarySoft,
                    child: Text(
                      initial,
                      style: const TextStyle(
                        color: AppTheme.primary,
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 48),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 10,
              spacing: 12,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      email,
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
                _AccountStatus(isActive: isActive),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Divider(),
          _InfoRow(
            icon: Icons.badge_outlined,
            label: 'Full name',
            value: fullName,
            narrow: narrow,
          ),
          const Divider(indent: 24, endIndent: 24),
          _InfoRow(
            icon: Icons.mail_outline_rounded,
            label: 'Email address',
            value: email,
            narrow: narrow,
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.narrow,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool narrow;

  @override
  Widget build(BuildContext context) {
    final labelWidget = Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: AppTheme.textSecondary,
      ),
    );
    final valueWidget = SelectableText(
      value,
      style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 14, 12, 14),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.textSecondary),
          const SizedBox(width: 14),
          Expanded(
            child: narrow
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      labelWidget,
                      const SizedBox(height: 3),
                      valueWidget,
                    ],
                  )
                : Row(
                    children: [
                      SizedBox(width: 150, child: labelWidget),
                      Expanded(child: valueWidget),
                    ],
                  ),
          ),
          IconButton(
            tooltip: 'Copy',
            icon: const Icon(
              Icons.copy_rounded,
              size: 18,
              color: AppTheme.textSecondary,
            ),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(
                    content: Text('$label copied'),
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 2),
                  ),
                );
            },
          ),
        ],
      ),
    );
  }
}

class _AccountStatus extends StatelessWidget {
  const _AccountStatus({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppTheme.success : const Color(0xFFB91C1C);
    final background = isActive
        ? AppTheme.successSoft
        : const Color(0xFFFEF2F2);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: ShapeDecoration(
        color: background,
        shape: const StadiumBorder(),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            isActive ? 'Active' : 'Inactive',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────── Session ───────────────────────────────

class _SessionPanel extends StatelessWidget {
  const _SessionPanel({required this.narrow});

  final bool narrow;

  @override
  Widget build(BuildContext context) {
    const text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sign out',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        SizedBox(height: 3),
        Text(
          'End your session on this device.',
          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
        ),
      ],
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.panelDecoration,
      child: narrow
          ? const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [text, SizedBox(height: 16), LogoutButton()],
            )
          : const Row(
              children: [
                Icon(Icons.logout_rounded, color: AppTheme.textSecondary),
                SizedBox(width: 14),
                Expanded(child: text),
                LogoutButton(),
              ],
            ),
    );
  }
}

// ─────────────────────────────── Empty / error ───────────────────────────────

class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      decoration: AppTheme.panelDecoration,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppTheme.primarySoft,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: AppTheme.primary, size: 26),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.45,
              color: AppTheme.textSecondary,
            ),
          ),
          if (action != null) ...[const SizedBox(height: 20), action!],
        ],
      ),
    );
  }
}
