import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:frontend/app/theme/app_theme.dart';
import 'package:frontend/features/documents/presentation/providers/document_providers.dart';
import 'package:frontend/features/workspaces/data/models/workspace_model.dart';
import 'package:frontend/features/workspaces/presentation/providers/workspace_providers.dart';
import '../../data/models/conversation_model.dart';
import '../../data/models/message_model.dart';
import '../providers/conversation_providers.dart';

String _formatTime(DateTime? value) =>
    value == null ? '' : DateFormat('hh:mm a').format(value.toLocal());

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({required this.onOpenDocuments, super.key});

  final VoidCallback onOpenDocuments;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  String? _activeConversationId;
  ConversationModel? _newConversation;
  String? _draftTitle;
  bool _isSending = false;
  bool _isCreatingFirstMessage = false;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _newChat() {
    setState(() {
      _activeConversationId = null;
      _draftTitle = null;
      _messageController.clear();
    });
  }

  Future<void> _deleteConversation(
    String workspaceId,
    ConversationModel conversation,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete conversation?'),
        content: Text(
          '“${conversation.title}” and its messages will be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await ref
          .read(conversationRepositoryProvider)
          .deleteConversation(
            workspaceId: workspaceId,
            conversationId: conversation.id,
          );

      setState(() {
        if (_activeConversationId == conversation.id) {
          _activeConversationId = null;
          _draftTitle = null;
        }
        if (_newConversation?.id == conversation.id) {
          _newConversation = null;
        }
      });
      ref.invalidate(conversationsProvider(workspaceId));

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Conversation deleted.')));
      }
    } catch (error) {
      _showError(error);
    }
  }

  void _selectConversation(String id) {
    setState(() {
      _activeConversationId = id;
      _draftTitle = null;
    });

    _scrollToBottom();
  }

  Future<void> _sendMessage(String workspaceId) async {
    final query = _messageController.text.trim();

    if (query.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    _messageController.clear();

    try {
      var conversationId = _activeConversationId;

      // Create a conversation automatically for the first message.
      if (conversationId == null) {
        final title = query.length > 60
            ? '${query.substring(0, 57).trimRight()}...'
            : query;
        setState(() {
          _draftTitle = title;
          _isCreatingFirstMessage = true;
        });
        final conversation = await ref
            .read(conversationRepositoryProvider)
            .createConversation(workspaceId: workspaceId, title: title);

        conversationId = conversation.id;

        if (!mounted) return;

        setState(() {
          _activeConversationId = conversationId;
          _draftTitle = conversation.title;
          _newConversation = conversation;
        });
      }

      await ref
          .read(conversationRepositoryProvider)
          .sendMessage(
            workspaceId: workspaceId,
            conversationId: conversationId,
            query: query,
          );

      if (!mounted) return;

      ref.invalidate(conversationMessagesProvider(workspaceId, conversationId));
      ref.invalidate(conversationsProvider(workspaceId));

      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        _messageController.text = query;
        if (e is DioException && e.response?.statusCode == 409) {
          ref.invalidate(documentsProvider(workspaceId));
        }
        if (_activeConversationId == null) {
          setState(() => _draftTitle = null);
        }
        final failedConversationId = _activeConversationId;
        if (failedConversationId != null) {
          ref.invalidate(
            conversationMessagesProvider(workspaceId, failedConversationId),
          );
          ref.invalidate(conversationsProvider(workspaceId));
        }
        _showError(e);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
          _isCreatingFirstMessage = false;
        });
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  void _showError(Object error) {
    var message = 'Something went wrong. Please try again.';

    if (error is DioException) {
      final detail = error.response?.data;

      if (detail is Map && detail['detail'] != null) {
        message = detail['detail'].toString();
      } else if (error.response == null) {
        message = 'Unable to connect to the server.';
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(chatDraftProvider, (previous, question) {
      if (question == null) return;
      _messageController.text = question;
      ref.read(chatDraftProvider.notifier).clear();
      _scrollToBottom();
    });

    ref.listen(selectedWorkspaceProvider, (previous, next) {
      if (previous?.id != next?.id) {
        setState(() {
          _activeConversationId = null;
          _newConversation = null;
          _draftTitle = null;
          _messageController.clear();
        });
      }
    });

    final workspacesAsync = ref.watch(workspacesProvider);
    final selectedWorkspace = ref.watch(selectedWorkspaceProvider);

    return workspacesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => _CenteredMessage(
        icon: Icons.cloud_off_outlined,
        title: 'Unable to load workspaces',
        subtitle: '$error',
        action: OutlinedButton.icon(
          onPressed: () => ref.invalidate(workspacesProvider),
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Retry'),
        ),
      ),
      data: (workspaces) {
        if (workspaces.isEmpty) {
          return const _CenteredMessage(
            icon: Icons.folder_open_outlined,
            title: 'No workspace yet',
            subtitle: 'Create a workspace before starting a chat.',
          );
        }

        final workspace = workspaces.firstWhere(
          (item) => item.id == selectedWorkspace?.id,
          orElse: () => workspaces.first,
        );
        final workspacePicker = _WorkspacePicker(
          workspaces: workspaces,
          selectedWorkspace: workspace,
          onChanged: (value) {
            if (value != null) {
              ref.read(selectedWorkspaceProvider.notifier).select(value);
            }
          },
        );

        final documentsAsync = ref.watch(documentsProvider(workspace.id));
        if (documentsAsync.hasError) {
          return _CenteredMessage(
            icon: Icons.cloud_off_outlined,
            title: 'Unable to check this workspace’s documents',
            topBar: workspacePicker,
            action: OutlinedButton.icon(
              onPressed: () => ref.invalidate(documentsProvider(workspace.id)),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
            ),
          );
        }
        if (documentsAsync.isLoading && documentsAsync.value == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if ((documentsAsync.value ?? const []).isEmpty) {
          return _CenteredMessage(
            icon: Icons.upload_file_outlined,
            title: 'Upload a document to start chatting',
            topBar: workspacePicker,
            subtitle:
                'This workspace needs at least one document before Cognexa can answer questions.',
            action: FilledButton.icon(
              onPressed: widget.onOpenDocuments,
              icon: const Icon(Icons.upload_file_outlined, size: 19),
              label: const Text('Go to documents'),
            ),
          );
        }

        final conversationsAsync = ref.watch(
          conversationsProvider(workspace.id),
        );

        final conversations =
            conversationsAsync.value ?? const <ConversationModel>[];
        final visibleConversations = [...conversations];
        final optimisticConversation = _newConversation;
        if (optimisticConversation != null &&
            optimisticConversation.workspaceId == workspace.id &&
            !visibleConversations.any(
              (item) => item.id == optimisticConversation.id,
            )) {
          visibleConversations.insert(0, optimisticConversation);
        }
        final activeConversation = visibleConversations
            .where((c) => c.id == _activeConversationId)
            .firstOrNull;

        final messagesAsync =
            _activeConversationId == null || _isCreatingFirstMessage
            ? null
            : ref.watch(
                conversationMessagesProvider(
                  workspace.id,
                  _activeConversationId!,
                ),
              );

        return LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 1000;
            final isNarrow = constraints.maxWidth < 600;

            return Row(
              children: [
                if (isWide)
                  SizedBox(
                    width: 280,
                    child: _ConversationSidebar(
                      conversations: visibleConversations,
                      activeId: _activeConversationId,
                      onNewChat: _newChat,
                      onSelect: _selectConversation,
                      onDelete: (conversation) =>
                          _deleteConversation(workspace.id, conversation),
                    ),
                  ),
                Expanded(
                  child: Column(
                    children: [
                      if (conversationsAsync.isLoading && conversations.isEmpty)
                        const LinearProgressIndicator(minHeight: 2),
                      if (conversationsAsync.hasError)
                        _ConversationLoadNotice(
                          onRetry: () => ref.invalidate(
                            conversationsProvider(workspace.id),
                          ),
                        ),
                      _ChatHeader(
                        title:
                            activeConversation?.title ??
                            _draftTitle ??
                            'New conversation',
                        isNarrow: isNarrow,
                        onHistory: () =>
                            _showHistory(visibleConversations, workspace.id),
                        workspacePicker: workspacePicker,
                      ),
                      Expanded(
                        child: _ChatBody(
                          messagesAsync: messagesAsync,
                          isSending: _isSending,
                          isNarrow: isNarrow,
                          messageController: _messageController,
                          scrollController: _scrollController,
                          onSend: () => _sendMessage(workspace.id),
                          onRetry: () {
                            final conversationId = _activeConversationId;
                            if (conversationId != null) {
                              ref.invalidate(
                                conversationMessagesProvider(
                                  workspace.id,
                                  conversationId,
                                ),
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showHistory(List<ConversationModel> conversations, String workspaceId) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.7,
          child: _ConversationSidebar(
            showRightBorder: false,
            conversations: conversations,
            activeId: _activeConversationId,
            onNewChat: () {
              Navigator.pop(sheetContext);
              _newChat();
            },
            onSelect: (id) {
              Navigator.pop(sheetContext);
              _selectConversation(id);
            },
            onDelete: (conversation) {
              Navigator.pop(sheetContext);
              _deleteConversation(workspaceId, conversation);
            },
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Centered states (errors, empty, no documents)
// ---------------------------------------------------------------------

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
    this.topBar,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;
  final Widget? topBar;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (topBar != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Align(alignment: Alignment.centerRight, child: topBar),
          ),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: AppTheme.primarySoft,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(icon, size: 28, color: AppTheme.primary),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        subtitle!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          height: 1.5,
                          fontSize: 14,
                        ),
                      ),
                    ],
                    if (action != null) ...[
                      const SizedBox(height: 22),
                      action!,
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------
// Conversation sidebar
// ---------------------------------------------------------------------

class _ConversationSidebar extends StatelessWidget {
  const _ConversationSidebar({
    required this.conversations,
    required this.activeId,
    required this.onNewChat,
    required this.onSelect,
    required this.onDelete,
    this.showRightBorder = true,
  });

  final List<ConversationModel> conversations;
  final String? activeId;
  final VoidCallback onNewChat;
  final ValueChanged<String> onSelect;
  final ValueChanged<ConversationModel> onDelete;
  final bool showRightBorder;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: showRightBorder
            ? const Border(right: BorderSide(color: AppTheme.border))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onNewChat,
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text('New conversation'),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 14, 20, 8),
            child: Text(
              'Recent',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: conversations.isEmpty
                ? const Center(
                    child: Text(
                      'No conversations yet',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    itemCount: conversations.length,
                    itemBuilder: (context, index) {
                      final item = conversations[index];
                      return _ConversationTile(
                        title: item.title,
                        selected: item.id == activeId,
                        onTap: () => onSelect(item.id),
                        onDelete: () => onDelete(item),
                      );
                    },
                  ),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.verified_outlined,
                  color: AppTheme.textSecondary,
                  size: 18,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Answers are grounded in your workspace documents.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConversationTile extends StatefulWidget {
  const _ConversationTile({
    required this.title,
    required this.selected,
    required this.onTap,
    required this.onDelete,
  });

  final String title;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  State<_ConversationTile> createState() => _ConversationTileState();
}

class _ConversationTileState extends State<_ConversationTile> {
  bool hovering = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;

    return MouseRegion(
      onEnter: (_) => setState(() => hovering = true),
      onExit: (_) => setState(() => hovering = false),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Material(
          color: selected
              ? AppTheme.primarySoft
              : hovering
              ? const Color(0xFFF3F4F8)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: selected
                              ? AppTheme.primary
                              : AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Conversation actions',
                    padding: EdgeInsets.zero,
                    iconSize: 18,
                    color: Colors.white,
                    surfaceTintColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: AppTheme.border),
                    ),
                    icon: Icon(
                      Icons.more_horiz_rounded,
                      color: selected || hovering
                          ? AppTheme.textSecondary
                          : AppTheme.textSecondary.withValues(alpha: 0.45),
                    ),
                    onSelected: (action) {
                      if (action == 'delete') widget.onDelete();
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete_outline_rounded,
                              size: 18,
                              color: Color(0xFFDC2626),
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Delete conversation',
                              style: TextStyle(color: Color(0xFFDC2626)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({
    required this.title,
    required this.isNarrow,
    required this.onHistory,
    required this.workspacePicker,
  });

  final String title;
  final bool isNarrow;
  final VoidCallback onHistory;
  final Widget workspacePicker;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: EdgeInsets.symmetric(horizontal: isNarrow ? 8 : 24),
      decoration: const BoxDecoration(
        color: AppTheme.background,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          if (isNarrow)
            IconButton(
              onPressed: onHistory,
              tooltip: 'Conversation history',
              icon: const Icon(Icons.history_rounded),
            ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: isNarrow ? 4 : 0),
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
            ),
          ),
          SizedBox(width: isNarrow ? 4 : 12),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isNarrow ? 150 : 240),
            child: workspacePicker,
          ),
          SizedBox(width: isNarrow ? 4 : 12),
        ],
      ),
    );
  }
}

class _WorkspacePicker extends StatelessWidget {
  const _WorkspacePicker({
    required this.workspaces,
    required this.selectedWorkspace,
    required this.onChanged,
  });

  final List<WorkspaceModel> workspaces;
  final WorkspaceModel selectedWorkspace;
  final ValueChanged<WorkspaceModel?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.folder_outlined, size: 17, color: AppTheme.primary),
        const SizedBox(width: 6),
        Expanded(
          child: DropdownButtonHideUnderline(
            child: DropdownButton<WorkspaceModel>(
              value: selectedWorkspace,
              isExpanded: true,
              isDense: true,
              iconSize: 18,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              items: workspaces
                  .map(
                    (workspace) => DropdownMenuItem<WorkspaceModel>(
                      value: workspace,
                      child: Text(
                        workspace.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------
// Chat body
// ---------------------------------------------------------------------

class _ChatBody extends StatelessWidget {
  const _ChatBody({
    required this.messagesAsync,
    required this.isSending,
    required this.isNarrow,
    required this.messageController,
    required this.scrollController,
    required this.onSend,
    required this.onRetry,
  });

  final AsyncValue<List<MessageModel>>? messagesAsync;
  final bool isSending;
  final bool isNarrow;
  final TextEditingController messageController;
  final ScrollController scrollController;
  final VoidCallback onSend;
  final VoidCallback onRetry;

  void _fillPrompt(String prompt) {
    messageController.text = prompt;
    messageController.selection = TextSelection.collapsed(
      offset: prompt.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget empty() => Column(
      children: [
        _EmptyChat(isNarrow: isNarrow, onPrompt: _fillPrompt),
        if (isSending)
          const Padding(
            padding: EdgeInsets.only(top: 28),
            child: _TypingIndicator(),
          ),
      ],
    );

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            controller: scrollController,
            padding: EdgeInsets.symmetric(
              horizontal: isNarrow ? 16 : 32,
              vertical: 28,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: messagesAsync == null
                    ? empty()
                    : messagesAsync!.when(
                        loading: () => isSending
                            ? const _TypingIndicator()
                            : const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(40),
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                        error: (error, stack) => _CenteredMessage(
                          icon: Icons.cloud_off_outlined,
                          title: 'Unable to load this conversation',
                          action: OutlinedButton.icon(
                            onPressed: onRetry,
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: const Text('Retry'),
                          ),
                        ),
                        data: (messages) {
                          if (messages.isEmpty) return empty();

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final message in messages) ...[
                                if (message.isUser)
                                  _UserMessage(message: message)
                                else
                                  _AssistantMessage(message: message),
                                const SizedBox(height: 28),
                              ],
                              if (isSending) const _TypingIndicator(),
                            ],
                          );
                        },
                      ),
              ),
            ),
          ),
        ),
        _MessageComposer(
          controller: messageController,
          onSend: onSend,
          isNarrow: isNarrow,
          isSending: isSending,
        ),
      ],
    );
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat({required this.isNarrow, required this.onPrompt});

  final bool isNarrow;
  final ValueChanged<String> onPrompt;

  static const _prompts = [
    (Icons.summarize_outlined, 'Summarize my documents'),
    (Icons.lightbulb_outline_rounded, 'What are the key takeaways?'),
    (Icons.event_outlined, 'Find deadlines and important dates'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: isNarrow ? 28 : 72),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.auto_awesome,
              size: 28,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 22),
          Text(
            'What would you like to research?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isNarrow ? 22 : 28,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.9,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Ask about your workspace documents. Answers come with sources.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 32),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final (icon, label) in _prompts)
                SizedBox(
                  width: isNarrow ? double.infinity : 260,
                  child: _PromptCard(
                    icon: icon,
                    label: label,
                    onTap: () => onPrompt(label),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PromptCard extends StatelessWidget {
  const _PromptCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppTheme.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppTheme.primarySoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: AppTheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    height: 1.3,
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

class _ConversationLoadNotice extends StatelessWidget {
  const _ConversationLoadNotice({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return MaterialBanner(
      backgroundColor: const Color(0xFFFFFBEB),
      dividerColor: Colors.transparent,
      content: const Text('Conversation history could not be refreshed.'),
      leading: const Icon(Icons.cloud_off_outlined, color: Color(0xFFB45309)),
      actions: [TextButton(onPressed: onRetry, child: const Text('Retry'))],
    );
  }
}

// ---------------------------------------------------------------------
// User message
// ---------------------------------------------------------------------

class _UserMessage extends StatelessWidget {
  const _UserMessage({required this.message});

  final MessageModel message;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(
                  20,
                ).copyWith(bottomRight: const Radius.circular(6)),
              ),
              child: SelectableText(
                message.content,
                style: const TextStyle(
                  fontSize: 14.5,
                  height: 1.55,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _formatTime(message.createdAt),
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Assistant message and citations
// ---------------------------------------------------------------------

class _AssistantAvatar extends StatelessWidget {
  const _AssistantAvatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.auto_awesome, color: Colors.white, size: 17),
    );
  }
}

class _AssistantMessage extends StatelessWidget {
  const _AssistantMessage({required this.message});

  final MessageModel message;

  MarkdownStyleSheet get _markdownStyle => MarkdownStyleSheet(
    p: const TextStyle(fontSize: 15, height: 1.7, color: AppTheme.textPrimary),
    h1: const TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
    ),
    h2: const TextStyle(
      fontSize: 19,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.4,
    ),
    h3: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    strong: const TextStyle(fontWeight: FontWeight.w700),
    a: const TextStyle(
      color: AppTheme.primary,
      decoration: TextDecoration.underline,
    ),
    blockSpacing: 12,
    listIndent: 22,
    listBullet: const TextStyle(fontSize: 15, color: AppTheme.textSecondary),
    code: const TextStyle(
      fontFamily: 'monospace',
      fontSize: 13,
      color: Color(0xFF3730A3),
      backgroundColor: Color(0xFFF1F2FA),
    ),
    codeblockPadding: const EdgeInsets.all(14),
    codeblockDecoration: BoxDecoration(
      color: const Color(0xFFF6F7FB),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppTheme.border),
    ),
    blockquotePadding: const EdgeInsets.fromLTRB(14, 8, 12, 8),
    blockquoteDecoration: BoxDecoration(
      color: const Color(0xFFF8F9FC),
      borderRadius: BorderRadius.circular(8),
      border: const Border(left: BorderSide(color: AppTheme.primary, width: 3)),
    ),
    tableBorder: TableBorder.all(color: AppTheme.border),
    tableCellsPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  );

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _AssistantAvatar(),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    const Text(
                      'Cognexa',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatTime(message.createdAt),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              MarkdownBody(
                data: message.content,
                selectable: true,
                softLineBreak: true,
                styleSheet: _markdownStyle,
              ),
              if (message.citations.isNotEmpty) ...[
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Icon(
                      Icons.link_rounded,
                      size: 16,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${message.citations.length} '
                      '${message.citations.length == 1 ? 'source' : 'sources'}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final (i, citation) in message.citations.indexed)
                      _CitationChip(index: i + 1, citation: citation),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              _CopyButton(text: message.content),
            ],
          ),
        ),
      ],
    );
  }
}

class _CopyButton extends StatelessWidget {
  const _CopyButton({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: () {
        Clipboard.setData(ClipboardData(text: text));
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('Copied to clipboard'),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 2),
            ),
          );
      },
      icon: const Icon(Icons.copy_rounded, size: 15),
      label: const Text('Copy'),
      style: TextButton.styleFrom(
        foregroundColor: AppTheme.textSecondary,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: const Size(0, 30),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _CitationChip extends StatelessWidget {
  const _CitationChip({required this.index, required this.citation});

  final int index;
  final CitationModel citation;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 280),
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppTheme.primarySoft,
                shape: BoxShape.circle,
              ),
              child: Text(
                '$index',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primary,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    citation.filename,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    citation.pageNumber == null
                        ? 'Source document'
                        : 'Page ${citation.pageNumber}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Typing indicator
// ---------------------------------------------------------------------

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        _AssistantAvatar(),
        SizedBox(width: 14),
        _TypingDots(),
        SizedBox(width: 10),
        Text(
          'Searching your documents…',
          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
        ),
      ],
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++)
            Container(
              width: 7,
              height: 7,
              margin: const EdgeInsets.symmetric(horizontal: 2.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primary.withValues(
                  alpha:
                      0.25 +
                      0.75 *
                          (math.sin(
                                    (_controller.value - i * 0.18) *
                                        2 *
                                        math.pi,
                                  ) *
                                  0.5 +
                              0.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Message composer
// ---------------------------------------------------------------------

class _MessageComposer extends StatelessWidget {
  const _MessageComposer({
    required this.controller,
    required this.onSend,
    required this.isNarrow,
    required this.isSending,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final bool isNarrow;
  final bool isSending;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.background,
      padding: EdgeInsets.fromLTRB(
        isNarrow ? 12 : 28,
        8,
        isNarrow ? 12 : 28,
        12,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(18, 4, 8, 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: AppTheme.border),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F1226).withValues(alpha: 0.06),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        minLines: 1,
                        maxLines: 5,
                        enabled: !isSending,
                        textInputAction: TextInputAction.send,
                        style: const TextStyle(fontSize: 15),
                        onSubmitted: (_) {
                          if (!isSending) onSend();
                        },
                        decoration: const InputDecoration(
                          hintText: 'Ask a question about your documents…',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          filled: false,
                          contentPadding: EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: ValueListenableBuilder<TextEditingValue>(
                        valueListenable: controller,
                        builder: (context, value, _) {
                          final canSend =
                              value.text.trim().isNotEmpty && !isSending;
                          return Tooltip(
                            message: 'Send message',
                            child: Material(
                              color: canSend
                                  ? AppTheme.primary
                                  : const Color(0xFFE9EBF3),
                              borderRadius: BorderRadius.circular(14),
                              child: InkWell(
                                onTap: canSend ? onSend : null,
                                borderRadius: BorderRadius.circular(14),
                                child: SizedBox(
                                  width: 42,
                                  height: 42,
                                  child: Center(
                                    child: isSending
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: AppTheme.textSecondary,
                                            ),
                                          )
                                        : Icon(
                                            Icons.arrow_upward_rounded,
                                            size: 20,
                                            color: canSend
                                                ? Colors.white
                                                : AppTheme.textSecondary,
                                          ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Cognexa can make mistakes. Verify important information with cited sources.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
