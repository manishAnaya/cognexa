import 'package:frontend/core/network/network_providers.dart';
import 'package:frontend/features/documents/data/models/document_model.dart';
import 'package:frontend/features/documents/data/repositories/document_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'document_providers.g.dart';

@Riverpod(keepAlive: true)
DocumentRepository documentRepository(Ref ref) {
  return DocumentRepository(ref.watch(dioProvider));
}

@riverpod
Future<List<DocumentModel>> documents(Ref ref, String workspaceId) {
  return ref.watch(documentRepositoryProvider).getDocuments(workspaceId);
}
