import '../../../core/auth/session.dart';

/// Hợp đồng (interface) cho chức năng xác thực.
///
/// Có 2 cài đặt:
/// - `AuthRemoteRepository`: gọi API thật `/api/v1/auth/*`.
/// - `AuthMockRepository`: dữ liệu giả, có sẵn tài khoản demo cho cả 3 role.
abstract class AuthRepository {
  /// POST /api/v1/auth/login
  Future<Session> login({required String email, required String password});

  /// POST /api/v1/auth/logout
  Future<void> logout();

  /// POST /api/v1/auth/forgot-password
  Future<void> forgotPassword(String email);

  /// POST /api/v1/auth/reset-password
  Future<void> resetPassword({
    required String token,
    required String newPassword,
    required String confirmPassword,
  });
}
