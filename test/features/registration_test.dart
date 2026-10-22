import 'package:flutter_test/flutter_test.dart';
import 'package:smartomni_mobile/core/auth/user_role.dart';
import 'package:smartomni_mobile/core/utils/mock_delay.dart';
import 'package:smartomni_mobile/features/auth/data/auth_mock_repository.dart';
import 'package:smartomni_mobile/features/auth/data/mock_account_store.dart';
import 'package:smartomni_mobile/features/auth/data/registration_mock_repository.dart';
import 'package:smartomni_mobile/features/auth/domain/registration.dart';
import 'package:smartomni_mobile/features/customer_shop/data/customer_shop_mock_repository.dart';
import 'package:smartomni_mobile/features/loyalty/data/loyalty_mock_repository.dart';

RegistrationRequest _request({
  String email = 'moi@khach.vn',
  String shopCode = 'bepxinh',
}) => RegistrationRequest(
  shopCode: shopCode,
  fullName: 'Nguyễn Văn An',
  email: email,
  phone: '0901234567',
  password: 'matkhau123',
);

void main() {
  setUp(() => MockDelay.enabled = false);

  group('OtpRules', () {
    test('đủ 6 chữ số', () {
      expect(OtpRules.isComplete('123456'), isTrue);
      expect(OtpRules.isComplete('12345'), isFalse);
      expect(OtpRules.isComplete('1234567'), isFalse);
      expect(OtpRules.isComplete('12a456'), isFalse);
    });

    test('đếm ngược mm:ss, làm tròn lên, không âm', () {
      expect(OtpRules.countdown(OtpRules.resendAfter), '00:45');
      expect(OtpRules.countdown(const Duration(milliseconds: 300)), '00:01');
      expect(OtpRules.countdown(const Duration(seconds: 75)), '01:15');
      expect(OtpRules.countdown(const Duration(seconds: -3)), '00:00');
    });
  });

  group('RegistrationMockRepository', () {
    late MockAccountStore store;
    late RegistrationMockRepository repo;

    setUp(() {
      store = MockAccountStore();
      repo = RegistrationMockRepository(store);
    });

    test('email demo hoặc đã đăng ký thì báo emailTaken', () async {
      await expectLater(
        repo.register(_request(email: 'Customer@demo.vn')),
        throwsA(
          isA<RegisterFailure>().having(
            (f) => f.kind,
            'kind',
            RegisterFailureKind.emailTaken,
          ),
        ),
      );
      await repo.register(_request());
      await repo.verifyEmail(email: 'moi@khach.vn', otp: MockAccounts.otp);
      await expectLater(
        repo.register(_request()),
        throwsA(isA<RegisterFailure>()),
      );
    });

    test('mã cửa hàng không có thì báo shopNotFound', () async {
      await expectLater(
        repo.register(_request(shopCode: 'KHONGCO')),
        throwsA(
          isA<RegisterFailure>().having(
            (f) => f.kind,
            'kind',
            RegisterFailureKind.shopNotFound,
          ),
        ),
      );
    });

    test('sai OTP trừ lượt; hết lượt thì phải gửi lại mã', () async {
      await repo.register(_request());
      for (var left = OtpRules.maxAttempts - 1; left > 0; left--) {
        await expectLater(
          repo.verifyEmail(email: 'moi@khach.vn', otp: '000000'),
          throwsA(
            isA<OtpFailure>()
                .having((f) => f.kind, 'kind', OtpFailureKind.wrongCode)
                .having((f) => f.attemptsLeft, 'left', left),
          ),
        );
      }
      await expectLater(
        repo.verifyEmail(email: 'moi@khach.vn', otp: '000000'),
        throwsA(
          isA<OtpFailure>().having(
            (f) => f.kind,
            'kind',
            OtpFailureKind.noAttemptsLeft,
          ),
        ),
      );
      // Hết lượt: mã đúng cũng không nhận cho tới khi gửi lại.
      await expectLater(
        repo.verifyEmail(email: 'moi@khach.vn', otp: MockAccounts.otp),
        throwsA(isA<OtpFailure>()),
      );
      await repo.resendOtp('moi@khach.vn');
      final session = await repo.verifyEmail(
        email: 'moi@khach.vn',
        otp: MockAccounts.otp,
      );
      expect(session.role, UserRole.customer);
      expect(session.tenantId, 3);
    });

    test('chưa đăng ký mà xác minh thì báo lỗi khác', () async {
      await expectLater(
        repo.verifyEmail(email: 'ai@khach.vn', otp: MockAccounts.otp),
        throwsA(
          isA<OtpFailure>().having((f) => f.kind, 'kind', OtpFailureKind.other),
        ),
      );
    });

    test('xác minh xong: đăng nhập lại được bằng mật khẩu riêng', () async {
      await repo.register(_request());
      await repo.verifyEmail(email: 'moi@khach.vn', otp: MockAccounts.otp);
      final auth = AuthMockRepository(store: store);
      final session = await auth.login(
        email: 'moi@khach.vn',
        password: 'matkhau123',
      );
      expect(session.tenantId, 3);
      await expectLater(
        auth.login(email: 'moi@khach.vn', password: MockAccounts.password),
        throwsA(anything),
      );
    });
  });

  test(
    'tài khoản mới: chỉ cửa hàng đã chọn, 0 điểm, chưa có voucher',
    () async {
      final shops = await CustomerShopMockRepository(
        joinedCodes: const ['BEPXINH'],
      ).listMyShops();
      expect(shops.map((s) => s.name), ['Bếp Xinh']);
      expect(shops.single.points, 0);

      final loyalty = LoyaltyMockRepository(demoData: false);
      expect((await loyalty.getSummary(1)).totalPoints, 0);
      expect(await loyalty.getVouchers(1), isEmpty);
    },
  );
}
