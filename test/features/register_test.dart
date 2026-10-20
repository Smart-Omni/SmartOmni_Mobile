import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:smartomni_mobile/app/router/routes.dart';
import 'package:smartomni_mobile/core/design/design.dart';
import 'package:smartomni_mobile/features/auth/data/auth_mock_repository.dart';
import 'package:smartomni_mobile/features/auth/presentation/login_screen.dart';
import 'package:smartomni_mobile/features/auth/presentation/register_otp_screen.dart';
import 'package:smartomni_mobile/features/auth/presentation/register_screen.dart';
import 'package:smartomni_mobile/features/storefront/presentation/storefront_screens.dart';

import '../helpers/test_app.dart';

Future<void> _openRegister(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await pumpSmartOmniApp(tester);
  await tapVisible(tester, find.byKey(const Key('login_register')));
  expect(find.byType(RegisterScreen), findsOneWidget);
}

Finder _field(String key) => find.descendant(
  of: find.byKey(Key(key)),
  matching: find.byType(EditableText),
);

Future<void> _fill(
  WidgetTester tester, {
  String shop = 'SHOPDEMO',
  String email = 'moi@khach.vn',
}) async {
  await tester.enterText(_field('register_shop_code'), shop);
  await tester.enterText(_field('register_name'), 'Nguyễn Văn An');
  await tester.enterText(_field('register_email'), email);
  await tester.enterText(_field('register_phone'), '0901234567');
  await tester.enterText(_field('register_password'), 'matkhau123');
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pumpAndSettle();
}

/// Đăng ký Bếp Xinh với moi@khach.vn, dừng ở màn OTP.
Future<void> _toOtp(WidgetTester tester) async {
  await _openRegister(tester);
  await _fill(tester, shop: 'BEPXINH');
  await tapVisible(tester, find.byKey(const Key('register_terms')));
  await tapVisible(tester, find.byKey(const Key('register_submit')));
  expect(find.byType(RegisterOtpScreen), findsOneWidget);
}

Future<void> _enterOtp(WidgetTester tester, String code) async {
  await tester.enterText(find.byKey(const Key('otp_input')), code);
  await tester.pump();
}

SoButton _otpSubmit(WidgetTester tester) =>
    tester.widget<SoButton>(find.byKey(const Key('otp_submit')));

