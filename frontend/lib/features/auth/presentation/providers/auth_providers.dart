import 'package:dio/dio.dart';
import 'package:frontend/core/network/network_providers.dart';
import 'package:frontend/features/auth/data/models/user_model.dart';
import 'package:frontend/features/auth/data/repositories/auth_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'auth_providers.g.dart';

@Riverpod(keepAlive: true)
AuthRepository authRepository(Ref ref) {
  return AuthRepository(
    ref.watch(dioProvider),
    ref.watch(tokenStorageProvider),
  );
}

// Restores the authenticated user when the app starts.
@riverpod
Future<UserModel?> currentUser(Ref ref) async {
  final repository = ref.watch(authRepositoryProvider);

  if (!await repository.hasToken()) {
    return null;
  }

  try {
    return await repository.getCurrentUser();
  } on DioException catch (error) {
    if (error.response?.statusCode == 401) {
      await repository.logout();
      return null;
    }

    rethrow;
  }
}
