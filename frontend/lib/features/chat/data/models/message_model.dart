class CitationModel {
  const CitationModel({
    required this.chunkId,
    required this.documentId,
    required this.filename,
    this.pageNumber,
  });

  final String chunkId;
  final String documentId;
  final String filename;
  final int? pageNumber;

  factory CitationModel.fromJson(Map<String, dynamic> json) {
    return CitationModel(
      chunkId: json['chunk_id']?.toString() ?? '',
      documentId: json['document_id']?.toString() ?? '',
      filename: json['filename']?.toString() ?? 'Unknown document',
      pageNumber: (json['page_number'] as num?)?.toInt(),
    );
  }
}

class MessageModel {
  const MessageModel({
    required this.id,
    required this.conversationId,
    required this.role,
    required this.content,
    required this.citations,
    this.createdAt,
  });

  final String id;
  final String conversationId;
  final String role;
  final String content;
  final List<CitationModel> citations;
  final DateTime? createdAt;

  bool get isUser => role.toLowerCase() == 'user';

  bool get isAssistant => role.toLowerCase() == 'assistant';

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    final rawCitations = json['citations'] as List<dynamic>? ?? [];

    return MessageModel(
      id: json['id'].toString(),
      conversationId: json['conversation_id'].toString(),
      role: json['role'] as String? ?? 'assistant',
      content: json['content'] as String? ?? '',
      citations: rawCitations
          .whereType<Map<String, dynamic>>()
          .map(CitationModel.fromJson)
          .toList(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }
}
