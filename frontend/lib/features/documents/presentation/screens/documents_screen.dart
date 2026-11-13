import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:frontend/app/theme/app_theme.dart';
import 'package:frontend/features/documents/data/models/document_model.dart';
import 'package:frontend/features/documents/presentation/providers/document_providers.dart';
import 'package:frontend/features/workspaces/presentation/providers/workspace_providers.dart';
import 'package:frontend/features/workspaces/data/models/workspace_model.dart';
import 'package:frontend/features/chat/presentation/providers/conversation_providers.dart';

enum DocumentStatus { processed, processing, failed, uploaded }

class DocumentItem {
  const DocumentItem({
    required this.id,
    required this.name,
    required this.type,
    required this.size,
    required this.date,
    required this.status,
  });

  final String id;
  final String name;
  final String type;
  final String size;
  final String date;
  final DocumentStatus status;

  factory DocumentItem.fromModel(DocumentModel model) {
    final status = switch (model.status.toLowerCase()) {
      'processed' => DocumentStatus.processed,
      'processing' => DocumentStatus.processing,
      'failed' => DocumentStatus.failed,
      _ => DocumentStatus.uploaded,
    };

    final date = model.createdAt != null
        ? DateFormat('MMM dd, yyyy').format(model.createdAt!)
        : 'Unknown';

    return DocumentItem(
      id: model.id,
      name: model.filename,
      type: model.fileType.toUpperCase().replaceFirst('.', ''),
      size: model.formattedSize,
      date: date,
      status: status,
    );
  }
}

class DocumentsScreen extends ConsumerStatefulWidget {
  const DocumentsScreen({super.key});

