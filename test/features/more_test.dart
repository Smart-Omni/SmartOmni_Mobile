import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartomni_mobile/core/design/design.dart';
import 'package:smartomni_mobile/features/ai_insights/presentation/ai_screens.dart';
import 'package:smartomni_mobile/features/auth/presentation/login_screen.dart';
import 'package:smartomni_mobile/features/marketplace/domain/marketplace_connection.dart';
import 'package:smartomni_mobile/features/marketplace/presentation/marketplace_screen.dart';
import 'package:smartomni_mobile/features/merchant_more/presentation/merchant_more_screen.dart';

import '../helpers/test_app.dart';

Future<void> _openMore(WidgetTester tester, String email) async {
  await loginAs(tester, email, tallView: true);
  await tester.tap(find.byKey(const Key('nav_more')));
  await tester.pumpAndSettle();
}

String _tag(WidgetTester tester, String key) =>
    tester.widget<SoStatusTag>(find.byKey(Key(key))).label;

void main() {
  test('nhãn trạng thái kết nối sàn', () {
    expect(ConnectionStatus.connected.tag, ('Đã kết nối', SoStatus.success));
    expect(ConnectionStatus.error.tag, ('Lỗi kết nối', SoStatus.danger));
    expect(null.tag, ('Chưa kết nối', SoStatus.neutral));
  });

  testWidgets('Staff: hồ sơ + Công cụ, không có Quản trị cửa hàng', (
    tester,
  ) async {
    await _openMore(tester, 'staff@demo.vn');

    expect(find.text('staff@demo.vn'), findsOneWidget);
    expect(find.text('Nhân viên · Cửa hàng #1'), findsOneWidget);
    expect(find.text('TENANT-1'), findsOneWidget);
    expect(find.text('CÔNG CỤ'), findsOneWidget);
    expect(find.text('QUẢN TRỊ CỬA HÀNG'), findsNothing);
    expect(find.byKey(const Key('menu_marketplace')), findsNothing);

    await tapVisible(tester, find.byKey(const Key('menu_ai')));
    expect(find.byType(AiInsightsScreen), findsOneWidget);
  });

  testWidgets('Admin: Kết nối sàn hiện trạng thái 2 sàn, mở được T-10', (
    tester,
  ) async {
    await _openMore(tester, 'admin@demo.vn');

    expect(find.text('QUẢN TRỊ CỬA HÀNG'), findsOneWidget);
    expect(_tag(tester, 'connection_shopee'), 'Đã kết nối');
    expect(_tag(tester, 'connection_tiktokShop'), 'Chưa kết nối');

    await tapVisible(tester, find.byKey(const Key('menu_marketplace')));
    expect(find.byType(MarketplaceScreen), findsOneWidget);
  });

  testWidgets('Đăng xuất: hủy thì ở lại, xác nhận thì về login', (
    tester,
  ) async {
    await _openMore(tester, 'admin@demo.vn');

    await tapVisible(tester, find.byKey(const Key('logout_tile')));
    expect(find.text('Bạn có chắc muốn đăng xuất?'), findsOneWidget);
    await tapVisible(tester, find.text('Hủy'));
    expect(find.byType(MerchantMoreScreen), findsOneWidget);

    await tapVisible(tester, find.byKey(const Key('logout_tile')));
    await tapVisible(tester, find.byKey(const Key('logout_confirm')));
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('M-50 bản Admin vừa bề rộng 360dp', (tester) async {
    useNarrowPhone(tester);
    await loginAs(tester, 'admin@demo.vn');
    await tester.tap(find.byKey(const Key('nav_more')));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).last, const Offset(0, -2000));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
