import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartomni_mobile/app/config/app_config.dart';
import 'package:smartomni_mobile/core/auth/jwt_decoder.dart';
import 'package:smartomni_mobile/core/auth/user_role.dart';
import 'package:smartomni_mobile/core/network/api_client.dart';
import 'package:smartomni_mobile/core/network/api_paths.dart';
import 'package:smartomni_mobile/core/storage/token_storage.dart';
import 'package:smartomni_mobile/features/auth/data/auth_remote_repository.dart';
import 'package:smartomni_mobile/features/auth/data/registration_remote_repository.dart';
import 'package:smartomni_mobile/features/auth/domain/registration.dart';
import 'package:smartomni_mobile/features/auth/domain/auth_failure.dart';
import 'package:smartomni_mobile/features/auth/presentation/auth_controller.dart';

import '../helpers/fake_backend.dart';

String _jwt(String role, Duration fromNow) => JwtDecoder.buildUnsigned({
  'sub': '7',
  'role': role,
  'tenantId': 3,
  'exp': DateTime.now().add(fromNow).millisecondsSinceEpoch ~/ 1000,
});

/// `AuthResponse` đúng như BE gửi (snake_case theo `@JsonProperty`).
Map<String, Object?> _authResponse(String role, {String refresh = 'r1'}) => {
  'access_token': _jwt(role, const Duration(hours: 24)),
  'refresh_token': refresh,
  'token_type': 'Bearer',
  'expires_in': 86400,
  'user_info': {
    'id': 7,
    'email': 'owner@shop.vn',
    'full_name': 'Nguyễn Chủ',
    'phone': '0901234567',
    'avatar': null,
    'role': role,
    'tenant_id': 3,
    'subdomain': 'shopdemo',
  },
};

