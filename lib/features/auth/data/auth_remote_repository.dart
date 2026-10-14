import 'package:dio/dio.dart';

import '../../../core/auth/jwt_decoder.dart';
import '../../../core/auth/session.dart';
import '../../../core/auth/user_role.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/api_response.dart';
import '../domain/auth_repository.dart';

/// Gọi API thật của Auth Service (qua Nginx: `/api/auth/*`).
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
        '/api/auth/login',
        data: {'email': email, 'password': password},
      );
      // data: { accessToken, role, tenantId, userId }
      return unwrapResponse<Session>(res.data, (data) {
        final json = data! as JsonMap;
        final token = json['accessToken'] as String;
        return Session(
          accessToken: token,
          userId: Json.asInt(json['userId']) ?? 0,
          role: UserRole.fromBackend(json['role'] as String?),
          tenantId: Json.asInt(json['tenantId']),
          email: email,
          expiresAt: JwtDecoder.expiry(token),
        );
      });
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  @override
  Future<void> logout() async {
    try {
      await _dio.post<Object?>('/api/auth/logout');
    } on DioException {
      // JWT là stateless: dù gọi logout lỗi, app vẫn xóa token ở máy.
    }
  }

  @override
  Future<void> forgotPassword(String email) async {
    try {
      await _dio.post<Object?>(
        '/api/auth/forgot-password',
        data: {'email': email},
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  @override
  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    try {
      await _dio.post<Object?>(
        '/api/auth/reset-password',
        data: {'token': token, 'newPassword': newPassword},
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
