import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../storage/token_storage.dart';
import 'dio_client.dart';
part 'network_providers.g.dart';

@Riverpod(keepAlive: true)
TokenStorage tokenStorage(Ref ref) {
  return TokenStorage();
}

@Riverpod(keepAlive: true)
DioClient dioClient(Ref ref) {
  final storage = ref.watch(tokenStorageProvider);
  return DioClient(storage);
}

@Riverpod(keepAlive: true)
Dio dio(Ref ref) {
  return ref.watch(dioClientProvider).dio;
}
