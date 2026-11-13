// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workspace_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(workspaceRepository)
final workspaceRepositoryProvider = WorkspaceRepositoryProvider._();

final class WorkspaceRepositoryProvider
    extends
        $FunctionalProvider<
          WorkspaceRepository,
          WorkspaceRepository,
          WorkspaceRepository
        >
    with $Provider<WorkspaceRepository> {
  WorkspaceRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'workspaceRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$workspaceRepositoryHash();

  @$internal
  @override
  $ProviderElement<WorkspaceRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  WorkspaceRepository create(Ref ref) {
    return workspaceRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WorkspaceRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WorkspaceRepository>(value),
    );
  }
}

String _$workspaceRepositoryHash() =>
    r'477f30a7d5f9e4119e26ebcf9aafc2af0794a545';

@ProviderFor(workspaces)
final workspacesProvider = WorkspacesProvider._();

final class WorkspacesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<WorkspaceModel>>,
          List<WorkspaceModel>,
          FutureOr<List<WorkspaceModel>>
        >
    with
        $FutureModifier<List<WorkspaceModel>>,
        $FutureProvider<List<WorkspaceModel>> {
  WorkspacesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'workspacesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$workspacesHash();

  @$internal
  @override
  $FutureProviderElement<List<WorkspaceModel>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<WorkspaceModel>> create(Ref ref) {
    return workspaces(ref);
  }
}

String _$workspacesHash() => r'c1f866a6f6b6e0f354d8ae42e4015a6c0ea1a840';

@ProviderFor(SelectedWorkspace)
final selectedWorkspaceProvider = SelectedWorkspaceProvider._();

final class SelectedWorkspaceProvider
    extends $NotifierProvider<SelectedWorkspace, WorkspaceModel?> {
  SelectedWorkspaceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'selectedWorkspaceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$selectedWorkspaceHash();

  @$internal
  @override
  SelectedWorkspace create() => SelectedWorkspace();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WorkspaceModel? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WorkspaceModel?>(value),
    );
  }
}

String _$selectedWorkspaceHash() => r'45d1bf21edc596a2ae54ec08c1b193f84f6adfb1';

abstract class _$SelectedWorkspace extends $Notifier<WorkspaceModel?> {
  WorkspaceModel? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<WorkspaceModel?, WorkspaceModel?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<WorkspaceModel?, WorkspaceModel?>,
              WorkspaceModel?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