void main() {
  group('AuthRemoteRepository', () {
    test('login đọc AuthResponse snake_case', () async {
      final backend = FakeBackend(
        (o) async => (200, ok(_authResponse('TENANT_ADMIN'))),
      );
      final session = await AuthRemoteRepository(
        fakeDio(backend),
      ).login(email: 'owner@shop.vn', password: '123456');

      expect(backend.requests.single.path, ApiPaths.login);
      expect(session.userId, 7);
      expect(session.role, UserRole.tenantAdmin);
      expect(session.tenantId, 3);
      expect(session.email, 'owner@shop.vn');
      expect(session.fullName, 'Nguyễn Chủ');
      expect(session.refreshToken, 'r1');
      expect(session.expiresAt, isNotNull);
    });

    test(
      'đặt lại mật khẩu gửi token, new_password, confirm_password',
      () async {
        final backend = FakeBackend((o) async => (200, ok()));
        await AuthRemoteRepository(fakeDio(backend)).resetPassword(
          token: 'abc',
          newPassword: 'matkhau1',
          confirmPassword: 'matkhau1',
        );

        final req = backend.requests.single;
        expect(req.path, ApiPaths.resetPassword);
        expect(req.data, {
          'token': 'abc',
          'new_password': 'matkhau1',
          'confirm_password': 'matkhau1',
        });
      },
    );
  });

  group('RegistrationRemoteRepository', () {
    const request = RegistrationRequest(
      shopCode: 'Shop-Demo',
      fullName: ' Trần Khách ',
      email: 'khach@mail.vn',
      phone: '0901234567',
      password: '123456',
    );

    test('gửi RegisterRequest snake_case, subdomain chữ thường, trả phiên '
        'CUSTOMER kèm refresh token', () async {
      final backend = FakeBackend(
        (o) async => (201, ok(_authResponse('CUSTOMER'))),
      );
      final session = await RegistrationRemoteRepository(
        fakeDio(backend),
      ).register(request);

      final req = backend.requests.single;
      expect(req.path, ApiPaths.register);
      expect(req.headers['Authorization'], isNull);
      expect(req.data, {
        'email': 'khach@mail.vn',
        'password': '123456',
        'full_name': 'Trần Khách',
        'phone': '0901234567',
        'subdomain': 'shop-demo',
      });
      expect(session!.role, UserRole.customer);
      expect(session.refreshToken, 'r1');
    });

    test('409 → email đã có tài khoản', () async {
      final backend = FakeBackend(
        (o) async => (409, apiError('Email đã được sử dụng trong hệ thống')),
      );
      await expectLater(
        RegistrationRemoteRepository(fakeDio(backend)).register(request),
        throwsA(
          isA<RegisterFailure>().having(
            (f) => f.kind,
            'kind',
            RegisterFailureKind.emailTaken,
          ),
        ),
      );
    });

    test('400 → lỗi khác, giữ message của BE', () async {
      final backend = FakeBackend(
        (o) async => (400, apiError('Mật khẩu phải từ 6 đến 100 ký tự')),
      );
      await expectLater(
        RegistrationRemoteRepository(fakeDio(backend)).register(request),
        throwsA(
          isA<RegisterFailure>()
              .having((f) => f.kind, 'kind', RegisterFailureKind.other)
              .having(
                (f) => f.message,
                'message',
                'Mật khẩu phải từ 6 đến 100 ký tự',
              ),
        ),
      );
    });
  });

  group('AuthController với BE thật', () {
    ProviderContainer container(FakeBackend backend, TokenStorage storage) {
      final c = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(
              flavor: Flavor.dev,
              apiBaseUrl: 'http://test',
              useMock: false,
            ),
          ),
          tokenStorageProvider.overrideWithValue(storage),
          dioProvider.overrideWithValue(fakeDio(backend)),
          tokenRefresherProvider.overrideWithValue(
            TokenRefresher(dio: fakeDio(backend), storage: storage),
          ),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    Future<AuthState> settled(ProviderContainer c) async {
      c.read(authControllerProvider);
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(Duration.zero);
        if (c.read(authControllerProvider) is! AuthUnknown) break;
      }
      return c.read(authControllerProvider);
    }

    test('SUPER_ADMIN bị từ chối, không lưu token', () async {
      final storage = InMemoryTokenStorage();
      final c = container(
        FakeBackend((o) async => (200, ok(_authResponse('SUPER_ADMIN')))),
        storage,
      );
      await settled(c);

      await expectLater(
        c
            .read(authControllerProvider.notifier)
            .login(email: 'root@smartomni.vn', password: '123456'),
        throwsA(
          isA<LoginFailure>().having(
            (f) => f.kind,
            'kind',
            LoginFailureKind.superAdmin,
          ),
        ),
      );
      expect(await storage.readToken(), isNull);
    });

    test('đăng nhập lưu cả access token và refresh token', () async {
      final storage = InMemoryTokenStorage();
      final c = container(
        FakeBackend((o) async => (200, ok(_authResponse('MANAGER')))),
        storage,
      );
      await settled(c);

      await c
          .read(authControllerProvider.notifier)
          .login(email: 'staff@shop.vn', password: '123456');

      expect(c.read(currentRoleProvider), UserRole.staff);
      expect(await storage.readToken(), isNotNull);
      expect(await storage.readRefreshToken(), 'r1');
    });

    test('mở lại app: access hết hạn + còn refresh token → gia hạn', () async {
      final storage = InMemoryTokenStorage(
        _jwt('TENANT_ADMIN', const Duration(minutes: -5)),
        'r1',
      );
      final backend = FakeBackend(
        (o) async => (200, ok(_authResponse('TENANT_ADMIN', refresh: 'r2'))),
      );
      final state = await settled(container(backend, storage));

      expect(state, isA<Authenticated>());
      expect(backend.calls(ApiPaths.refresh), 1);
      expect(await storage.readRefreshToken(), 'r2');
    });

    test('mở lại app: refresh bị từ chối → về đăng nhập, xóa token', () async {
      final storage = InMemoryTokenStorage(
        _jwt('TENANT_ADMIN', const Duration(minutes: -5)),
        'r1',
      );
      final backend = FakeBackend(
        (o) async =>
            (401, apiError('Refresh token không hợp lệ hoặc đã hết hạn')),
      );
      final state = await settled(container(backend, storage));

      expect(state, isA<Unauthenticated>());
      expect(await storage.readToken(), isNull);
      expect(await storage.readRefreshToken(), isNull);
    });
  });
}
