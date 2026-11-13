import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../models/document_model.dart';

class DocumentRepository {
  DocumentRepository(this._dio);

  final Dio _dio;

  Future<List<DocumentModel>> getDocuments(String workspaceId) async {
    final response = await _dio.get('/workspaces/$workspaceId/documents/');

    final data = response.data as List<dynamic>;

    return data
        .map((item) => DocumentModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<DocumentModel> uploadDocument({
    required String workspaceId,
    required String filename,
    String? filePath,
    Uint8List? bytes,
    void Function(int sent, int total)? onProgress,
  }) async {
    late MultipartFile multipartFile;

    if (bytes != null) {
      multipartFile = MultipartFile.fromBytes(bytes, filename: filename);
    } else if (filePath != null) {
      multipartFile = await MultipartFile.fromFile(
        filePath,
        filename: filename,
      );
    } else {
      throw ArgumentError('Either filePath or bytes must be provided.');
    }

    final formData = FormData.fromMap({'file': multipartFile});

    final response = await _dio.post(
      '/workspaces/$workspaceId/documents/',
      data: formData,
      onSendProgress: onProgress,
    );

    return DocumentModel.fromJson(response.data as Map<String, dynamic>);
  }
}