  @override
  ConsumerState<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends ConsumerState<DocumentsScreen> {
  final _searchController = TextEditingController();

  String _selectedFilter = 'All documents';
  String _searchQuery = '';

  bool _isUploading = false;
  double _uploadProgress = 0;
  String? _uploadingFileName;
  int _uploadingFileIndex = 0;
  int _totalUploadFiles = 0;

  static const _filters = [
    'All documents',
    'Processed',
    'Processing',
    'Uploaded',
    'Failed',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<DocumentItem> _filterDocuments(List<DocumentItem> documents) {
    return documents.where((document) {
      final matchesSearch = document.name.toLowerCase().contains(
        _searchQuery.toLowerCase(),
      );

      final matchesFilter = switch (_selectedFilter) {
        'Processed' => document.status == DocumentStatus.processed,
        'Processing' => document.status == DocumentStatus.processing,
        'Uploaded' => document.status == DocumentStatus.uploaded,
        'Failed' => document.status == DocumentStatus.failed,
        _ => true,
      };

      return matchesSearch && matchesFilter;
    }).toList();
  }

  Future<void> _createWorkspace() async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Create workspace'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Workspace name',
                    hintText: 'e.g. Product Research',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    hintText: 'Describe your workspace',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (nameController.text.trim().isEmpty) return;
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );

    if (result != true || !mounted) {
      nameController.dispose();
      descriptionController.dispose();
      return;
    }

    try {
      final workspace = await ref
          .read(workspaceRepositoryProvider)
          .createWorkspace(
            name: nameController.text.trim(),
            description: descriptionController.text.trim().isEmpty
                ? null
                : descriptionController.text.trim(),
          );

      ref.read(selectedWorkspaceProvider.notifier).select(workspace);
      ref.invalidate(workspacesProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Workspace created successfully.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not create workspace: $error')),
        );
      }
    } finally {
      nameController.dispose();
      descriptionController.dispose();
    }
  }

  Future<void> _renameWorkspace(WorkspaceModel workspace) async {
    final controller = TextEditingController(text: workspace.name);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rename workspace'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Workspace name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim().isNotEmpty),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      controller.dispose();
      return;
    }
    try {
      final updated = await ref
          .read(workspaceRepositoryProvider)
          .updateWorkspace(id: workspace.id, name: controller.text.trim());
      ref.read(selectedWorkspaceProvider.notifier).select(updated);
      ref.invalidate(workspacesProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Workspace renamed.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not rename workspace: $error')),
        );
      }
    } finally {
      controller.dispose();
    }
  }

  Future<void> _deleteWorkspace(WorkspaceModel workspace) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete workspace?'),
        content: Text(
          '"${workspace.name}" and its documents and conversations will be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(workspaceRepositoryProvider).deleteWorkspace(workspace.id);
      final remaining =
          (ref.read(workspacesProvider).asData?.value ??
                  const <WorkspaceModel>[])
              .where((item) => item.id != workspace.id)
              .toList();
      if (ref.read(selectedWorkspaceProvider)?.id == workspace.id) {
        if (remaining.isEmpty) {
          ref.read(selectedWorkspaceProvider.notifier).clear();
        } else {
          ref.read(selectedWorkspaceProvider.notifier).select(remaining.first);
        }
      }
      ref.invalidate(documentsProvider(workspace.id));
      ref.invalidate(conversationsProvider(workspace.id));
      ref.invalidate(workspacesProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Workspace deleted.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete workspace: $error')),
        );
      }
    }
  }

  Future<void> _pickDocuments() async {
    if (_isUploading) return;

    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'docx', 'txt', 'csv', 'md'],
    );

    if (!mounted || files.isEmpty) return;

    final workspace = ref.read(selectedWorkspaceProvider);

    if (workspace == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a workspace first.')),
      );
      return;
    }

    await _uploadDocuments(workspaceId: workspace.id, files: files);
  }

  Future<void> _uploadDocuments({
    required String workspaceId,
    required List<PlatformFile> files,
  }) async {
    setState(() {
      _isUploading = true;
      _totalUploadFiles = files.length;
      _uploadingFileIndex = 0;
      _uploadProgress = 0;
    });

    var successfulUploads = 0;
    final failedFiles = <String>[];

    try {
      for (var i = 0; i < files.length; i++) {
        final file = files[i];

        if (!mounted) return;

        setState(() {
          _uploadingFileIndex = i + 1;
          _uploadingFileName = file.name;
          _uploadProgress = 0;
        });

        try {
          await ref
              .read(documentRepositoryProvider)
              .uploadDocument(
                workspaceId: workspaceId,
                filename: file.name,
                bytes: await file.readAsBytes(),
                onProgress: (sent, total) {
                  if (mounted && total > 0) {
                    setState(() {
                      _uploadProgress = sent / total;
                    });
                  }
                },
              );

          successfulUploads++;
        } catch (error) {
          failedFiles.add(file.name);
        }
      }

      ref.invalidate(documentsProvider(workspaceId));

      if (!mounted) return;

      final message = failedFiles.isEmpty
          ? '$successfulUploads document(s) uploaded successfully.'
          : '$successfulUploads uploaded, ${failedFiles.length} failed.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );

      if (failedFiles.isNotEmpty) {
        debugPrint('Failed document uploads: ${failedFiles.join(', ')}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadProgress = 0;
          _uploadingFileName = null;
          _uploadingFileIndex = 0;
          _totalUploadFiles = 0;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final workspacesAsync = ref.watch(workspacesProvider);
    final selectedWorkspace = ref.watch(selectedWorkspaceProvider);

    // Automatically select the first workspace when none is selected.
    ref.listen(workspacesProvider, (previous, next) {
      next.whenData((workspaces) {
        if (ref.read(selectedWorkspaceProvider) == null &&
            workspaces.isNotEmpty) {
          ref.read(selectedWorkspaceProvider.notifier).select(workspaces.first);
        }
      });
    });

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 650;

        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isNarrow ? 16 : 32,
            vertical: isNarrow ? 20 : 28,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1280),
              child: workspacesAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(80),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, stackTrace) => _ErrorState(
                  message: 'Unable to load workspaces.',
                  onRetry: () => ref.invalidate(workspacesProvider),
                ),
                data: (workspaces) {
                  if (workspaces.isEmpty) {
                    return _EmptyWorkspaceState(onCreate: _createWorkspace);
                  }

                  final workspace = workspaces.firstWhere(
                    (item) => item.id == selectedWorkspace?.id,
                    orElse: () => workspaces.first,
                  );

                  final workspaceDocuments = ref.watch(
                    documentsProvider(workspace.id),
                  );

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Header(
                        isNarrow: isNarrow,
                        onUpload: _pickDocuments,
                        isUploading: _isUploading,
                      ),
                      const SizedBox(height: 20),
                      _WorkspaceSelector(
                        workspaces: workspaces,
                        selectedWorkspace: workspace,
                        onChanged: (value) {
                          if (value != null) {
                            ref
                                .read(selectedWorkspaceProvider.notifier)
                                .select(value);
                            setState(() {
                              _selectedFilter = 'All documents';
                              _searchQuery = '';
                              _searchController.clear();
                            });
                          }
                        },
                        onCreate: _createWorkspace,
                        onRename: _renameWorkspace,
                        onDelete: _deleteWorkspace,
                      ),
                      const SizedBox(height: 20),
                      if (_isUploading) ...[
                        _UploadProgress(
                          filename: _uploadingFileName ?? '',
                          progress: _uploadProgress,
                          current: _uploadingFileIndex,
                          total: _totalUploadFiles,
                        ),
                        const SizedBox(height: 20),
                      ],
                      workspaceDocuments.when(
                        loading: () => const Padding(
                          padding: EdgeInsets.all(80),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                        error: (error, stackTrace) => _ErrorState(
                          message: 'Unable to load documents.',
                          onRetry: () =>
                              ref.invalidate(documentsProvider(workspace.id)),
                        ),
                        data: (models) {
                          final allDocuments = models
                              .map(DocumentItem.fromModel)
                              .toList();

                          final filteredDocuments = _filterDocuments(
                            allDocuments,
                          );

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _DocumentSummary(documents: allDocuments),
                              const SizedBox(height: 24),
                              _DocumentToolbar(
                                controller: _searchController,
                                selectedFilter: _selectedFilter,
                                filters: _filters,
                                onSearch: (value) {
                                  setState(() => _searchQuery = value);
                                },
                                onFilterChanged: (value) {
                                  setState(() => _selectedFilter = value);
                                },
                              ),
                              const SizedBox(height: 16),
                              _DocumentList(
                                documents: filteredDocuments,
                                isNarrow: isNarrow,
                              ),
                              const SizedBox(height: 24),
                            ],
                          );
                        },
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

class _Header extends StatelessWidget {
  const _Header({
    required this.isNarrow,
    required this.onUpload,
    required this.isUploading,
  });

  final bool isNarrow;
  final VoidCallback onUpload;
  final bool isUploading;

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
              'Documents',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 6),
            const Text(
              'Manage your knowledge base and indexed content.',
              style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
            ),
          ],
        ),
        FilledButton.icon(
          onPressed: isUploading ? null : onUpload,
          icon: const Icon(Icons.upload_file_rounded, size: 19),
          label: const Text('Upload documents'),
        ),
      ],
    );
  }
}

