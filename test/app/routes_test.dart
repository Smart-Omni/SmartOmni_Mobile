import 'package:flutter_test/flutter_test.dart';
import 'package:smartomni_mobile/app/router/routes.dart';
import 'package:smartomni_mobile/core/auth/session.dart';
import 'package:smartomni_mobile/core/auth/user_role.dart';
import 'package:smartomni_mobile/features/auth/presentation/auth_controller.dart';

Authenticated _as(UserRole role) => Authenticated(
  Session(accessToken: 't', userId: 1, role: role, tenantId: 1),
);

void main() {
  group('resolveRedirect', () {
    test('đang khôi phục phiên -> splash', () {
      expect(resolveRedirect(const AuthUnknown(), Routes.login), Routes.splash);
      expect(resolveRedirect(const AuthUnknown(), Routes.splash), isNull);
    });

    test('chưa đăng nhập -> chỉ được ở login / quên mật khẩu', () {
      const s = Unauthenticated();
      expect(resolveRedirect(s, Routes.merchantOrders), Routes.login);
      expect(resolveRedirect(s, Routes.customerShop), Routes.login);
      expect(resolveRedirect(s, Routes.login), isNull);
      expect(resolveRedirect(s, Routes.forgotPassword), isNull);
      expect(resolveRedirect(s, Routes.resetPassword), isNull);
    });

    test('đăng nhập xong vào trang chủ theo role', () {
      expect(
        resolveRedirect(_as(UserRole.staff), Routes.login),
        Routes.merchantDashboard,
      );
      expect(
        resolveRedirect(_as(UserRole.tenantAdmin), Routes.splash),
        Routes.merchantDashboard,
      );
      expect(
        resolveRedirect(_as(UserRole.customer), Routes.login),
        Routes.customerShop,
      );
    });

    test('không cho đi sai khu vực', () {
      expect(
        resolveRedirect(_as(UserRole.customer), Routes.merchantOrders),
        Routes.customerShop,
      );
      expect(
        resolveRedirect(_as(UserRole.staff), Routes.customerLoyalty),
        Routes.merchantDashboard,
      );
    });

    test('Staff không vào được chức năng của Tenant Admin', () {
      expect(
        resolveRedirect(_as(UserRole.staff), Routes.merchantMarketplace),
        Routes.merchantMore,
      );
      expect(
        resolveRedirect(_as(UserRole.tenantAdmin), Routes.merchantMarketplace),
        isNull,
      );
    });

    test('route /dev/ chỉ vào được ở bản dev', () {
      const s = Unauthenticated();
      expect(
        resolveRedirect(s, Routes.devGallery, allowDevRoutes: true),
        isNull,
      );
      expect(resolveRedirect(s, Routes.devGallery), Routes.login);
      expect(
        resolveRedirect(_as(UserRole.staff), Routes.devGallery),
        Routes.merchantDashboard,
      );
    });
  });
}
