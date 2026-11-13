import 'package:dio/dio.dart';
import '../models/workspace_model.dart';

class WorkspaceRepository {
  WorkspaceRepository(this._dio);

  final Dio _dio;

  Future<List<WorkspaceModel>> getWorkspaces() async {
    final response = await _dio.get('/workspaces/');

    final data = response.data as List<dynamic>;

    return data
        .map((item) => WorkspaceModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<WorkspaceModel> getWorkspace(String id) async {
    final response = await _dio.get('/workspaces/$id');

    return WorkspaceModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<WorkspaceModel> createWorkspace({
    required String name,
    String? description,
  }) async {
    final response = await _dio.post(
      '/workspaces/',
      data: {'name': name, 'description': description},
    );

    return WorkspaceModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<WorkspaceModel> updateWorkspace({
    required String id,
    String? name,
    String? description,
  }) async {
    final response = await _dio.patch(
      '/workspaces/$id',
      data: {
        if (name != null) 'name': name,
        if (description != null) 'description': description,
      },
    );

    return WorkspaceModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deleteWorkspace(String id) async {
    await _dio.delete('/workspaces/$id');
  }
}
