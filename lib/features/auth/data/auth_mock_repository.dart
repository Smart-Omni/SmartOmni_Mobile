import '../../../core/auth/jwt_decoder.dart';
import '../../../core/auth/session.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/mock_delay.dart';
import '../domain/auth_repository.dart';

/// Tài khoản demo cho chế độ mock. Mật khẩu chung: [MockAccounts.password].
class MockAccounts {
  const MockAccounts._();

  static const password = '12345678';

  /// email -> (userId, role backend, tenantId)
  static const accounts = <String, (int, String, int?)>{
    'admin@demo.vn': (1, 'ADMIN', 1),
    'staff@demo.vn': (2, 'MANAGER', 1),
    'customer@demo.vn': (3, 'CUSTOMER', 1),
    'superadmin@demo.vn': (99, 'SUPER_ADMIN', null),
  };
}

class AuthMockRepository implements AuthRepository {
  @override
  Future<Session> login({
    required String email,
    required String password,
  }) async {
    await MockDelay.short();
    final account = MockAccounts.accounts[email.trim().toLowerCase()];
    if (account == null || password != MockAccounts.password) {
      // Giống thông điệp backend: không tiết lộ email có tồn tại hay không.
      throw const ApiException(
        type: ApiErrorType.unauthorized,
        message: 'Email hoặc mật khẩu không đúng',
        statusCode: 401,
      );
    }
    final (userId, role, tenantId) = account;
    final exp = DateTime.now().add(const Duration(hours: 24));
    final token = JwtDecoder.buildUnsigned({
      'sub': '$userId',
      'role': role,
      'tenantId': ?tenantId,
      'email': email,
      'exp': exp.millisecondsSinceEpoch ~/ 1000,
    });
    return Session.fromToken(token)!;
  }

  @override
  Future<void> logout() => MockDelay.short();

  @override
  Future<void> forgotPassword(String email) => MockDelay.short();

  @override
  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) => MockDelay.short();
}
