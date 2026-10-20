import '../domain/registration.dart';

/// Tài khoản khách đăng ký ở chế độ mock.
class MockCustomerAccount {
  const MockCustomerAccount({
    required this.userId,
    required this.tenantId,
    required this.request,
  });

  final int userId;

  /// Cửa hàng khách tham gia khi đăng ký.
  final int tenantId;
  final RegistrationRequest request;

  String get email => request.email;
  String get password => request.password;
  String get shopCode => request.shopCode;
}

/// Kho tài khoản khách đăng ký mới, chỉ nằm trong bộ nhớ (tắt app là mất).
/// Đăng nhập mock, cửa hàng mock và điểm mock cùng đọc kho này, để tài khoản
/// mới đăng nhập lại được và chỉ thấy cửa hàng vừa tham gia.
class MockAccountStore {
  final _accounts = <String, MockCustomerAccount>{};

  /// Đăng ký xong, chờ nhập OTP.
  final _pending = <String, MockCustomerAccount>{};
  final _attemptsLeft = <String, int>{};

  static String _key(String email) => email.trim().toLowerCase();

  MockCustomerAccount? find(String? email) =>
      email == null ? null : _accounts[_key(email)];

  MockCustomerAccount? pending(String email) => _pending[_key(email)];

  void addPending(MockCustomerAccount account) {
    _pending[_key(account.email)] = account;
    resetAttempts(account.email);
  }

  void resetAttempts(String email) =>
      _attemptsLeft[_key(email)] = OtpRules.maxAttempts;

  /// Trừ một lượt thử, trả về số lượt còn lại.
  int useAttempt(String email) {
    final left = (_attemptsLeft[_key(email)] ?? 0) - 1;
    _attemptsLeft[_key(email)] = left < 0 ? 0 : left;
    return _attemptsLeft[_key(email)]!;
  }

  int attemptsLeft(String email) => _attemptsLeft[_key(email)] ?? 0;

  /// OTP đúng: tài khoản chờ thành tài khoản dùng được.
  MockCustomerAccount activate(String email) {
    final account = _pending.remove(_key(email))!;
    _attemptsLeft.remove(_key(email));
    _accounts[_key(email)] = account;
    return account;
  }

  /// Id cho tài khoản mới, không trùng tài khoản demo.
  int nextUserId() => 100 + _accounts.length + _pending.length;
}
