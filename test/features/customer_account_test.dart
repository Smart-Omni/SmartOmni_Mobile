import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartomni_mobile/core/design/design.dart';
import 'package:smartomni_mobile/features/customer_shop/presentation/customer_shops_screen.dart';

import '../helpers/test_app.dart';

Future<void> _openAccount(WidgetTester tester) async {
  await loginAs(tester, 'customer@demo.vn', tallView: true);
  await tester.tap(find.text('Tài khoản'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('C-40: hồ sơ khách, cửa hàng đã tham gia, Cài đặt, Đăng xuất', (
    tester,
  ) async {
    await _openAccount(tester);

    final profile = find.byKey(const Key('customer_profile'));
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
    for (final title in [
      'Sửa thông tin cá nhân',
      'Đổi mật khẩu',
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
  });

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