class _WorkspaceSelector extends StatelessWidget {
  const _WorkspaceSelector({
    required this.workspaces,
    required this.selectedWorkspace,
    required this.onChanged,
    required this.onCreate,
    required this.onRename,
    required this.onDelete,
  });

  final List<WorkspaceModel> workspaces;
  final WorkspaceModel selectedWorkspace;
  final ValueChanged<WorkspaceModel?> onChanged;
  final VoidCallback onCreate;
  final ValueChanged<WorkspaceModel> onRename;
  final ValueChanged<WorkspaceModel> onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: AppTheme.panelDecoration,
      child: Row(
        children: [
          const Icon(Icons.folder_outlined, color: AppTheme.primary),
          const SizedBox(width: 12),
          const Text(
            'Workspace',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton(
                value: selectedWorkspace,
                isExpanded: true,
                items: workspaces.map((workspace) {
                  return DropdownMenuItem(
                    value: workspace,
                    child: Text(
                      workspace.name,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: onChanged,
              ),
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Workspace actions',
            onSelected: (action) {
              if (action == 'rename') onRename(selectedWorkspace);
              if (action == 'delete') onDelete(selectedWorkspace);
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'rename', child: Text('Rename')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
          IconButton(
            tooltip: 'Create workspace',
            onPressed: onCreate,
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
    );
  }
}

class _UploadProgress extends StatelessWidget {
  const _UploadProgress({
    required this.filename,
    required this.progress,
    required this.current,
    required this.total,
  });

  final String filename;
  final double progress;
  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.panelDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.cloud_upload_outlined, color: AppTheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Uploading $filename',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                '$current/$total',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            borderRadius: BorderRadius.circular(10),
          ),
          const SizedBox(height: 6),
          Text(
            '${(progress * 100).toStringAsFixed(0)}% uploaded',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _EmptyWorkspaceState extends StatelessWidget {
  const _EmptyWorkspaceState({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: AppTheme.panelDecoration,
      child: Column(
        children: [
          const Icon(
            Icons.folder_open_outlined,
            size: 48,
            color: AppTheme.primary,
          ),
          const SizedBox(height: 16),
          const Text(
            'No workspaces yet',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create a workspace before uploading your documents.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add),
            label: const Text('Create workspace'),
          ),
        ],
      ),
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
      padding: const EdgeInsets.all(40),
      decoration: AppTheme.panelDecoration,
      child: Column(
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            size: 40,
            color: AppTheme.textSecondary,
          ),
          const SizedBox(height: 12),
          Text(message),
          const SizedBox(height: 16),
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

class _DocumentSummary extends StatelessWidget {
  const _DocumentSummary({required this.documents});

  final List<DocumentItem> documents;

  @override
  Widget build(BuildContext context) {
    final items = [
      _SummaryData(
        'Total documents',
        '${documents.length}',
        Icons.description_outlined,
      ),
      _SummaryData(
        'Processed',
        '${documents.where((d) => d.status == DocumentStatus.processed).length}',
        Icons.check_circle_outline,
      ),
      _SummaryData(
        'Processing',
        '${documents.where((d) => d.status == DocumentStatus.processing).length}',
        Icons.sync_rounded,
      ),
      _SummaryData(
        'Failed',
        '${documents.where((d) => d.status == DocumentStatus.failed).length}',
        Icons.error_outline,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 850
            ? 4
            : constraints.maxWidth >= 430
            ? 2
            : 1;

        const spacing = 12.0;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: items.map((item) {
            return SizedBox(
              width: width,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: AppTheme.panelDecoration,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.primarySoft,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Icon(item.icon, size: 20, color: AppTheme.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.value,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
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
          }).toList(),
        );
      },
    );
  }
}

class _SummaryData {
  const _SummaryData(this.title, this.value, this.icon);

  final String title;
  final String value;
  final IconData icon;
}

class _DocumentToolbar extends StatelessWidget {
  const _DocumentToolbar({
    required this.controller,
    required this.selectedFilter,
    required this.filters,
    required this.onSearch,
    required this.onFilterChanged,
  });

  final TextEditingController controller;
  final String selectedFilter;
  final List<String> filters;
  final ValueChanged<String> onSearch;
  final ValueChanged<String> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 650;

        final search = SizedBox(
          height: 44,
          width: narrow ? double.infinity : 300,
          child: TextField(
            controller: controller,
            onChanged: onSearch,
            decoration: const InputDecoration(
              hintText: 'Search documents...',
              prefixIcon: Icon(Icons.search_rounded, size: 20),
              contentPadding: EdgeInsets.zero,
              isDense: true,
            ),
          ),
        );

        final filter = Wrap(
          spacing: 6,
          children: filters.map((item) {
            final selected = selectedFilter == item;

            return ChoiceChip(
              label: Text(item),
              selected: selected,
              onSelected: (_) => onFilterChanged(item),
              showCheckmark: false,
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? AppTheme.primary : AppTheme.textSecondary,
              ),
              backgroundColor: Colors.white,
              selectedColor: AppTheme.primarySoft,
              side: BorderSide(
                color: selected ? AppTheme.primarySoft : AppTheme.border,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            );
          }).toList(),
        );

        if (narrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [search, const SizedBox(height: 12), filter],
          );
        }

        return Row(
          children: [
            search,
            const Spacer(),
            Flexible(child: filter),
          ],
        );
      },
    );
  }
}

class _DocumentList extends StatelessWidget {
  const _DocumentList({required this.documents, required this.isNarrow});

  final List<DocumentItem> documents;
  final bool isNarrow;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.panelDecoration,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 17),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Your documents',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  '${documents.length} files',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (documents.isEmpty)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Column(
                children: [
                  Icon(
                    Icons.search_off_rounded,
                    size: 36,
                    color: AppTheme.textSecondary,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'No documents found',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Try changing your search or filter.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            )
          else
            ...documents.map(
              (document) => Column(
                children: [
                  _DocumentRow(document: document, isNarrow: isNarrow),
                  const Divider(height: 1),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DocumentRow extends StatelessWidget {
  const _DocumentRow({required this.document, required this.isNarrow});

  final DocumentItem document;
  final bool isNarrow;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (document.type) {
      'PDF' => (Icons.picture_as_pdf_outlined, const Color(0xFFDC2626)),
      'DOCX' => (Icons.description_outlined, const Color(0xFF2563EB)),
      'CSV' => (Icons.table_chart_outlined, const Color(0xFF059669)),
      _ => (Icons.article_outlined, const Color(0xFF64748B)),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  document.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${document.type}  ·  ${document.size}  ·  ${document.date}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                  ),
                ),
                if (isNarrow) ...[
                  const SizedBox(height: 8),
                  _StatusPill(status: document.status),
                ],
              ],
            ),
          ),
          if (!isNarrow) ...[
            const SizedBox(width: 12),
            _StatusPill(status: document.status),
          ],
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            tooltip: 'Document actions',
            icon: const Icon(
              Icons.more_horiz_rounded,
              color: AppTheme.textSecondary,
            ),
            onSelected: (_) => showDialog<void>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: Text(document.name),
                content: SelectableText(
                  'ID: ${document.id}\n'
                  'Type: ${document.type}\n'
                  'Size: ${document.size}\n'
                  'Uploaded: ${document.date}\n'
                  'Status: ${document.status.name}',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'details', child: Text('View details')),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final DocumentStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color, background, icon) = switch (status) {
      DocumentStatus.processed => (
        'Processed',
        const Color(0xFF047857),
        const Color(0xFFECFDF5),
        Icons.check_circle_outline,
      ),
      DocumentStatus.processing => (
        'Processing',
        const Color(0xFFB45309),
        const Color(0xFFFFF7ED),
        Icons.sync_rounded,
      ),
      DocumentStatus.failed => (
        'Failed',
        const Color(0xFFB91C1C),
        const Color(0xFFFEF2F2),
        Icons.error_outline,
      ),
      DocumentStatus.uploaded => (
        'Uploaded',
        const Color(0xFF2563EB),
        const Color(0xFFEFF6FF),
        Icons.cloud_done_outlined,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
