import 'package:dio/dio.dart';
import 'package:frontend/core/storage/token_storage.dart';
import 'package:frontend/features/auth/data/models/user_model.dart';

class AuthRepository {
  AuthRepository(this._dio, this._tokenStorage);

  final Dio _dio;
  final TokenStorage _tokenStorage;

  // Registration uses JSON.
  Future<UserModel> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final response = await _dio.post(
      '/auth/register',
      data: {'full_name': fullName, 'email': email, 'password': password},
    );

    return UserModel.fromJson(Map<String, dynamic>.from(response.data));
  }

  // The login endpoint accepts the UserLogin JSON schema.
  Future<void> login({required String email, required String password}) async {
    final response = await _dio.post(
      '/auth/login',
      data: {'email': email, 'password': password},
      options: Options(contentType: Headers.jsonContentType),
    );

    final data = Map<String, dynamic>.from(response.data);
    final token = data['access_token'] as String;

    await _tokenStorage.saveToken(token);
  }

  Future<UserModel> getCurrentUser() async {
    final response = await _dio.get('/users/me');

    return UserModel.fromJson(Map<String, dynamic>.from(response.data));
  }

  Future<void> logout() async {
    await _tokenStorage.deleteToken();
  }

  Future<bool> hasToken() async {
    final token = await _tokenStorage.getToken();
    return token != null && token.isNotEmpty;
  }
}
