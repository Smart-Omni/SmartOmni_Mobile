import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartomni_mobile/core/design/design.dart';
import 'package:smartomni_mobile/core/models/platform.dart';
import 'package:smartomni_mobile/core/utils/formatters.dart';
import 'package:smartomni_mobile/features/auth/data/auth_mock_repository.dart';
import 'package:smartomni_mobile/features/dashboard/data/dashboard_data.dart';
import 'package:smartomni_mobile/features/orders/domain/order.dart';
import 'package:smartomni_mobile/features/orders/presentation/order_ui.dart';
import 'package:smartomni_mobile/features/orders/presentation/orders_screen.dart';

import '../helpers/test_app.dart';

Future<void> _loginAs(WidgetTester tester, String email) async {
  await pumpSmartOmniApp(tester);
  await tester.enterText(find.byKey(const Key('login_email')), email);
  await tester.enterText(
    find.byKey(const Key('login_password')),
    MockAccounts.password,
  );
  await tester.tap(find.byKey(const Key('login_submit')));
  await tester.pumpAndSettle();
}

void _useNarrowPhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(360, 780);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _scrollToBottom(WidgetTester tester) async {
  await tester.drag(find.byType(ListView).first, const Offset(0, -2000));
  await tester.pumpAndSettle();
}

void main() {
  group('Formatters', () {
    test('compactVnd rút gọn số lớn', () {
      expect(Formatters.compactVnd(3870000), '3,87 tr');
      expect(Formatters.compactVnd(12000000), '12 tr');
      expect(Formatters.compactVnd(1250000000), '1,25 tỷ');
      expect(Formatters.compactVnd(870000), '870.000 ₫');
    });

    test('percent làm tròn', () {
      expect(Formatters.percent(0.634), '63%');
      expect(Formatters.percent(0), '0%');
    });
  });

  test('channelShare: tỉ trọng theo kênh, tổng 0 thì 0', () {
    const s = DashboardSummary(
      shopName: 'S',
      ordersToday: 0,
      pendingOrders: 0,
      toShipOrders: 0,
      revenueToday: 0,
      revenue7Days: [],
      lowStockSkus: 0,
      revenueByChannel: {Platform.shopee: 300, Platform.tiktokShop: 100},
      aiAlerts: [],
    );
    expect(s.channelShare(Platform.shopee), 0.75);
    expect(s.channelShare(Platform.tiktokShop), 0.25);

    const empty = DashboardSummary(
      shopName: 'S',
      ordersToday: 0,
      pendingOrders: 0,
      toShipOrders: 0,
      revenueToday: 0,
      revenue7Days: [],
      lowStockSkus: 0,
      revenueByChannel: {},
      aiAlerts: [],
    );
    expect(empty.channelShare(Platform.shopee), 0);
  });

  test('trạng thái đơn -> tông nhãn theo DESIGN.md', () {
    expect(OrderStatus.pending.soStatus, SoStatus.warning);
    expect(OrderStatus.toShip.soStatus, SoStatus.kraft);
    expect(OrderStatus.shipped.soStatus, SoStatus.info);
    expect(OrderStatus.delivering.soStatus, SoStatus.info);
    expect(OrderStatus.completed.soStatus, SoStatus.success);
    expect(OrderStatus.cancelled.soStatus, SoStatus.neutral);
    expect(OrderStatus.returned.soStatus, SoStatus.danger);
  });

  test('productSummary gộp nhiều sản phẩm', () {
    const item = OrderItem(skuCode: 'A', name: 'Áo', quantity: 1, unitPrice: 1);
    Order order(List<OrderItem> items) => Order(
      id: 1,
      platform: Platform.shopee,
      platformOrderId: 'X',
      status: OrderStatus.pending,
      totalAmount: 1,
      items: items,
    );
    expect(order([item]).productSummary, 'Áo');
    expect(order([item, item]).productSummary, 'Áo và 1 sản phẩm khác');
    expect(order([]).productSummary, 'Chưa có thông tin sản phẩm');
  });

  testWidgets('Staff: 4 ô việc, không có doanh thu, 3 đơn cần xử lý', (
    tester,
  ) async {
    await _loginAs(tester, 'staff@demo.vn');

    expect(find.text('Shop Demo · Nhân viên'), findsOneWidget);
    expect(find.byKey(const Key('tile_to_ship')), findsOneWidget);
    expect(find.byKey(const Key('tile_revenue_today')), findsNothing);
    expect(find.textContaining('DOANH THU'), findsNothing);
    expect(find.byType(SoOrderRow), findsNWidgets(3));

    await tester.ensureVisible(find.byKey(const Key('pending_see_all')));
    await tester.tap(find.byKey(const Key('pending_see_all')));
    await tester.pumpAndSettle();
    expect(find.byType(OrdersScreen), findsOneWidget);
  });

  testWidgets('Admin: ô doanh thu thay ô Chờ giao, có 2 thẻ doanh thu', (
    tester,
  ) async {
    await _loginAs(tester, 'admin@demo.vn');

    expect(find.text('Shop Demo · Chủ cửa hàng'), findsOneWidget);
    expect(find.byKey(const Key('tile_revenue_today')), findsOneWidget);
    expect(find.byKey(const Key('tile_to_ship')), findsNothing);
    expect(find.text('3,87 tr'), findsWidgets);
    expect(find.text('DOANH THU THEO KÊNH'), findsOneWidget);
    expect(find.text('63%'), findsOneWidget); // 2,45 tr / 3,87 tr
    expect(find.byType(SoOrderRow), findsNothing);

    // Chạm cột ngày đầu -> nhãn số chuyển sang cột đó.
    await tester.scrollUntilVisible(
      find.byKey(const Key('revenue_bar_0')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('revenue_bar_0')));
    await tester.pumpAndSettle();
    expect(find.text('2,1 tr'), findsOneWidget);
  });

  testWidgets('M-10 vừa bề rộng 360dp cho cả Staff và Admin', (tester) async {
    _useNarrowPhone(tester);
    await _loginAs(tester, 'staff@demo.vn');
    await _scrollToBottom(tester);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Thêm'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('logout_tile')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('logout_tile')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('logout_confirm')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('login_email')),
      'admin@demo.vn',
    );
    await tester.enterText(
      find.byKey(const Key('login_password')),
      MockAccounts.password,
    );
    await tester.ensureVisible(find.byKey(const Key('login_submit')));
    await tester.tap(find.byKey(const Key('login_submit')));
    await tester.pumpAndSettle();
    await _scrollToBottom(tester);
    expect(tester.takeException(), isNull);
  });
}
