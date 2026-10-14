import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/config/app_config.dart';
import '../storage/token_storage.dart';

/// Phát sự kiện khi backend trả 401 (token hết hạn / không hợp lệ).
/// `AuthController` lắng nghe để đăng xuất và đưa người dùng về màn đăng nhập.
final sessionExpiredEventsProvider = Provider<StreamController<void>>((ref) {
  final controller = StreamController<void>.broadcast();
  ref.onDispose(controller.close);
  return controller;
});

/// Dio dùng chung cho toàn app. Mọi request đi qua Nginx Gateway của backend.
final dioProvider = Provider<Dio>((ref) {
  final config = ref.watch(appConfigProvider);
  final dio = Dio(
    BaseOptions(
      baseUrl: config.apiBaseUrl,
      connectTimeout: config.connectTimeout,
      receiveTimeout: config.receiveTimeout,
      contentType: Headers.jsonContentType,
      responseType: ResponseType.json,
    ),
  );

  dio.interceptors.add(
    AuthInterceptor(
      tokenStorage: ref.watch(tokenStorageProvider),
      onUnauthorized: () => ref.read(sessionExpiredEventsProvider).add(null),
    ),
  );

  if (kDebugMode && !config.isProd) {
    dio.interceptors.add(
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (o) => debugPrint(o.toString()),
      ),
    );
  }
  return dio;
});

/// Gắn `Authorization: Bearer <token>` vào mọi request và xử lý 401.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({required this.tokenStorage, required this.onUnauthorized});

  final TokenStorage tokenStorage;
  final VoidCallback onUnauthorized;

  /// Các endpoint không cần token.
  static const _publicPaths = [
    '/api/auth/login',
    '/api/auth/forgot-password',
    '/api/auth/reset-password',
  ];

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final isPublic = _publicPaths.any(options.path.endsWith);
    if (!isPublic) {
      final token = await tokenStorage.readToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final isPublic = _publicPaths.any(err.requestOptions.path.endsWith);
    if (err.response?.statusCode == 401 && !isPublic) {
      onUnauthorized();
    }
    handler.next(err);
  }
}
