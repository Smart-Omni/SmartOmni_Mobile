import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartomni_mobile/core/auth/jwt_decoder.dart';
import 'package:smartomni_mobile/features/auth/data/auth_mock_repository.dart';
import 'package:smartomni_mobile/features/auth/presentation/forgot_password_screen.dart';
import 'package:smartomni_mobile/features/auth/presentation/login_screen.dart';
import 'package:smartomni_mobile/features/dashboard/presentation/dashboard_screen.dart';
import 'package:smartomni_mobile/features/storefront/presentation/storefront_screens.dart';

import '../helpers/test_app.dart';

Future<void> _login(WidgetTester tester, String email, String password) async {
  await tester.enterText(find.byKey(const Key('login_email')), email);
  await tester.enterText(find.byKey(const Key('login_password')), password);
  await _tapKey(tester, 'login_submit');
}

Future<void> _tapKey(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

bool _submitEnabled(WidgetTester tester) => tester
    .widget<TextButton>(
      find.descendant(
        of: find.byKey(const Key('login_submit')),
        matching: find.byType(TextButton),
      ),
    )
    .enabled;

/// Từ A-02 đi tới A-04 qua A-03.
Future<void> _openResetScreen(WidgetTester tester) async {
  await _tapKey(tester, 'login_forgot');
  await tester.enterText(find.byKey(const Key('forgot_email')), 'a@b.vn');
  await _tapKey(tester, 'forgot_submit');
  expect(find.text('Kiểm tra hộp thư'), findsOneWidget);
  await tester.tap(find.text('Tôi đã có mã'));
  await tester.pumpAndSettle();
}

Future<void> _submitReset(
  WidgetTester tester,
  String code, {
  String password = 'matkhau-moi',
  String? confirm,
}) async {
  await tester.enterText(find.byKey(const Key('reset_code')), code);
  await tester.enterText(find.byKey(const Key('reset_password')), password);
  await tester.enterText(
    find.byKey(const Key('reset_confirm')),
    confirm ?? password,
  );
  await _tapKey(tester, 'reset_submit');
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

  testWidgets('sai mật khẩu 5 lần -> banner khóa 15 phút, nút vô hiệu', (
    tester,
  ) async {
    await pumpSmartOmniApp(tester);
    for (var i = 0; i < MockAccounts.maxFailedAttempts; i++) {
      await _login(tester, 'staff@demo.vn', 'wrong-pass');
    }
    await _login(tester, 'staff@demo.vn', MockAccounts.password);

    expect(find.text('Tài khoản tạm khóa 15 phút'), findsOneWidget);
    expect(_submitEnabled(tester), isFalse);

    // Link "Đặt lại mật khẩu" mở A-03.
    await tester.tap(find.text('Đặt lại mật khẩu'));
    await tester.pumpAndSettle();
    expect(find.byType(ForgotPasswordScreen), findsOneWidget);
  });

  testWidgets('cửa hàng bị khóa / tài khoản vô hiệu -> banner danger', (
    tester,
  ) async {
    await pumpSmartOmniApp(tester);
    await _login(tester, MockAccounts.tenantLocked, MockAccounts.password);
    expect(find.text('Cửa hàng đang bị khóa'), findsOneWidget);

    await _login(tester, MockAccounts.disabled, MockAccounts.password);
    expect(find.text('Tài khoản đã bị vô hiệu hóa'), findsOneWidget);
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('Super Admin -> banner web, "Dùng tài khoản khác" xóa form', (
    tester,
  ) async {
    await pumpSmartOmniApp(tester);
    await _login(tester, 'superadmin@demo.vn', MockAccounts.password);
    expect(find.text('Tài khoản này dùng trên web'), findsOneWidget);

    await _tapKey(tester, 'login_use_another');
    expect(find.byKey(const Key('login_error')), findsNothing);
    final email = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const Key('login_email')),
        matching: find.byType(EditableText),
      ),
    );
    expect(email.controller.text, isEmpty);
  });

  testWidgets('trạng thái lỗi vừa bề rộng 360dp', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pumpSmartOmniApp(tester);
    await _login(tester, MockAccounts.tenantLocked, MockAccounts.password);
    expect(tester.takeException(), isNull);
    await _login(tester, 'staff@demo.vn', 'wrong-pass');
    expect(find.text('Email hoặc mật khẩu không đúng.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('quên mật khẩu -> nhập mã -> đặt lại -> về login kèm toast', (
    tester,
  ) async {
    await pumpSmartOmniApp(tester);
    await _openResetScreen(tester);

    await _submitReset(tester, '999999');
    expect(find.byKey(const Key('reset_code_error')), findsOneWidget);

    await _submitReset(tester, MockAccounts.expiredResetCode);
    expect(find.text('Mã đặt lại đã hết hạn'), findsOneWidget);

    await _submitReset(tester, MockAccounts.resetCode);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(
      find.text('Đã đặt lại mật khẩu. Đăng nhập bằng mật khẩu mới.'),
      findsOneWidget,
    );
  });

  testWidgets('đặt lại mật khẩu: hai mật khẩu phải giống nhau', (tester) async {
    await pumpSmartOmniApp(tester);
    await _openResetScreen(tester);
    await _submitReset(
      tester,
      MockAccounts.resetCode,
      password: '12345678',
      confirm: '87654321',
    );
    expect(find.text('Hai mật khẩu chưa giống nhau'), findsOneWidget);
  });
}
