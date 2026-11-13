// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'conversation_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(conversationRepository)
final conversationRepositoryProvider = ConversationRepositoryProvider._();

final class ConversationRepositoryProvider
    extends
        $FunctionalProvider<
          ConversationRepository,
          ConversationRepository,
          ConversationRepository
        >
    with $Provider<ConversationRepository> {
  ConversationRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'conversationRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$conversationRepositoryHash();

  @$internal
  @override
  $ProviderElement<ConversationRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ConversationRepository create(Ref ref) {
    return conversationRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ConversationRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ConversationRepository>(value),
    );
  }
}

String _$conversationRepositoryHash() =>
    r'c8e5c1c9749356083ef86d5fa40b787fcdea4b14';

@ProviderFor(conversations)
final conversationsProvider = ConversationsFamily._();

final class ConversationsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ConversationModel>>,
          List<ConversationModel>,
          FutureOr<List<ConversationModel>>
        >
    with
        $FutureModifier<List<ConversationModel>>,
        $FutureProvider<List<ConversationModel>> {
  ConversationsProvider._({
    required ConversationsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'conversationsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$conversationsHash();

  @override
  String toString() {
    return r'conversationsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<ConversationModel>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<ConversationModel>> create(Ref ref) {
    final argument = this.argument as String;
    return conversations(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ConversationsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$conversationsHash() => r'd19a2671d130d034f1d5714fd0333719b558ac6e';

final class ConversationsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<ConversationModel>>, String> {
  ConversationsFamily._()
    : super(
        retry: null,
        name: r'conversationsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ConversationsProvider call(String workspaceId) =>
      ConversationsProvider._(argument: workspaceId, from: this);

  @override
  String toString() => r'conversationsProvider';
}

@ProviderFor(conversationMessages)
final conversationMessagesProvider = ConversationMessagesFamily._();

final class ConversationMessagesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<MessageModel>>,
          List<MessageModel>,
          FutureOr<List<MessageModel>>
        >
    with
        $FutureModifier<List<MessageModel>>,
        $FutureProvider<List<MessageModel>> {
  ConversationMessagesProvider._({
    required ConversationMessagesFamily super.from,
    required (String, String) super.argument,
  }) : super(
         retry: null,
         name: r'conversationMessagesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$conversationMessagesHash();

  @override
  String toString() {
    return r'conversationMessagesProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<List<MessageModel>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<MessageModel>> create(Ref ref) {
    final argument = this.argument as (String, String);
    return conversationMessages(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is ConversationMessagesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$conversationMessagesHash() =>
    r'1b64531c72293e37d3f134e81bc99a5edde702a9';

final class ConversationMessagesFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<MessageModel>>,
          (String, String)
        > {
  ConversationMessagesFamily._()
    : super(
        retry: null,
        name: r'conversationMessagesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ConversationMessagesProvider call(
    String workspaceId,
    String conversationId,
  ) => ConversationMessagesProvider._(
    argument: (workspaceId, conversationId),
    from: this,
  );

  @override
  String toString() => r'conversationMessagesProvider';
}
