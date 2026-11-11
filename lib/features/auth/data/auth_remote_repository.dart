import 'package:dio/dio.dart';

import '../../../core/auth/jwt_decoder.dart';
import '../../../core/auth/session.dart';
import '../../../core/auth/user_role.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/api_paths.dart';
import '../../../core/network/api_response.dart';
import '../domain/auth_repository.dart';

/// Đọc `AuthResponse` của BE (login, register, refresh), tên trường snake_case:
/// `{ access_token, refresh_token, token_type, expires_in, user_info: { id,
/// email, full_name, phone, avatar, role, tenant_id, subdomain } }`.
Session sessionFromAuthResponse(JsonMap json) {
  final token = json['access_token'] as String;
  final info = json['user_info'] as JsonMap? ?? const {};
  return Session(
    accessToken: token,
    refreshToken: json['refresh_token'] as String?,
    userId: Json.asInt(info['id']) ?? 0,
    role: UserRole.fromBackend(info['role'] as String?),
    tenantId: Json.asInt(info['tenant_id']),
    email: info['email'] as String?,
    fullName: info['full_name'] as String?,
    expiresAt: JwtDecoder.expiry(token),
  );
}

/// Gọi API thật của Auth Service (đường dẫn ở [ApiPaths]).
class AuthRemoteRepository implements AuthRepository {
  AuthRemoteRepository(this._dio);

  final Dio _dio;

  @override
  Future<Session> login({
    required String email,
    required String password,
  }) async {
    try {
      final res = await _dio.post<Object?>(
        ApiPaths.login,
        data: {'email': email, 'password': password},
      );
      return unwrapResponse<Session>(
        res.data,
        (data) => sessionFromAuthResponse(data! as JsonMap),
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  @override
  Future<void> logout() async {
    try {
      await _dio.post<Object?>(ApiPaths.logout);
    } on DioException {
      // Dù gọi logout lỗi, app vẫn xóa token ở máy.
    }
  }

  @override
  Future<void> forgotPassword(String email) async {
    try {
      await _dio.post<Object?>(ApiPaths.forgotPassword, data: {'email': email});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  @override
  Future<void> resetPassword({
    required String token,
    required String newPassword,
    required String confirmPassword,
  }) async {
    try {
      await _dio.post<Object?>(
        ApiPaths.resetPassword,
        data: {
          'token': token,
          'new_password': newPassword,
          'confirm_password': confirmPassword,
        },
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
