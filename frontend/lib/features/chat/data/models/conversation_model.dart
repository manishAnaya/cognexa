class ConversationModel {
  const ConversationModel({
    required this.id,
    required this.workspaceId,
    required this.title,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String workspaceId;
  final String title;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    return ConversationModel(
      id: json['id'].toString(),
      workspaceId: json['workspace_id'].toString(),
      title: json['title'] as String? ?? 'New conversation',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }
}
