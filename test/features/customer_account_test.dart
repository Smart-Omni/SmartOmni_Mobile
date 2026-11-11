import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartomni_mobile/core/design/design.dart';
import 'package:smartomni_mobile/features/account/presentation/change_password_sheet.dart';
import 'package:smartomni_mobile/features/auth/data/auth_mock_repository.dart';
import 'package:smartomni_mobile/features/auth/presentation/login_screen.dart';
import 'package:smartomni_mobile/features/customer_shop/presentation/customer_shops_screen.dart';

import '../helpers/test_app.dart';

Future<void> _openAccount(WidgetTester tester) async {
  await loginAs(tester, 'customer@demo.vn', tallView: true);
  await tester.tap(find.text('Tài khoản'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'C-40: hồ sơ khách (tên, email), cửa hàng đã tham gia, Cài đặt, Đăng xuất',
    (tester) async {
      await _openAccount(tester);

      final profile = find.byKey(const Key('customer_profile'));
      expect(
        find.descendant(of: profile, matching: find.text('Nguyễn Khách')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: profile, matching: find.text('customer@demo.vn')),
        findsOneWidget,
      );
      expect(find.textContaining('TENANT'), findsNothing);
      expect(find.textContaining('Cửa hàng #'), findsNothing);

      expect(find.text('Cửa hàng đã tham gia'), findsOneWidget);
      expect(find.byKey(const Key('account_shop_1')), findsOneWidget);
      expect(find.byKey(const Key('account_shop_2')), findsOneWidget);
      expect(find.text('620 điểm'), findsOneWidget);

      expect(find.text('Cài đặt'), findsOneWidget);
      expect(
        tester
            .widget<SoListRow>(find.byKey(const Key('account_change_password')))
            .comingSoon,
        isFalse,
      );
      for (final title in [
        'Sửa thông tin cá nhân',
        'Điều khoản & quyền riêng tư',
      ]) {
        final row = find.ancestor(
          of: find.text(title),
          matching: find.byType(SoListRow),
        );
        expect(tester.widget<SoListRow>(row).comingSoon, isTrue, reason: title);
      }
      expect(find.text('Thông báo voucher'), findsNothing);
      expect(find.byKey(const Key('logout_tile')), findsOneWidget);

      await tapVisible(tester, find.byKey(const Key('account_shop_2')));
      expect(find.byType(CustomerShopsScreen), findsOneWidget);
    },
  );

  testWidgets('C-40: Thêm mở sheet; tham gia xong về C-10 của cửa hàng mới', (
    tester,
  ) async {
    await _openAccount(tester);
    await tapVisible(tester, find.byKey(const Key('account_add_shop')));
    expect(find.text('Thêm cửa hàng'), findsWidgets);

    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('add_shop_code')),
        matching: find.byType(EditableText),
      ),
      'bepxinh',
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add_shop_join')));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<SoShopSwitcher>(find.byKey(const Key('shop_switcher')))
          .name,
      'Bếp Xinh',
    );
    expect(find.text('Đã tham gia Bếp Xinh'), findsOneWidget);
  });

  group('C-40 Đổi mật khẩu', () {
    Finder field(String key) => find.descendant(
      of: find.byKey(Key(key)),
      matching: find.byType(EditableText),
    );

    Future<void> openSheet(WidgetTester tester) async {
      await _openAccount(tester);
      await tapVisible(
        tester,
        find.byKey(const Key('account_change_password')),
      );
      expect(find.byType(ChangePasswordSheet), findsOneWidget);
    }

    Future<void> submit(
      WidgetTester tester, {
      required String current,
      required String next,
      required String confirm,
    }) async {
      await tester.enterText(field('change_password_current'), current);
      await tester.enterText(field('change_password_new'), next);
      await tester.enterText(field('change_password_confirm'), confirm);
      await tester.tap(find.byKey(const Key('change_password_submit')));
      await tester.pumpAndSettle();
    }

    testWidgets('kiểm tra tại máy: trống, ngắn, trùng mật khẩu cũ, nhập lại '
        'sai', (tester) async {
      await openSheet(tester);
      await tester.tap(find.byKey(const Key('change_password_submit')));
      await tester.pumpAndSettle();
      expect(find.text('Mật khẩu không được để trống'), findsWidgets);

      await submit(tester, current: '12345678', next: '123', confirm: '123');
      expect(find.text('Mật khẩu phải từ 6 đến 100 ký tự'), findsOneWidget);

      await submit(
        tester,
        current: '12345678',
        next: '12345678',
        confirm: '12345678',
      );
      expect(
        find.text('Mật khẩu mới phải khác mật khẩu hiện tại'),
        findsOneWidget,
      );

      await submit(
        tester,
        current: '12345678',
        next: 'matkhau-moi',
        confirm: 'matkhau-khac',
      );
      expect(find.text('Hai mật khẩu chưa giống nhau'), findsOneWidget);
      expect(find.byType(ChangePasswordSheet), findsOneWidget);
    });

    testWidgets('sai mật khẩu hiện tại: banner trong sheet, giữ chữ đã nhập', (
      tester,
    ) async {
      await openSheet(tester);
      await submit(
        tester,
        current: 'sai-roi',
        next: 'matkhau-moi',
        confirm: 'matkhau-moi',
      );
      expect(find.byKey(const Key('change_password_error')), findsOneWidget);
      expect(find.text('Mật khẩu hiện tại không chính xác'), findsOneWidget);
      expect(find.text('sai-roi'), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
    });

    testWidgets('đổi thành công: đăng xuất, xóa 2 token, về đăng nhập kèm '
        'thông báo; đăng nhập bằng mật khẩu mới được', (tester) async {
      final storage = await loginAs(tester, 'customer@demo.vn', tallView: true);
      await tester.tap(find.text('Tài khoản'));
      await tester.pumpAndSettle();
      await tapVisible(
        tester,
        find.byKey(const Key('account_change_password')),
      );
      await submit(
        tester,
        current: MockAccounts.password,
        next: 'matkhau-moi',
        confirm: 'matkhau-moi',
      );

      expect(find.byType(ChangePasswordSheet), findsNothing);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text(passwordChangedReason), findsOneWidget);
      expect(await storage.readToken(), isNull);
      expect(await storage.readRefreshToken(), isNull);

      await tester.enterText(
        find.byKey(const Key('login_email')),
        'customer@demo.vn',
      );
      await tester.enterText(
        find.byKey(const Key('login_password')),
        'matkhau-moi',
      );
      await tester.tap(find.byKey(const Key('login_submit')));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsNothing);
    });
  });

  testWidgets('C-40 vừa bề rộng 360dp, chữ phóng 1.3', (tester) async {
    useNarrowPhone(tester);
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await loginAs(tester, 'customer@demo.vn');
    await tester.tap(find.text('Tài khoản'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.drag(
      find.byType(CustomScrollView).last,
      const Offset(0, -1500),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
