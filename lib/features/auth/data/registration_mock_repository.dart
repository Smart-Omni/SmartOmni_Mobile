import '../../../core/auth/session.dart';
import '../../../core/utils/mock_delay.dart';
import '../../customer_shop/data/customer_shop_mock_repository.dart';
import '../../customer_shop/domain/customer_shop.dart';
import '../domain/registration.dart';
import 'auth_mock_repository.dart';
import 'mock_account_store.dart';

/// Giả lập đăng ký khách + OTP. Mã OTP đúng: [MockAccounts.otp].
class RegistrationMockRepository implements RegistrationRepository {
  RegistrationMockRepository(this._store, {DateTime Function()? clock})
    : _now = clock ?? DateTime.now;

  final MockAccountStore _store;
  final DateTime Function() _now;

  @override
  Future<void> register(RegistrationRequest request) async {
    await MockDelay.short();
    final email = request.email.trim().toLowerCase();
    if (MockAccounts.accounts.containsKey(email) ||
        _store.find(email) != null) {
      throw const RegisterFailure(
        RegisterFailureKind.emailTaken,
        'Email này đã có tài khoản.',
      );
    }
    final code = normalizeShopCode(request.shopCode);
    final shop = CustomerShopMockRepository.all
        .where((s) => s.code == code)
        .firstOrNull;
    if (shop == null) {
      throw const RegisterFailure(
        RegisterFailureKind.shopNotFound,
        'Không tìm thấy cửa hàng với mã này.',
      );
    }
    _store.addPending(
      MockCustomerAccount(
        userId: _store.nextUserId(),
        tenantId: shop.tenantId,
        request: RegistrationRequest(
          shopCode: code,
          fullName: request.fullName.trim(),
          email: email,
          phone: request.phone,
          password: request.password,
        ),
      ),
    );
  }

  @override
  Future<void> resendOtp(String email) async {
    await MockDelay.short();
    _store.resetAttempts(email);
  }

  @override
  Future<Session> verifyEmail({
    required String email,
    required String otp,
  }) async {
    await MockDelay.short();
    if (_store.pending(email) == null) {
      throw const OtpFailure(
        OtpFailureKind.other,
        message: 'Phiên đăng ký đã hết. Hãy đăng ký lại.',
      );
    }
    if (_store.attemptsLeft(email) <= 0) {
      throw const OtpFailure(OtpFailureKind.noAttemptsLeft);
    }
    if (otp != MockAccounts.otp) {
      final left = _store.useAttempt(email);
      throw OtpFailure(
        left == 0 ? OtpFailureKind.noAttemptsLeft : OtpFailureKind.wrongCode,
        attemptsLeft: left,
      );
    }
    final account = _store.activate(email);
    return mockSession(
      userId: account.userId,
      role: 'CUSTOMER',
      tenantId: account.tenantId,
      email: account.email,
      now: _now(),
    );
  }
}
