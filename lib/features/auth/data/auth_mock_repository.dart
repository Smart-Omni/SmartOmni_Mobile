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
    'disabled@demo.vn': (4, 'MANAGER', 1),
    'shoplocked@demo.vn': (5, 'ADMIN', 2),
  };

  /// Tài khoản bị vô hiệu hóa (để xem trạng thái lỗi).
  static const disabled = 'disabled@demo.vn';

  /// Tài khoản thuộc cửa hàng bị khóa (để xem trạng thái lỗi).
  static const tenantLocked = 'shoplocked@demo.vn';

  /// Sai mật khẩu bao nhiêu lần thì khóa (giống `AuthService` của backend).
  static const maxFailedAttempts = 5;
  static const lockDuration = Duration(minutes: 15);

  /// Mã đặt lại mật khẩu dùng được.
  static const resetCode = '123456';

  /// Mã đặt lại mật khẩu đã hết hạn.
  static const expiredResetCode = '000000';
}

/// Giả lập Auth Service. Thông điệp lỗi chép đúng như backend (không dấu)
/// để phần phân loại lỗi (`LoginFailure.fromApi`) chạy giống khi có API thật.
class AuthMockRepository implements AuthRepository {
  AuthMockRepository({DateTime Function()? clock})
    : _now = clock ?? DateTime.now;

  final DateTime Function() _now;
  final _failedAttempts = <String, int>{};
  final _lockedUntil = <String, DateTime>{};

  static const _invalid = ApiException(
    type: ApiErrorType.unauthorized,
    message: 'Email hoac mat khau khong dung',
    statusCode: 401,
  );

  @override
  Future<Session> login({
    required String email,
    required String password,
  }) async {
    await MockDelay.short();
    final key = email.trim().toLowerCase();
    final account = MockAccounts.accounts[key];
    // Giống backend: không tiết lộ email có tồn tại hay không.
    if (account == null) throw _invalid;

    final lockedUntil = _lockedUntil[key];
    if (lockedUntil != null && lockedUntil.isAfter(_now())) {
      throw const ApiException(
        type: ApiErrorType.forbidden,
        message:
            'Tai khoan tam khoa do dang nhap sai qua nhieu lan. '
            'Vui long thu lai sau.',
        statusCode: 403,
      );
    }
    if (key == MockAccounts.disabled) {
      throw const ApiException(
        type: ApiErrorType.forbidden,
        message: 'Tai khoan da bi vo hieu hoa',
        statusCode: 403,
      );
    }
    if (password != MockAccounts.password) {
      final count = (_failedAttempts[key] ?? 0) + 1;
      _failedAttempts[key] = count;
      if (count >= MockAccounts.maxFailedAttempts) {
        _lockedUntil[key] = _now().add(MockAccounts.lockDuration);
        _failedAttempts.remove(key);
      }
      throw _invalid;
    }
    if (key == MockAccounts.tenantLocked) {
      // Backend chưa làm (TODO FR-003): dự kiến trả 403 như sau.
      throw const ApiException(
        type: ApiErrorType.forbidden,
        message: 'Cua hang dang bi khoa',
        statusCode: 403,
        code: 'TENANT_LOCKED',
      );
    }

    _failedAttempts.remove(key);
    _lockedUntil.remove(key);
    final (userId, role, tenantId) = account;
    final exp = _now().add(const Duration(hours: 24));
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
  }) async {
    await MockDelay.short();
    if (token == MockAccounts.expiredResetCode) {
      throw const ApiException(
        type: ApiErrorType.validation,
        message: 'Token dat lai mat khau da het han',
        statusCode: 400,
      );
    }
    if (token != MockAccounts.resetCode) {
      throw const ApiException(
        type: ApiErrorType.validation,
        message: 'Token khong hop le hoac da duoc su dung',
        statusCode: 400,
      );
    }
  }
}
