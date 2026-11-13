import 'package:material_ui/material_ui.dart';
import 'package:frontend/app/theme/app_theme.dart';
import 'package:frontend/features/chat/presentation/screens/chat_screen.dart';
import 'package:frontend/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:frontend/features/documents/presentation/screens/documents_screen.dart';
import 'package:frontend/features/settings/presentation/screens/settings_screen.dart';
import 'package:frontend/features/auth/presentation/widgets/logout_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/features/auth/presentation/providers/auth_providers.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int selectedIndex = 0;

  late final List<Widget> screens = [
    DashboardScreen(
      onOpenDocuments: () => _onSelect(1),
      onOpenChat: () => _onSelect(2),
    ),
    DocumentsScreen(),
    ChatScreen(onOpenDocuments: () => _onSelect(1)),
    SettingsScreen(),
  ];

  final destinations = const [
    NavigationDestination(
      icon: Icon(Icons.grid_view_outlined),
      selectedIcon: Icon(Icons.grid_view_rounded),
      label: 'Overview',
    ),
    NavigationDestination(
      icon: Icon(Icons.folder_outlined),
      selectedIcon: Icon(Icons.folder_rounded),
      label: 'Documents',
    ),
    NavigationDestination(
      icon: Icon(Icons.chat_bubble_outline),
      selectedIcon: Icon(Icons.chat_bubble_rounded),
      label: 'AI Chat',
    ),
    NavigationDestination(
      icon: Icon(Icons.settings_outlined),
      selectedIcon: Icon(Icons.settings_rounded),
      label: 'Settings',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 700;

    return Scaffold(
      appBar: isMobile
          ? AppBar(
              title: const _Brand(),
              actions: const [LogoutButton(showLabel: false)],
            )
          : null,
      body: Row(
        children: [
          if (!isMobile)
            _DesktopSidebar(
              selectedIndex: selectedIndex,
              destinations: destinations,
              onSelected: _onSelect,
            ),
          Expanded(
            child: Column(
              children: [
                if (!isMobile)
                  _DesktopTopBar(
                    title: destinations[selectedIndex].label,
                    onOpenAccount: () => _onSelect(3),
                  ),
                Expanded(
                  child: IndexedStack(index: selectedIndex, children: screens),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: isMobile
          ? DecoratedBox(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppTheme.border)),
              ),
              child: NavigationBar(
                selectedIndex: selectedIndex,
                onDestinationSelected: _onSelect,
                destinations: destinations,
              ),
            )
          : null,
    );
  }

  void _onSelect(int index) {
    setState(() => selectedIndex = index);
  }
}

// ─────────────────────────────── Sidebar ───────────────────────────────

class _DesktopSidebar extends StatelessWidget {
  const _DesktopSidebar({
    required this.selectedIndex,
    required this.destinations,
    required this.onSelected,
  });

  final int selectedIndex;
  final List<NavigationDestination> destinations;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 248,
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(right: BorderSide(color: AppTheme.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(22, 24, 16, 28),
            child: _Brand(),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: destinations.length,
              itemBuilder: (context, i) => _NavItem(
                destination: destinations[i],
                selected: i == selectedIndex,
                onTap: () => onSelected(i),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final NavigationDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool hovering = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final color = selected ? AppTheme.primary : AppTheme.textSecondary;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => hovering = true),
      onExit: (_) => setState(() => hovering = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.primarySoft
                : hovering
                ? const Color(0xFFF3F4F8)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              IconTheme(
                data: IconThemeData(color: color, size: 20),
                child: selected
                    ? (widget.destination.selectedIcon ??
                          widget.destination.icon)
                    : widget.destination.icon,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.destination.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: selected ? AppTheme.primary : AppTheme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────── Top bar ───────────────────────────────

class _DesktopTopBar extends ConsumerWidget {
  const _DesktopTopBar({required this.title, required this.onOpenAccount});

  final String title;
  final VoidCallback onOpenAccount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).asData?.value;
    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: const BoxDecoration(
        color: AppTheme.background,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const Spacer(),
          if (user != null) ...[
            InkWell(
              onTap: onOpenAccount,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Row(
                  children: [
                    _Avatar(name: user.fullName),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          user.fullName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          user.email,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 4),
            const LogoutButton(showLabel: false),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────── Shared bits ───────────────────────────────

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppTheme.primary,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.auto_awesome, color: Colors.white, size: 19),
        ),
        const SizedBox(width: 10),
        const Text(
          'Cognexa',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 18,
      backgroundColor: AppTheme.primarySoft,
      child: Text(
        name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase(),
        style: const TextStyle(
          color: AppTheme.primary,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
    );
  }
}
