import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/features/auth/presentation/providers/auth_providers.dart';

class LogoutButton extends ConsumerWidget {
  const LogoutButton({super.key, this.showLabel = true});

  final bool showLabel;

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('Are you sure you want to sign out of Cognexa?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );

    if (shouldLogout != true) return;

    await ref.read(authRepositoryProvider).logout();
    ref.invalidate(currentUserProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return showLabel
        ? TextButton.icon(
            onPressed: () => _logout(context, ref),
            icon: const Icon(Icons.logout_outlined),
            label: const Text('Sign out'),
          )
        : IconButton(
            tooltip: 'Sign out',
            onPressed: () => _logout(context, ref),
            icon: const Icon(Icons.logout_outlined),
          );
  }
}
