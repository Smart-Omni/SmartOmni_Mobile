import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartomni_mobile/core/design/design.dart';
import 'package:smartomni_mobile/core/models/platform.dart';
import 'package:smartomni_mobile/core/network/api_paths.dart';
import 'package:smartomni_mobile/core/utils/clock.dart';
import 'package:smartomni_mobile/features/orders/data/orders_repositories.dart';
import 'package:smartomni_mobile/features/orders/domain/order.dart';
import 'package:smartomni_mobile/features/orders/presentation/order_detail_screen.dart';
import 'package:smartomni_mobile/features/orders/presentation/orders_providers.dart';

import '../helpers/fake_backend.dart';
import '../helpers/test_app.dart';

final _now = DateTime(2026, 11, 11, 10);

/// Entity `Order` như BE trả (camelCase, enum viết HOA).
Map<String, Object?> _order(
  int id,
  String status, {
  String platform = 'SHOPEE',
  String code = '',
}) => {
  'id': id,
  'tenantId': 3,
  'platform': platform,
  'connectionId': 1,
  'platformOrderId': code.isEmpty ? 'SO$id' : code,
  'status': status,
  'slaDeadline': '2026-11-12T10:00:00Z',
  'trackingNumber': status == 'PENDING' ? null : 'SPX$id',
  'customerName': 'Khách $id',
  'customerPhone': '0901234567',
  'shippingAddress': 'Hà Nội',
  'totalAmount': 259000.0,
  'source': 'WEBHOOK',
  'createdAt': _now.subtract(Duration(hours: id)).toUtc().toIso8601String(),
};

Map<String, Object?> _page(List<Object?> content) => ok({
  'content': content,
  'totalElements': content.length,
  'totalPages': 1,
  'number': 0,
  'size': 20,
  'last': true,
});

/// BE giả của Order Service: đổi trạng thái thật sự lưu lại.
FakeBackend _orderService(List<Map<String, Object?>> orders) =>
    FakeBackend((RequestOptions o) async {
      final status = RegExp(r'/orders/(\d+)/status$').firstMatch(o.path);
      if (status != null) {
        final order = orders.firstWhere(
          (e) => e['id'] == int.parse(status.group(1)!),
        );
        order['status'] = o.queryParameters['status'];
        return (200, ok(order));
      }
      if (o.path == ApiPaths.returns) {
        return (200, ok({'id': 1, 'status': 'REQUESTED'}));
      }
      return (200, _page(orders));
    });

