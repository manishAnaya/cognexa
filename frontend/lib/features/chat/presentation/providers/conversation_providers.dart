import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/network/network_providers.dart';
import 'package:frontend/features/chat/data/models/conversation_model.dart';
import 'package:frontend/features/chat/data/models/message_model.dart';
import 'package:frontend/features/chat/data/repositories/conversation_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'conversation_providers.g.dart';

final chatDraftProvider = NotifierProvider<ChatDraft, String?>(ChatDraft.new);

class ChatDraft extends Notifier<String?> {
  @override
  String? build() => null;

  void setQuestion(String question) => state = question;

  void clear() => state = null;
}

@Riverpod(keepAlive: true)
ConversationRepository conversationRepository(Ref ref) {
  return ConversationRepository(ref.watch(dioProvider));
}

@riverpod
Future<List<ConversationModel>> conversations(Ref ref, String workspaceId) {
  return ref
      .watch(conversationRepositoryProvider)
      .getConversations(workspaceId);
}

@riverpod
Future<List<MessageModel>> conversationMessages(
  Ref ref,
  String workspaceId,
  String conversationId,
) {
  return ref
      .watch(conversationRepositoryProvider)
      .getMessages(workspaceId: workspaceId, conversationId: conversationId);
}
