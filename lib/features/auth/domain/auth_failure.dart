import '../../../core/network/api_exception.dart';
import '../../../core/utils/text_fold.dart';

/// Lý do đăng nhập thất bại. Màn A-02 hiển thị mỗi loại một kiểu
/// (docs/DESIGN.md mục 8, "A-02 lỗi").
enum LoginFailureKind {
  /// Sai email hoặc mật khẩu (401). Viền đỏ ở ô mật khẩu.
  invalidCredentials,

  /// Sai 5 lần, backend khóa 15 phút (403 `ACCOUNT_TEMP_LOCKED`).
  temporarilyLocked,

  /// Tài khoản bị vô hiệu hóa (403 `ACCOUNT_DISABLED`).
  accountDisabled,

  /// Cửa hàng (tenant) bị khóa. Backend chưa làm (TODO FR-003), dự kiến 403
  /// `TENANT_LOCKED`.
  tenantLocked,

  /// Super Admin: không dùng trên mobile, chỉ dùng web.
  superAdmin,

  /// Lỗi khác (mạng, máy chủ…): hiện nguyên thông điệp.
  other,
}

/// Lỗi đăng nhập đã phân loại. `AuthController.login` ném lỗi này.
class LoginFailure implements Exception {
  const LoginFailure(this.kind, this.message);

  final LoginFailureKind kind;

  /// Thông điệp gốc (dùng khi [kind] là [LoginFailureKind.other]).
  final String message;

  /// Phân loại [ApiException] từ `POST /api/auth/login`.
  ///
  /// Backend hiện chỉ trả `message` (không dấu) chứ chưa trả `errorCode`, nên
  /// ưu tiên [ApiException.code] nếu có, không thì dựa vào status + nội dung.
  factory LoginFailure.fromApi(ApiException e) {
    final kind = switch (e.code) {
      'INVALID_CREDENTIALS' => LoginFailureKind.invalidCredentials,
      'ACCOUNT_TEMP_LOCKED' => LoginFailureKind.temporarilyLocked,
      'ACCOUNT_DISABLED' => LoginFailureKind.accountDisabled,
      'TENANT_LOCKED' => LoginFailureKind.tenantLocked,
      _ => _kindFromMessage(e),
    };
    return LoginFailure(kind, e.message);
  }

  static LoginFailureKind _kindFromMessage(ApiException e) {
    final text = foldVietnamese(e.message);
    if (e.statusCode == 401 || e.type == ApiErrorType.unauthorized) {
      return LoginFailureKind.invalidCredentials;
    }
    if (e.statusCode == 403 || e.type == ApiErrorType.forbidden) {
      if (text.contains('tam khoa')) return LoginFailureKind.temporarilyLocked;
      if (text.contains('vo hieu')) return LoginFailureKind.accountDisabled;
      if (text.contains('cua hang') || text.contains('tenant')) {
        return LoginFailureKind.tenantLocked;
      }
    }
    return LoginFailureKind.other;
  }

  @override
  String toString() => 'LoginFailure($kind): $message';
}

/// Lý do đặt lại mật khẩu thất bại (A-04).
enum ResetFailureKind {
  /// Mã hết hạn (quá 30 phút). Hiện banner + "Gửi lại mã".
  expired,

  /// Mã sai hoặc đã dùng. Viền đỏ ở ô mã.
  invalidCode,
  other,
}

class ResetFailure implements Exception {
  const ResetFailure(this.kind, this.message);

  final ResetFailureKind kind;
  final String message;

  /// Phân loại lỗi từ `POST /api/auth/reset-password` (backend trả 400).
  factory ResetFailure.fromApi(ApiException e) {
    final text = foldVietnamese(e.message);
    final kind = e.type != ApiErrorType.validation
        ? ResetFailureKind.other
        : text.contains('het han')
        ? ResetFailureKind.expired
        : text.contains('token') || text.contains('ma ')
        ? ResetFailureKind.invalidCode
        : ResetFailureKind.other;
    return ResetFailure(kind, e.message);
  }

  @override
  String toString() => 'ResetFailure($kind): $message';
}
