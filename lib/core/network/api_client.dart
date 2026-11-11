import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/config/app_config.dart';
import '../auth/jwt_decoder.dart';
import '../storage/token_storage.dart';
import 'api_exception.dart';
import 'api_paths.dart';
import 'api_response.dart';

/// Phát sự kiện khi phiên không gia hạn được (refresh token hết hạn / bị thu
/// hồi). `AuthController` lắng nghe để đăng xuất và về màn đăng nhập.
final sessionExpiredEventsProvider = Provider<StreamController<void>>((ref) {
  final controller = StreamController<void>.broadcast();
  ref.onDispose(controller.close);
  return controller;
});

BaseOptions _baseOptions(AppConfig config) => BaseOptions(
  baseUrl: config.apiBaseUrl,
  connectTimeout: config.connectTimeout,
  receiveTimeout: config.receiveTimeout,
  contentType: Headers.jsonContentType,
  responseType: ResponseType.json,
);

/// Gọi `POST /api/v1/auth/refresh` bằng Dio riêng (không qua [AuthInterceptor]
/// để tránh vòng lặp).
final tokenRefresherProvider = Provider<TokenRefresher>((ref) {
  return TokenRefresher(
    dio: Dio(_baseOptions(ref.watch(appConfigProvider))),
    storage: ref.watch(tokenStorageProvider),
  );
});

/// Dio dùng chung cho toàn app. Mọi request đi qua Nginx Gateway của backend.
final dioProvider = Provider<Dio>((ref) {
  final config = ref.watch(appConfigProvider);
  final dio = Dio(_baseOptions(config));

  dio.interceptors.add(
    AuthInterceptor(
      tokenStorage: ref.watch(tokenStorageProvider),
      refresher: ref.watch(tokenRefresherProvider),
      retry: dio.fetch,
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

/// Đổi refresh token lấy cặp token mới. BE xoay vòng refresh token: mỗi lần
/// gọi trả token mới và hủy token cũ, nên luôn ghi đè cả hai.
class TokenRefresher {
  TokenRefresher({required this.dio, required this.storage});

  final Dio dio;
  final TokenStorage storage;
  Future<String?>? _inFlight;

  /// Trả access token mới, hoặc `null` khi phiên hết thật (không có refresh
  /// token / BE từ chối với 400, 401, 403). Lỗi tạm thời (mất mạng, 5xx, phản
  /// hồi sai định dạng) thì ném [TemporaryRefreshFailure]: giữ phiên, thử lại
  /// sau. Nhiều lời gọi cùng lúc dùng chung một request.
  Future<String?> refresh() =>
      _inFlight ??= _refresh().whenComplete(() => _inFlight = null);

  Future<String?> _refresh() async {
    final refreshToken = await storage.readRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) return null;
    try {
      final res = await dio.post<Object?>(
        ApiPaths.refresh,
        data: {'refresh_token': refreshToken},
      );
      final (access, refresh) = unwrapResponse(res.data, (data) {
        final json = data! as JsonMap;
        return (
          json['access_token'] as String,
          json['refresh_token'] as String?,
        );
      });
      await storage.writeTokens(access: access, refresh: refresh);
      return access;
    } on DioException catch (e) {
      if (const {400, 401, 403}.contains(e.response?.statusCode)) return null;
      throw TemporaryRefreshFailure(e);
    } on ApiException catch (e) {
      // Body không phải ApiResponse (vd. trang HTML của wifi công cộng).
      throw TemporaryRefreshFailure(e);
    } on TypeError catch (e) {
      // Thiếu `access_token` / sai kiểu.
      throw TemporaryRefreshFailure(e);
    }
  }
}

/// Gia hạn phiên chưa được vì lỗi tạm thời. Không đăng xuất, không xóa token.
class TemporaryRefreshFailure implements Exception {
  const TemporaryRefreshFailure(this.cause);

  final Object cause;

  @override
  String toString() => 'TemporaryRefreshFailure($cause)';
}

/// Gắn `Authorization: Bearer <token>` vào mọi request và gia hạn phiên:
/// - Trước khi gửi: token đã/sắp hết hạn (theo `exp`) thì refresh trước. BE
///   trả 403 body rỗng (không phải 401) cho token hết hạn, nên không thể chờ
///   lỗi mới refresh.
/// - Gặp 401: refresh một lần rồi gọi lại request cũ.
/// Refresh thất bại thì gọi [onUnauthorized] (đăng xuất).
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required this.tokenStorage,
    required this.refresher,
    required this.retry,
    required this.onUnauthorized,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final TokenStorage tokenStorage;
  final TokenRefresher refresher;
  final Future<Response<dynamic>> Function(RequestOptions) retry;
  final VoidCallback onUnauthorized;
  final DateTime Function() _clock;

  /// Còn ít hơn chừng này thì coi như hết hạn, refresh trước.
  static const refreshMargin = Duration(seconds: 30);
  static const _retriedKey = 'auth_retried';

  static bool _isPublic(RequestOptions o) =>
      ApiPaths.public.any(o.path.endsWith);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!_isPublic(options)) {
      var token = await tokenStorage.readToken();
      if (token != null &&
          JwtDecoder.isExpired(token, now: _clock().add(refreshMargin))) {
        token = await _refreshOrNull() ?? token;
      }
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    if (err.response?.statusCode != 401 || _isPublic(options)) {
      return handler.next(err);
    }
    if (options.extra[_retriedKey] == true) {
      onUnauthorized();
      return handler.next(err);
    }

    // Request khác có thể đã refresh xong trong lúc request này chờ: token
    // đang lưu khác token đã gửi thì dùng luôn, không refresh lần nữa.
    final sent = options.headers['Authorization'];
    final stored = await tokenStorage.readToken();
    final token = stored != null && sent != 'Bearer $stored'
        ? stored
        : await _refreshOrNull();
    if (token == null) return handler.next(err);

    options
      ..headers['Authorization'] = 'Bearer $token'
      ..extra[_retriedKey] = true;
    try {
      handler.resolve(await retry(options));
    } on DioException catch (e) {
      handler.next(e);
    }
  }

  /// Token mới, hoặc `null` khi BE từ chối (đã báo [onUnauthorized]) hoặc lỗi
  /// tạm thời (giữ phiên, để request tự báo lỗi).
  Future<String?> _refreshOrNull() async {
    try {
      final token = await refresher.refresh();
      if (token == null) onUnauthorized();
      return token;
    } on TemporaryRefreshFailure {
      return null;
    }
  }
}
