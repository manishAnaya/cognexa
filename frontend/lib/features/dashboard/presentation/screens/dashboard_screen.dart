import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/app/theme/app_theme.dart';
import 'package:frontend/features/auth/presentation/providers/auth_providers.dart';
import 'package:frontend/features/chat/data/models/conversation_model.dart';
import 'package:frontend/features/chat/presentation/providers/conversation_providers.dart';
import 'package:frontend/features/documents/data/models/document_model.dart';
import 'package:frontend/features/documents/presentation/providers/document_providers.dart';
import 'package:frontend/features/workspaces/data/models/workspace_model.dart';
import 'package:frontend/features/workspaces/presentation/providers/workspace_providers.dart';
import 'package:intl/intl.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({
    required this.onOpenDocuments,
    required this.onOpenChat,
    super.key,
  });

  final VoidCallback onOpenDocuments;
  final VoidCallback onOpenChat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(workspacesProvider, (previous, next) {
      next.whenData((workspaces) {
        final selected = ref.read(selectedWorkspaceProvider);
        if (workspaces.isEmpty) {
          if (selected != null) {
            ref.read(selectedWorkspaceProvider.notifier).clear();
          }
        } else if (!workspaces.any(
          (workspace) => workspace.id == selected?.id,
        )) {
          ref.read(selectedWorkspaceProvider.notifier).select(workspaces.first);
        }
      });
    });

    final workspacesAsync = ref.watch(workspacesProvider);
    final user = ref.watch(currentUserProvider).asData?.value;
    final firstName = user?.fullName.trim().split(' ').first;

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
              constraints: const BoxConstraints(maxWidth: 1280),
              child: workspacesAsync.when(
                loading: () => const _LoadingState(),
                error: (error, stackTrace) => _ErrorState(
                  message: 'Unable to load your workspaces.',
                  onRetry: () => ref.invalidate(workspacesProvider),
                ),
                data: (workspaces) {
                  if (workspaces.isEmpty) {
                    return _EmptyWorkspaceState(
                      name: firstName ?? 'there',
                      onOpenDocuments: onOpenDocuments,
                    );
                  }

                  final selected = ref.watch(selectedWorkspaceProvider);
                  final workspace = workspaces.firstWhere(
                    (item) => item.id == selected?.id,
                    orElse: () => workspaces.first,
                  );
                  final documentsAsync = ref.watch(
                    documentsProvider(workspace.id),
                  );
                  final conversationsAsync = ref.watch(
                    conversationsProvider(workspace.id),
                  );

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _DashboardHeader(
                        firstName: firstName ?? 'there',
                        workspaces: workspaces,
                        selectedWorkspace: workspace,
                        onWorkspaceChanged: (value) {
                          if (value != null) {
                            ref
                                .read(selectedWorkspaceProvider.notifier)
                                .select(value);
                          }
                        },
                        onOpenDocuments: onOpenDocuments,
                      ),
                      const SizedBox(height: 24),
                      documentsAsync.when(
                        loading: () => const _LoadingState(compact: true),
                        error: (error, stackTrace) => _ErrorState(
                          message:
                              'Unable to load documents for this workspace.',
                          onRetry: () =>
                              ref.invalidate(documentsProvider(workspace.id)),
                        ),
                        data: (documents) => conversationsAsync.when(
                          loading: () => const _LoadingState(compact: true),
                          error: (error, stackTrace) => _ErrorState(
                            message: 'Unable to load conversations.',
                            onRetry: () => ref.invalidate(
                              conversationsProvider(workspace.id),
                            ),
                          ),
                          data: (conversations) => _DashboardData(
                            documents: documents,
                            conversations: conversations,
                            onOpenDocuments: onOpenDocuments,
                            onOpenChat: onOpenChat,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
    required this.firstName,
    required this.workspaces,
    required this.selectedWorkspace,
    required this.onWorkspaceChanged,
    required this.onOpenDocuments,
  });

  final String firstName;
  final List<WorkspaceModel> workspaces;
  final WorkspaceModel selectedWorkspace;
  final ValueChanged<WorkspaceModel?> onWorkspaceChanged;
  final VoidCallback onOpenDocuments;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 16,
      runSpacing: 16,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome back, $firstName',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 6),
            const Text(
              'Your workspace documents and conversations, in one place.',
              style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
            ),
          ],
        ),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: 230,
              child: DropdownButtonFormField<WorkspaceModel>(
                initialValue: selectedWorkspace,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Workspace',
                  isDense: true,
                ),
                items: workspaces
                    .map(
                      (workspace) => DropdownMenuItem(
                        value: workspace,
                        child: Text(
                          workspace.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: onWorkspaceChanged,
              ),
            ),
            FilledButton.icon(
              onPressed: onOpenDocuments,
              icon: const Icon(Icons.upload_file_rounded, size: 19),
              label: const Text('Upload documents'),
            ),
          ],
        ),
      ],
    );
  }
}

class _DashboardData extends StatelessWidget {
  const _DashboardData({
    required this.documents,
    required this.conversations,
    required this.onOpenDocuments,
    required this.onOpenChat,
  });

  final List<DocumentModel> documents;
  final List<ConversationModel> conversations;
  final VoidCallback onOpenDocuments;
  final VoidCallback onOpenChat;