void main() {
  group('OrdersRemoteRepository', () {
    test(
      'đọc Page<Order>: TIKTOK_SHOP, ON_HOLD, mã vận đơn, hạn SLA',
      () async {
        final backend = _orderService([
          _order(7, 'ON_HOLD', platform: 'TIKTOK_SHOP'),
          _order(8, 'TO_SHIP'),
        ]);
        final page = await OrdersRemoteRepository(
          fakeDio(backend),
        ).fetchOrders();

        final req = backend.requests.single;
        expect(req.path, ApiPaths.orders);
        expect(req.queryParameters, {
          'page': 0,
          'size': 20,
          'sort': 'createdAt,desc',
        });
        final hold = page.items.first;
        expect(hold.platform, Platform.tiktokShop);
        expect(hold.status, OrderStatus.onHold);
        expect(hold.customerName, 'Khách 7');
        expect(hold.trackingNumber, 'SPX7');
        expect(hold.slaDeadline, isNotNull);
        expect(hold.items, isEmpty);
      },
    );

    test('Chuẩn bị hàng gửi PATCH ?status=TO_SHIP', () async {
      final backend = _orderService([_order(1, 'PENDING')]);
      final updated = await OrdersRemoteRepository(
        fakeDio(backend),
      ).updateStatus(1, OrderStatus.toShip);

      final req = backend.requests.single;
      expect(req.method, 'PATCH');
      expect(req.path, ApiPaths.orderStatus(1));
      expect(req.queryParameters, {'status': 'TO_SHIP'});
      expect(updated.status, OrderStatus.toShip);
    });

    test('chuyển sang trạng thái khác TO_SHIP: không gửi request', () async {
      final backend = _orderService([_order(1, 'PENDING')]);
      final repo = OrdersRemoteRepository(fakeDio(backend));
      for (final s in OrderStatus.values.where(
        (s) => s != OrderStatus.toShip,
      )) {
        await expectLater(repo.updateStatus(1, s), throwsArgumentError);
      }
      expect(backend.requests, isEmpty);
    });

    test('hoàn/trả gửi POST /api/v1/returns { orderId, reason }', () async {
      final backend = _orderService([]);
      await OrdersRemoteRepository(
        fakeDio(backend),
      ).createReturn(orderId: 8, reason: 'Hàng lỗi/hư hỏng: rách');
      final req = backend.requests.single;
      expect(req.method, 'POST');
      expect(req.path, ApiPaths.returns);
      expect(req.data, {'orderId': 8, 'reason': 'Hàng lỗi/hư hỏng: rách'});
    });
  });

  group('M-20/M-21 với BE thật', () {
    Future<FakeBackend> openOrders(
      WidgetTester tester,
      List<Map<String, Object?>> orders,
    ) async {
      final backend = _orderService(orders);
      await loginAs(
        tester,
        'staff@demo.vn',
        tallView: true,
        overrides: [
          clockProvider.overrideWithValue(() => _now),
          ordersUseRemoteProvider.overrideWithValue(true),
          ordersRepositoryProvider.overrideWithValue(
            OrdersRemoteRepository(fakeDio(backend)),
          ),
        ],
      );
      await tester.tap(find.byKey(const Key('nav_orders')));
      await tester.pumpAndSettle();
      return backend;
    }

    testWidgets('M-20 rỗng: trạng thái trống, không banner mẫu', (
      tester,
    ) async {
      await openOrders(tester, []);
      expect(find.byKey(const Key('orders_mock_banner')), findsNothing);
      expect(find.text('Chưa có đơn nào'), findsOneWidget);
    });

    testWidgets('M-21: thẻ Sản phẩm trống; Chuẩn bị hàng → Chờ giao', (
      tester,
    ) async {
      final backend = await openOrders(tester, [_order(1, 'PENDING')]);
      await tapVisible(tester, find.byKey(const Key('order_1')));

      expect(find.byType(OrderDetailScreen), findsOneWidget);
      expect(find.byKey(const Key('order_mock_banner')), findsNothing);
      expect(
        find.text('Chưa có danh sách sản phẩm cho đơn này.'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('order_prepare')));
      await tester.pumpAndSettle();
      expect(backend.calls(ApiPaths.orderStatus(1)), 1);
      expect(
        tester.widget<SoStatusTag>(find.byKey(const Key('order_status'))).label,
        'Chờ giao',
      );
      expect(find.byKey(const Key('order_prepare')), findsNothing);
    });

    testWidgets('M-21 Tạm giữ: không có Chuẩn bị hàng', (tester) async {
      await openOrders(tester, [_order(5, 'ON_HOLD')]);
      await tapVisible(tester, find.byKey(const Key('order_5')));
      expect(find.byKey(const Key('order_prepare')), findsNothing);
      expect(find.byKey(const Key('order_on_hold_banner')), findsOneWidget);
    });

    testWidgets('sheet hoàn/trả: không banner mẫu, gửi lên BE', (tester) async {
      final backend = await openOrders(tester, [_order(2, 'DELIVERING')]);
      await tapVisible(tester, find.byKey(const Key('order_2')));
      await tapVisible(tester, find.byKey(const Key('order_return')));

      expect(find.byKey(const Key('return_mock_banner')), findsNothing);
      await tester.tap(find.byKey(const Key('reason_damaged')));
      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('return_note')),
          matching: find.byType(EditableText),
        ),
        'rách đường may',
      );
      await tester.tap(find.byKey(const Key('return_submit')));
      await tester.pumpAndSettle();

      expect(backend.calls(ApiPaths.returns), 1);
      expect(find.text('Đã ghi nhận hoàn/trả'), findsOneWidget);
    });

    testWidgets('Hộp thư (mock) dùng đơn mẫu riêng; thẻ đơn không mở M-21 '
        'khi M-21 gọi BE thật', (tester) async {
      await openOrders(tester, [_order(1, 'PENDING')]);
      await tester.tap(find.byKey(const Key('nav_more')));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.byKey(const Key('menu_inbox')));
      await tapVisible(tester, find.byKey(const Key('conversation_1')));

      // Hội thoại mẫu vẫn thấy đơn mẫu của nó (BE thật không có đơn này).
      final card = find.byKey(const Key('conversation_order'));
      expect(card, findsOneWidget);
      await tapVisible(tester, card);
      expect(find.byType(OrderDetailScreen), findsNothing);

      // Sheet "Gắn đơn" liệt kê đơn mẫu, không phải đơn của BE thật.
      await tester.tap(find.byKey(const Key('so_app_bar_leading')));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.byKey(const Key('conversation_2')));
      await tapVisible(
        tester,
        find.byKey(const Key('conversation_find_order')),
      );
      expect(find.byKey(const Key('attach_order_1')), findsNothing);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w.key is ValueKey<String> &&
              (w.key! as ValueKey<String>).value.startsWith('attach_order_10'),
        ),
        findsWidgets,
      );
    });
  });
}