void main() {
  testWidgets('A-02 -> A-05; "Đã có tài khoản? Đăng nhập" quay lại', (
    tester,
  ) async {
    await _openRegister(tester);
    expect(find.text('Tạo tài khoản khách'), findsOneWidget);

    await tapVisible(tester, find.byKey(const Key('register_login')));
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('Bấm khi trống: lỗi từng ô và ô điều khoản', (tester) async {
    await _openRegister(tester);
    await tapVisible(tester, find.byKey(const Key('register_submit')));

    expect(find.text('Mã cửa hàng không được để trống'), findsOneWidget);
    expect(find.text('Họ tên không được để trống'), findsOneWidget);
    expect(find.text('Email không được để trống'), findsOneWidget);
    expect(find.text('Số điện thoại không được để trống'), findsOneWidget);
    expect(find.byKey(const Key('register_terms_error')), findsOneWidget);

    await tapVisible(tester, find.byKey(const Key('register_terms')));
    expect(find.byKey(const Key('register_terms_error')), findsNothing);
    expect(find.byType(RegisterOtpScreen), findsNothing);
  });

  testWidgets('Tra mã: tìm thấy thì có thẻ, sai mã thì lỗi dưới ô', (
    tester,
  ) async {
    await _openRegister(tester);
    await tester.enterText(_field('register_shop_code'), 'khongco');
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('register_shop_error')), findsOneWidget);

    await tester.enterText(_field('register_shop_code'), 'bepxinh');
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('register_shop_preview')), findsOneWidget);
    expect(find.text('Bếp Xinh'), findsOneWidget);
  });

  testWidgets('Email đã có tài khoản thì báo dưới ô Email', (tester) async {
    await _openRegister(tester);
    await _fill(tester, email: 'customer@demo.vn');
    await tapVisible(tester, find.byKey(const Key('register_terms')));
    await tapVisible(tester, find.byKey(const Key('register_submit')));

    expect(find.byKey(const Key('register_email_error')), findsOneWidget);
    expect(find.text('Email này đã có tài khoản.'), findsOneWidget);
    expect(find.byType(RegisterOtpScreen), findsNothing);
  });

  testWidgets('Đủ thông tin -> màn OTP', (tester) async {
    await _openRegister(tester);
    await _fill(tester);
    await tapVisible(tester, find.byKey(const Key('register_terms')));
    await tapVisible(tester, find.byKey(const Key('register_submit')));

    expect(find.byType(RegisterOtpScreen), findsOneWidget);
    expect(find.textContaining('moi@khach.vn'), findsWidgets);
  });

  testWidgets('A-05 vừa bề rộng 360dp, chữ phóng 1.3', (tester) async {
    useNarrowPhone(tester);
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpSmartOmniApp(tester);
    await tapVisible(tester, find.byKey(const Key('login_register')));
    expect(tester.takeException(), isNull);
    await tester.drag(
      find.byType(CustomScrollView).last,
      const Offset(0, -1500),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('OTP: thẻ cửa hàng, nút chỉ bật khi đủ 6 số, sai thì báo '
      'số lần còn lại', (tester) async {
    await _toOtp(tester);
    expect(find.text('Bạn sẽ tham gia'), findsOneWidget);
    expect(find.text('Bếp Xinh · Standard'), findsOneWidget);

    await _enterOtp(tester, '12345');
    expect(_otpSubmit(tester).onPressed, isNull);

    await _enterOtp(tester, '111111');
    await tester.tap(find.byKey(const Key('otp_submit')));
    await tester.pumpAndSettle();
    expect(find.text('Mã không đúng. Bạn còn 4 lần thử.'), findsOneWidget);

    // Gõ lại thì xóa lỗi.
    await _enterOtp(tester, '1');
    expect(find.byKey(const Key('otp_error')), findsNothing);
  });

  testWidgets('OTP: đếm ngược 45 giây rồi Gửi lại mã; sai 5 lần thì khóa, '
      'gửi lại thì mở', (tester) async {
    await _toOtp(tester);
    expect(find.text('Gửi lại sau 00:45'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Gửi lại sau 00:44'), findsOneWidget);

    for (var i = 0; i < 5; i++) {
      await _enterOtp(tester, '111111');
      await tester.tap(find.byKey(const Key('otp_submit')));
      await tester.pumpAndSettle();
    }
    expect(
      find.text('Bạn đã nhập sai quá nhiều lần. Hãy gửi lại mã.'),
      findsOneWidget,
    );
    await _enterOtp(tester, MockAccounts.otp);
    expect(_otpSubmit(tester).onPressed, isNull);

    await tester.pump(const Duration(seconds: 45));
    expect(find.byKey(const Key('otp_countdown')), findsNothing);
    await tester.tap(find.byKey(const Key('otp_resend')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('otp_error')), findsNothing);
    expect(find.text('Gửi lại sau 00:45'), findsOneWidget);
  });

  testWidgets('OTP đúng -> vào C-10 của cửa hàng vừa tham gia; đăng xuất '
      'rồi đăng nhập lại được', (tester) async {
    await _toOtp(tester);
    await _enterOtp(tester, MockAccounts.otp);
    await tester.tap(find.byKey(const Key('otp_submit')));
    await tester.pumpAndSettle();

    expect(find.byType(StorefrontScreen), findsOneWidget);
    expect(
      tester
          .widget<SoShopSwitcher>(find.byKey(const Key('shop_switcher')))
          .name,
      'Bếp Xinh',
    );

    await tester.tap(find.text('Tài khoản'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const Key('logout_tile')));
    await tester.tap(find.byKey(const Key('logout_confirm')));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('login_email')),
      'moi@khach.vn',
    );
    await tester.enterText(
      find.byKey(const Key('login_password')),
      'matkhau123',
    );
    await tester.tap(find.byKey(const Key('login_submit')));
    await tester.pumpAndSettle();
    expect(find.byType(StorefrontScreen), findsOneWidget);
  });

  testWidgets('OTP mở thẳng (không qua A-05) thì có nút Về Đăng ký', (
    tester,
  ) async {
    await pumpSmartOmniApp(tester);
    final context = tester.element(find.byType(LoginScreen));
    GoRouter.of(context).go(Routes.registerVerify);
    await tester.pumpAndSettle();
    expect(find.text('Chưa có thông tin đăng ký'), findsOneWidget);
    await tester.tap(find.text('Về Đăng ký'));
    await tester.pumpAndSettle();
    expect(find.byType(RegisterScreen), findsOneWidget);
  });
}
