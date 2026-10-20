import '../../../core/auth/session.dart';

/// Thông tin khách nhập ở A-05 Đăng ký.
class RegistrationRequest {
  const RegistrationRequest({
    required this.shopCode,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.password,
  });

  final String shopCode;
  final String fullName;
  final String email;
  final String phone;
  final String password;
}

enum RegisterFailureKind {
  /// Email đã có tài khoản. Báo dưới ô Email.
  emailTaken,

  /// Mã cửa hàng không tồn tại (hoặc cửa hàng vừa bị khóa).
  shopNotFound,
  other,
}

/// Lỗi đăng ký. `RegistrationRepository.register` ném lỗi này.
class RegisterFailure implements Exception {
  const RegisterFailure(this.kind, this.message);

  final RegisterFailureKind kind;
  final String message;

  @override
  String toString() => 'RegisterFailure($kind): $message';
}

enum OtpFailureKind {
  /// Mã sai, còn [OtpFailure.attemptsLeft] lần thử.
  wrongCode,

  /// Hết lượt thử: phải gửi lại mã.
  noAttemptsLeft,
  other,
}

/// Lỗi xác minh OTP. `RegistrationRepository.verifyEmail` ném lỗi này.
class OtpFailure implements Exception {
  const OtpFailure(this.kind, {this.attemptsLeft = 0, this.message = ''});

  final OtpFailureKind kind;
  final int attemptsLeft;
  final String message;

  @override
  String toString() => 'OtpFailure($kind, còn $attemptsLeft)';
}

/// Quy tắc OTP xác minh email (USER_FLOWS: 6 số, gửi lại sau 45 giây).
class OtpRules {
  const OtpRules._();

  static const length = 6;
  static const resendAfter = Duration(seconds: 45);

  /// Sai bao nhiêu lần thì phải gửi lại mã.
  /// shortcut: ngưỡng thật do backend quyết định.
  static const maxAttempts = 5;

  static final _code = RegExp(r'^\d{6}$');

  /// Đủ 6 chữ số chưa.
  static bool isComplete(String code) => _code.hasMatch(code);

  /// Chữ đếm ngược "00:45". Làm tròn lên để không hiện "00:00" khi còn
  /// chưa tới 1 giây.
  static String countdown(Duration left) {
    final seconds = left.isNegative ? 0 : (left.inMilliseconds / 1000).ceil();
    final mm = (seconds ~/ 60).toString().padLeft(2, '0');
    final ss = (seconds % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }
}

/// ⚠️ Backend CHƯA có các API này (docs/API_CONTRACT.md mục 3) -> mock.
abstract class RegistrationRepository {
  /// POST /api/customers/register { shopCode, fullName, email, phone,
  /// password } -> gửi OTP tới email. Ném [RegisterFailure].
  Future<void> register(RegistrationRequest request);

  /// Gửi lại OTP. Chưa có trong API_CONTRACT; dự kiến gọi lại `register`.
  Future<void> resendOtp(String email);

  /// POST /api/customers/verify-email { email, otp } -> { accessToken }.
  /// Ném [OtpFailure].
  Future<Session> verifyEmail({required String email, required String otp});
}
