import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartomni_mobile/core/auth/jwt_decoder.dart';
import 'package:smartomni_mobile/features/auth/data/auth_mock_repository.dart';
import 'package:smartomni_mobile/features/auth/presentation/login_screen.dart';
import 'package:smartomni_mobile/features/dashboard/presentation/dashboard_screen.dart';
import 'package:smartomni_mobile/features/storefront/presentation/storefront_screens.dart';

import '../helpers/test_app.dart';

Future<void> _login(WidgetTester tester, String email, String password) async {
  await tester.enterText(find.byKey(const Key('login_email')), email);
  await tester.enterText(find.byKey(const Key('login_password')), password);
  await tester.tap(find.byKey(const Key('login_submit')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('chưa đăng nhập -> hiện màn đăng nhập chung', (tester) async {
    await pumpSmartOmniApp(tester);
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('bỏ trống form -> báo lỗi validate', (tester) async {
    await pumpSmartOmniApp(tester);
    await tester.tap(find.byKey(const Key('login_submit')));
    await tester.pumpAndSettle();
    expect(find.text('Email không được để trống'), findsOneWidget);
  });

  testWidgets('sai mật khẩu -> hiện lỗi, ở lại login', (tester) async {
    await pumpSmartOmniApp(tester);
    await _login(tester, 'staff@demo.vn', 'wrong-pass');
    expect(find.byKey(const Key('login_error')), findsOneWidget);
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('Staff đăng nhập -> vào Merchant (Việc hôm nay)', (tester) async {
    final storage = await pumpSmartOmniApp(tester);
    await _login(tester, 'staff@demo.vn', MockAccounts.password);
    expect(find.byType(DashboardScreen), findsOneWidget);
    expect(find.text('Việc hôm nay'), findsOneWidget);
    expect(await storage.readToken(), isNotNull);
  });

  testWidgets('Tenant Admin đăng nhập -> thấy tổng quan cửa hàng', (
    tester,
  ) async {
    await pumpSmartOmniApp(tester);
    await _login(tester, 'admin@demo.vn', MockAccounts.password);
    expect(find.text('Tổng quan cửa hàng'), findsOneWidget);
  });

  testWidgets('Customer đăng nhập -> vào Storefront', (tester) async {
    await pumpSmartOmniApp(tester);
    await _login(tester, 'customer@demo.vn', MockAccounts.password);
    expect(find.byType(StorefrontScreen), findsOneWidget);
  });

  testWidgets('Super Admin bị từ chối trên mobile', (tester) async {
    final storage = await pumpSmartOmniApp(tester);
    await _login(tester, 'superadmin@demo.vn', MockAccounts.password);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byKey(const Key('login_error')), findsOneWidget);
    expect(await storage.readToken(), isNull);
  });

  testWidgets('mở lại app với token còn hạn -> vào thẳng trang chủ', (
    tester,
  ) async {
    final token = JwtDecoder.buildUnsigned({
      'sub': '3',
      'role': 'CUSTOMER',
      'tenantId': 1,
      'exp':
          DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
          1000,
    });
    await pumpSmartOmniApp(tester, savedToken: token);
    expect(find.byType(StorefrontScreen), findsOneWidget);
  });

  testWidgets('token hết hạn -> về màn đăng nhập', (tester) async {
    final token = JwtDecoder.buildUnsigned({
      'sub': '2',
      'role': 'MANAGER',
      'exp': 1000,
    });
    final storage = await pumpSmartOmniApp(tester, savedToken: token);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(await storage.readToken(), isNull);
  });

  testWidgets('đăng xuất -> quay về login', (tester) async {
    final storage = await pumpSmartOmniApp(tester);
    await _login(tester, 'staff@demo.vn', MockAccounts.password);

    await tester.tap(find.text('Thêm'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('logout_tile')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('logout_tile')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('logout_confirm')));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(await storage.readToken(), isNull);
  });

  testWidgets('Staff không thấy menu Kết nối sàn, Admin thì thấy', (
    tester,
  ) async {
    await pumpSmartOmniApp(tester);
    await _login(tester, 'staff@demo.vn', MockAccounts.password);
    await tester.tap(find.text('Thêm'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('menu_marketplace')), findsNothing);
  });
}
