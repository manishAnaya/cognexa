import 'message_model.dart';

class ChatResponseModel {
  const ChatResponseModel({
    required this.workspaceId,
    required this.answer,
    required this.citations,
  });

  final String workspaceId;
  final String answer;
  final List<CitationModel> citations;

  factory ChatResponseModel.fromJson(Map<String, dynamic> json) {
    final rawCitations = json['citations'] as List<dynamic>? ?? [];

    return ChatResponseModel(
      workspaceId: json['workspace_id'].toString(),
      answer: json['answer'] as String? ?? '',
      citations: rawCitations
          .whereType<Map<String, dynamic>>()
          .map(CitationModel.fromJson)
          .toList(),
    );
  }
}
