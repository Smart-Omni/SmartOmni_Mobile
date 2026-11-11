import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartomni_mobile/core/network/api_paths.dart';
import 'package:smartomni_mobile/features/account/data/account_repositories.dart';

import '../helpers/fake_backend.dart';
import '../helpers/test_app.dart';

/// `UserProfileResponse` như BE gửi (snake_case).
Map<String, Object?> _user({int? tenantId}) => {
  'id': 7,
  'email': 'owner@shop.vn',
  'full_name': 'Nguyễn Chủ',
  'phone': '0901234567',
  'role': 'TENANT_ADMIN',
  'status': 'ACTIVE',
  'tenant_id': tenantId,
  'subdomain': 'shopdemo',
};

void main() {
  group('AccountRemoteRepository', () {
    test('users/me snake_case + tenants/me storefront.storeName', () async {
      final backend = FakeBackend((o) async {
        if (o.path == ApiPaths.usersMe) return (200, ok(_user(tenantId: 3)));
        // TenantProfileResponse: camelCase.
        return (
          200,
          ok({
            'id': 3,
            'companyName': 'Công ty Shop Demo',
            'storefront': {'storeName': 'Shop Demo'},
          }),
        );
      });
      final profile = await AccountRemoteRepository(
        fakeDio(backend),
      ).getProfile();

      expect(profile.fullName, 'Nguyễn Chủ');
      expect(profile.email, 'owner@shop.vn');
      expect(profile.phone, '0901234567');
      expect(profile.storeName, 'Shop Demo');
    });

    test('storefront trống → dùng companyName', () async {
      final backend = FakeBackend(
        (o) async => o.path == ApiPaths.usersMe
            ? (200, ok(_user(tenantId: 3)))
            : (200, ok({'companyName': 'Công ty Shop Demo'})),
      );
      final profile = await AccountRemoteRepository(
        fakeDio(backend),
      ).getProfile();
      expect(profile.storeName, 'Công ty Shop Demo');
    });

    test('khách không có tenant: không gọi tenants/me', () async {
      final backend = FakeBackend((o) async => (200, ok(_user())));
      final profile = await AccountRemoteRepository(
        fakeDio(backend),
      ).getProfile();

      expect(backend.calls(ApiPaths.tenantsMe), 0);
      expect(profile.fullName, 'Nguyễn Chủ');
      expect(profile.storeName, isNull);
    });

    test('tenants/me lỗi: vẫn có tên, email', () async {
      final backend = FakeBackend(
        (o) async => o.path == ApiPaths.usersMe
            ? (200, ok(_user(tenantId: 3)))
            : (400, apiError('Không tìm thấy thông tin tenant trong context')),
      );
      final profile = await AccountRemoteRepository(
        fakeDio(backend),
      ).getProfile();
      expect(profile.fullName, 'Nguyễn Chủ');
      expect(profile.storeName, isNull);
    });

    test('tenants/me trả body sai định dạng: vẫn có tên, email', () async {
      for (final body in [
        ok({'storefront': 'Shop Demo'}), // storefront không phải object
        ok('không phải object'),
        '<html>wifi</html>', // không phải ApiResponse
      ]) {
        final backend = FakeBackend(
          (o) async => o.path == ApiPaths.usersMe
              ? (200, ok(_user(tenantId: 3)))
              : (200, body),
        );
        final profile = await AccountRemoteRepository(
          fakeDio(backend),
        ).getProfile();
        expect(profile.fullName, 'Nguyễn Chủ', reason: '$body');
        expect(profile.email, 'owner@shop.vn', reason: '$body');
        expect(profile.storeName, isNull, reason: '$body');
      }
    });

    test('đổi mật khẩu gửi current_password, new_password, '
        'confirm_password', () async {
      final backend = FakeBackend((o) async => (200, ok()));
      await AccountRemoteRepository(fakeDio(backend)).changePassword(
        currentPassword: 'cu123456',
        newPassword: 'moi123456',
        confirmPassword: 'moi123456',
      );
      final req = backend.requests.single;
      expect(req.path, ApiPaths.changePassword);
      expect(req.data, {
        'current_password': 'cu123456',
        'new_password': 'moi123456',
        'confirm_password': 'moi123456',
      });
    });
  });

  testWidgets('M-50: thẻ hồ sơ hiện họ tên, email, vai trò · tên cửa hàng', (
    tester,
  ) async {
    await loginAs(tester, 'admin@demo.vn', tallView: true);
    await tester.tap(find.byKey(const Key('nav_more')));
    await tester.pumpAndSettle();

    final card = find.byKey(const Key('profile_card'));
    Finder inCard(String text) =>
        find.descendant(of: card, matching: find.text(text));
    expect(inCard('Trần Chủ Shop'), findsOneWidget);
    expect(inCard('admin@demo.vn'), findsOneWidget);
    expect(inCard('Chủ cửa hàng · Shop Demo'), findsOneWidget);
    // M-50 không có hàng Đổi mật khẩu (DESIGN.md mục 8b).
    expect(find.text('Đổi mật khẩu'), findsNothing);
  });
}
