import 'package:flutter_test/flutter_test.dart';
import 'package:smartomni_mobile/core/network/api_exception.dart';
import 'package:smartomni_mobile/core/utils/mock_delay.dart';
import 'package:smartomni_mobile/core/utils/text_fold.dart';
import 'package:smartomni_mobile/features/auth/data/auth_mock_repository.dart';
import 'package:smartomni_mobile/features/auth/domain/auth_failure.dart';

ApiException _api(int status, String message, {String? code}) => ApiException(
  type: switch (status) {
    400 => ApiErrorType.validation,
    401 => ApiErrorType.unauthorized,
    403 => ApiErrorType.forbidden,
    _ => ApiErrorType.server,
  },
  message: message,
  statusCode: status,
  code: code,
);

void main() {
  test('foldVietnamese bỏ dấu và viết thường', () {
    expect(foldVietnamese('Tạm KHÓA Đơn Hàng'), 'tam khoa don hang');
    expect(foldVietnamese('Vô hiệu hóa'), 'vo hieu hoa');
  });

  group('LoginFailure.fromApi', () {
    LoginFailureKind kind(ApiException e) => LoginFailure.fromApi(e).kind;

    test('theo thông điệp backend hiện tại (không dấu, chưa có errorCode)', () {
      expect(
        kind(_api(401, 'Email hoac mat khau khong dung')),
        LoginFailureKind.invalidCredentials,
      );
      expect(
        kind(
          _api(
            403,
            'Tai khoan tam khoa do dang nhap sai qua nhieu lan. '
            'Vui long thu lai sau.',
          ),
        ),
        LoginFailureKind.temporarilyLocked,
      );
      expect(
        kind(_api(403, 'Tai khoan da bi vo hieu hoa')),
        LoginFailureKind.accountDisabled,
      );
      expect(
        kind(_api(403, 'Cửa hàng đang bị khóa')),
        LoginFailureKind.tenantLocked,
      );
    });

    test('ưu tiên errorCode nếu backend gửi', () {
      expect(
        kind(_api(403, 'bất kỳ', code: 'TENANT_LOCKED')),
        LoginFailureKind.tenantLocked,
      );
      expect(
        kind(_api(403, 'bất kỳ', code: 'ACCOUNT_TEMP_LOCKED')),
        LoginFailureKind.temporarilyLocked,
      );
    });

    test('lỗi mạng / máy chủ -> other, giữ thông điệp', () {
      final f = LoginFailure.fromApi(
        const ApiException(type: ApiErrorType.network, message: 'Mất mạng'),
      );
      expect(f.kind, LoginFailureKind.other);
      expect(f.message, 'Mất mạng');
      expect(kind(_api(500, 'Loi')), LoginFailureKind.other);
    });
  });

  test('ResetFailure.fromApi: hết hạn / mã sai / lỗi khác', () {
    expect(
      ResetFailure.fromApi(_api(400, 'Token dat lai mat khau da het han')).kind,
      ResetFailureKind.expired,
    );
    expect(
      ResetFailure.fromApi(
        _api(400, 'Token khong hop le hoac da duoc su dung'),
      ).kind,
      ResetFailureKind.invalidCode,
    );
    expect(
      ResetFailure.fromApi(_api(500, 'Token loi he thong')).kind,
      ResetFailureKind.other,
    );
  });

  test('mock: sai 5 lần -> khóa 15 phút, hết 15 phút thì mở', () async {
    MockDelay.enabled = false;
    var now = DateTime(2026, 10, 14, 9);
    final repo = AuthMockRepository(clock: () => now);
    Future<LoginFailureKind?> attempt(String password) async {
      try {
        await repo.login(email: 'staff@demo.vn', password: password);
        return null;
      } on ApiException catch (e) {
        return LoginFailure.fromApi(e).kind;
      }
    }

    for (var i = 0; i < MockAccounts.maxFailedAttempts; i++) {
      expect(await attempt('sai'), LoginFailureKind.invalidCredentials);
    }
    // Đúng mật khẩu vẫn bị chặn khi đang khóa.
    expect(
      await attempt(MockAccounts.password),
      LoginFailureKind.temporarilyLocked,
    );

    now = now.add(MockAccounts.lockDuration + const Duration(seconds: 1));
    expect(await attempt(MockAccounts.password), isNull);
  });
}
