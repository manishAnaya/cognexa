import 'package:dio/dio.dart';
import '../models/chat_response_model.dart';
import '../models/conversation_model.dart';
import '../models/message_model.dart';

class ConversationRepository {
  ConversationRepository(this._dio);

  final Dio _dio;

  Future<List<ConversationModel>> getConversations(String workspaceId) async {
    final response = await _dio.get('/workspaces/$workspaceId/conversations/');

    final data = response.data as List<dynamic>;

    return data
        .map((item) => ConversationModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<ConversationModel> createConversation({
    required String workspaceId,
    required String title,
  }) async {
    final response = await _dio.post(
      '/workspaces/$workspaceId/conversations/',
      data: {'title': title},
    );

    return ConversationModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<MessageModel>> getMessages({
    required String workspaceId,
    required String conversationId,
  }) async {
    final response = await _dio.get(
      '/workspaces/$workspaceId/conversations/$conversationId/messages',
    );

    final data = response.data as List<dynamic>;

    return data
        .map((item) => MessageModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<ChatResponseModel> sendMessage({
    required String workspaceId,
    required String conversationId,
    required String query,
  }) async {
    final response = await _dio.post(
      '/workspaces/$workspaceId/conversations/$conversationId/messages/',
      data: {'query': query},
    );

    return ChatResponseModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deleteConversation({
    required String workspaceId,
    required String conversationId,
  }) async {
    await _dio.delete('/workspaces/$workspaceId/conversations/$conversationId');
  }
}
