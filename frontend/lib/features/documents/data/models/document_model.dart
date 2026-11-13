class DocumentModel {
  const DocumentModel({
    required this.id,
    required this.workspaceId,
    required this.filename,
    required this.fileType,
    required this.fileSize,
    required this.status,
    this.createdAt,
  });

  final String id;
  final String workspaceId;
  final String filename;
  final String fileType;
  final int fileSize;
  final String status;
  final DateTime? createdAt;

  factory DocumentModel.fromJson(Map<String, dynamic> json) {
    return DocumentModel(
      id: json['id'].toString(),
      workspaceId: json['workspace_id'].toString(),
      filename: json['filename'] as String,
      fileType: json['file_type'] as String? ?? '',
      fileSize: (json['file_size'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'uploaded',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  bool get isProcessed => status.toLowerCase() == 'processed';

  bool get isProcessing => status.toLowerCase() == 'processing';

  bool get hasFailed => status.toLowerCase() == 'failed';

  String get formattedSize {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
