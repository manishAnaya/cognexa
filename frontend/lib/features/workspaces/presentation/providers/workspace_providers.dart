import 'package:frontend/core/network/network_providers.dart';
import 'package:frontend/features/workspaces/data/models/workspace_model.dart';
import 'package:frontend/features/workspaces/data/repositories/workspace_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'workspace_providers.g.dart';

@Riverpod(keepAlive: true)
WorkspaceRepository workspaceRepository(Ref ref) {
  return WorkspaceRepository(ref.watch(dioProvider));
}

@riverpod
Future<List<WorkspaceModel>> workspaces(Ref ref) {
  return ref.watch(workspaceRepositoryProvider).getWorkspaces();
}

@Riverpod(keepAlive: true)
class SelectedWorkspace extends _$SelectedWorkspace {
  @override
  WorkspaceModel? build() => null;

  void select(WorkspaceModel workspace) {
    state = workspace;
  }

  void clear() {
    state = null;
  }
}