  @override
  Widget build(BuildContext context) {
    final sortedDocuments = [...documents]
      ..sort(
        (a, b) =>
            (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)),
      );
    final sortedConversations = [...conversations]
      ..sort(
        (a, b) =>
            (b.updatedAt ?? DateTime(0)).compareTo(a.updatedAt ?? DateTime(0)),
      );
    final failed = documents.where((doc) => doc.hasFailed).length;
    final processed = documents.where((doc) => doc.isProcessed).length;
    final metrics = [
      _Metric('Documents', documents.length, Icons.description_outlined),
      _Metric('Processed', processed, Icons.check_circle_outline),
      _Metric('Failed', failed, Icons.error_outline),
      _Metric('Conversations', conversations.length, Icons.forum_outlined),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 900
                ? 4
                : constraints.maxWidth >= 520
                ? 2
                : 1;
            const spacing = 12.0;
            final width =
                (constraints.maxWidth - spacing * (columns - 1)) / columns;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: metrics
                  .map(
                    (metric) => SizedBox(
                      width: width,
                      child: _MetricCard(metric: metric),
                    ),
                  )
                  .toList(),
            );
          },
        ),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints) {
            final documentsPanel = _RecentDocuments(
              documents: sortedDocuments.take(5).toList(),
              onViewAll: onOpenDocuments,
            );
            final conversationsPanel = _RecentConversations(
              conversations: sortedConversations.take(5).toList(),
              onViewAll: onOpenChat,
            );

            if (constraints.maxWidth >= 900) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: documentsPanel),
                  const SizedBox(width: 16),
                  Expanded(flex: 2, child: conversationsPanel),
                ],
              );
            }

            return Column(
              children: [
                documentsPanel,
                const SizedBox(height: 16),
                conversationsPanel,
              ],
            );
          },
        ),
      ],
    );
  }
}

class _Metric {
  const _Metric(this.label, this.value, this.icon);

  final String label;
  final int value;
  final IconData icon;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric});

  final _Metric metric;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AppTheme.panelDecoration,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primarySoft,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(metric.icon, color: AppTheme.primary),
          ),
          const SizedBox(width: 13),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${metric.value}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                metric.label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecentDocuments extends StatelessWidget {
  const _RecentDocuments({required this.documents, required this.onViewAll});

  final List<DocumentModel> documents;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Recent documents',
      actionLabel: 'View all',
      onAction: onViewAll,
      child: documents.isEmpty
          ? const _EmptyPanel(message: 'No documents in this workspace yet.')
          : Column(
              children: documents
                  .map((document) => _DocumentRow(document: document))
                  .toList(),
            ),
    );
  }
}

class _DocumentRow extends StatelessWidget {
  const _DocumentRow({required this.document});

  final DocumentModel document;

  @override
  Widget build(BuildContext context) {
    final extension = document.fileType.toLowerCase();
    final (icon, color) = switch (extension) {
      '.pdf' ||
      'pdf' => (Icons.picture_as_pdf_outlined, const Color(0xFFDC2626)),
      '.docx' ||
      'docx' => (Icons.description_outlined, const Color(0xFF2563EB)),
      '.csv' || 'csv' => (Icons.table_chart_outlined, const Color(0xFF059669)),
      _ => (Icons.article_outlined, AppTheme.primary),
    };
    final created = document.createdAt == null
        ? 'Date unavailable'
        : DateFormat('MMM d, yyyy').format(document.createdAt!.toLocal());

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  document.filename,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 3),
                Text(
                  '${document.formattedSize} · $created',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _StatusLabel(status: document.status),
        ],
      ),
    );
  }
}

class _RecentConversations extends StatelessWidget {
  const _RecentConversations({
    required this.conversations,
    required this.onViewAll,
  });

  final List<ConversationModel> conversations;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Recent conversations',
      actionLabel: 'Open chat',
      onAction: onViewAll,
      child: conversations.isEmpty
          ? const _EmptyPanel(
              message: 'No conversations in this workspace yet.',
            )
          : Column(
              children: conversations
                  .map(
                    (conversation) => Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.forum_outlined,
                            color: AppTheme.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              conversation.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            conversation.updatedAt == null
                                ? ''
                                : DateFormat(
                                    'MMM d',
                                  ).format(conversation.updatedAt!.toLocal()),
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.actionLabel,
    required this.onAction,
    required this.child,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onAction;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.panelDecoration,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                TextButton(onPressed: onAction, child: Text(actionLabel)),
              ],
            ),
          ),
          const Divider(height: 1),
          child,
        ],
      ),
    );
  }
}

class _StatusLabel extends StatelessWidget {
  const _StatusLabel({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase();
    final (label, color, background) = switch (normalized) {
      'processed' => (
        'Processed',
        const Color(0xFF047857),
        const Color(0xFFECFDF5),
      ),
      'processing' => (
        'Processing',
        const Color(0xFFB45309),
        const Color(0xFFFFF7ED),
      ),
      'failed' => ('Failed', const Color(0xFFB91C1C), const Color(0xFFFEF2F2)),
      _ => ('Uploaded', AppTheme.primary, AppTheme.primarySoft),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
      ),
    );
  }
}

class _EmptyWorkspaceState extends StatelessWidget {
  const _EmptyWorkspaceState({
    required this.name,
    required this.onOpenDocuments,
  });

  final String name;
  final VoidCallback onOpenDocuments;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome, $name',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(32),
          decoration: AppTheme.panelDecoration,
          child: Column(
            children: [
              const Icon(
                Icons.folder_open_outlined,
                size: 44,
                color: AppTheme.primary,
              ),
              const SizedBox(height: 14),
              const Text(
                'Create a workspace to get started',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 7),
              const Text(
                'Workspaces keep your documents and conversations organized.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onOpenDocuments,
                icon: const Icon(Icons.add),
                label: const Text('Open documents'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(compact ? 48 : 96),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: AppTheme.panelDecoration,
      child: Column(
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
