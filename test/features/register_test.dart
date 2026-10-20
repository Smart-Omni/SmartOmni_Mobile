import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartomni_mobile/features/auth/presentation/login_screen.dart';
import 'package:smartomni_mobile/features/auth/presentation/register_otp_screen.dart';
import 'package:smartomni_mobile/features/auth/presentation/register_screen.dart';

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
}
