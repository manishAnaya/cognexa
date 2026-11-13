// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'document_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(documentRepository)
final documentRepositoryProvider = DocumentRepositoryProvider._();

final class DocumentRepositoryProvider
    extends
        $FunctionalProvider<
          DocumentRepository,
          DocumentRepository,
          DocumentRepository
        >
    with $Provider<DocumentRepository> {
  DocumentRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'documentRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$documentRepositoryHash();

  @$internal
  @override
  $ProviderElement<DocumentRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DocumentRepository create(Ref ref) {
    return documentRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DocumentRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DocumentRepository>(value),
    );
  }
}

String _$documentRepositoryHash() =>
    r'1fc257e056dbcbe7c0b98a3e3532e9eb57294220';

@ProviderFor(documents)
final documentsProvider = DocumentsFamily._();

final class DocumentsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<DocumentModel>>,
          List<DocumentModel>,
          FutureOr<List<DocumentModel>>
        >
    with
        $FutureModifier<List<DocumentModel>>,
        $FutureProvider<List<DocumentModel>> {
  DocumentsProvider._({
    required DocumentsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'documentsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$documentsHash();

  @override
  String toString() {
    return r'documentsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<DocumentModel>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<DocumentModel>> create(Ref ref) {
    final argument = this.argument as String;
    return documents(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is DocumentsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$documentsHash() => r'08537b708ed52f6abb61fe2f3290077c51e06fe4';

final class DocumentsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<DocumentModel>>, String> {
  DocumentsFamily._()
    : super(
        retry: null,
        name: r'documentsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  DocumentsProvider call(String workspaceId) =>
      DocumentsProvider._(argument: workspaceId, from: this);

  @override
  String toString() => r'documentsProvider';
}
