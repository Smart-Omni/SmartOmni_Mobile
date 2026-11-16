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

/// `OrderItemDto` như BE `3eb89ec` trả: `skuCode`, `productName` có trong DTO
/// nhưng `OrderService.getOrderDetail` không điền (null).
Map<String, Object?> _item(
  int id,
  int skuId,
  int qty,
  num price, {
  String? skuCode,
  String? productName,
  String? imageUrl,
}) => {
  'id': id,
  'skuId': skuId,
  'skuCode': skuCode,
  'productName': productName,
  'quantity': qty,
  'unitPrice': price,
  'subtotal': price * qty,
  'imageUrl': imageUrl,
};

/// `OrderDetailDto`: các trường của đơn + `items`.
Map<String, Object?> _detail(
  Map<String, Object?> order,
  List<Map<String, Object?>> items,
) => {
  ...order,
  'shippingMethod': null,
  'courierScannedAt': null,
  'returnReason': null,
  'rejectReason': null,
  'restockStatus': null,
  'items': items,
};

Map<String, Object?> _page(List<Object?> content) => ok({
  'content': content,
  'totalElements': content.length,
  'totalPages': 1,
  'number': 0,
  'size': 20,
  'last': true,
});

/// BE giả của Order Service: đổi trạng thái thật sự lưu lại. [items]: sản
/// phẩm của từng đơn ở `GET /orders/{id}`; [detailError]: mã lỗi của lần gọi
/// chi tiết đầu tiên (null = không lỗi).
FakeBackend _orderService(
  List<Map<String, Object?>> orders, {
  Map<int, List<Map<String, Object?>>> items = const {},
  int? detailError,
}) {
  var failDetail = detailError != null;
  return FakeBackend((RequestOptions o) async {
    final detail = RegExp(r'/orders/(\d+)$').firstMatch(o.path);
    if (detail != null) {
      if (failDetail) {
        failDetail = false;
        return (detailError!, apiError('Lỗi máy chủ'));
      }
      final id = int.parse(detail.group(1)!);
      final order = orders.firstWhere((e) => e['id'] == id);
      return (200, ok(_detail(order, items[id] ?? const [])));
    }
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
}

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

    test('chi tiết đơn đọc OrderDetailDto: items; BE không điền skuCode, '
        'productName thì mã rỗng, tên "SKU #id"', () async {
      final backend = _orderService(
        [_order(100, 'TO_SHIP')],
        items: {
          100: [
            _item(1, 10, 2, 125000),
            _item(
              2,
              11,
              1,
              99000,
              skuCode: 'AT-TRANG-M',
              productName: 'Áo thun',
              imageUrl: 'https://img.test/a.png',
            ),
          ],
        },
      );
      final order = await OrdersRemoteRepository(
        fakeDio(backend),
      ).getOrder(100);

      expect(backend.requests.single.path, ApiPaths.order(100));
      expect(order.platformOrderId, 'SO100');
      expect(order.status, OrderStatus.toShip);
      final [a, b] = order.items;
      expect(a.skuId, 10);
      expect(a.skuCode, isEmpty);
      expect(a.name, 'SKU #10');
      expect(a.quantity, 2);
      expect(a.unitPrice, 125000);
      expect(a.subtotal, 250000);
      expect(a.imageUrl, isNull);
      expect(b.skuCode, 'AT-TRANG-M');
      expect(b.name, 'Áo thun');
      expect(b.imageUrl, 'https://img.test/a.png');
    });

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
      List<Map<String, Object?>> orders, {
      Map<int, List<Map<String, Object?>>> items = const {},
      int? detailError,
    }) async {
      final backend = _orderService(
        orders,
        items: items,
        detailError: detailError,
      );
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

    testWidgets('M-21: sản phẩm từ GET /orders/{id}', (tester) async {
      final backend = await openOrders(
        tester,
        [_order(1, 'PENDING')],
        items: {
          1: [
            _item(1, 10, 2, 125000),
            _item(2, 11, 1, 99000, skuCode: 'AT-TRANG-M', productName: 'Áo'),
          ],
        },
      );
      await tapVisible(tester, find.byKey(const Key('order_1')));

      expect(backend.calls(ApiPaths.order(1)), 1);
      expect(find.text('SKU #10'), findsOneWidget);
      expect(find.text('2 × 125.000 ₫'), findsOneWidget);
      expect(find.text('Áo'), findsOneWidget);
      expect(find.text('AT-TRANG-M'), findsOneWidget);
      expect(
        find.text('Chưa có danh sách sản phẩm cho đơn này.'),
        findsNothing,
      );
    });

    testWidgets('M-21: chi tiết lỗi → vẫn hiện thông tin đơn từ danh sách, '
        'Thử lại tải được sản phẩm', (tester) async {
      await openOrders(
        tester,
        [_order(1, 'PENDING')],
        items: {
          1: [_item(1, 10, 2, 125000)],
        },
        detailError: 500,
      );
      await tapVisible(tester, find.byKey(const Key('order_1')));

      expect(find.byKey(const Key('order_items_error')), findsOneWidget);
      expect(find.text('Khách 1'), findsWidgets);
      expect(find.byKey(const Key('order_prepare')), findsOneWidget);

      await tapVisible(tester, find.byKey(const Key('order_items_retry')));
      expect(find.byKey(const Key('order_items_error')), findsNothing);
      expect(find.text('SKU #10'), findsOneWidget);
    });

    testWidgets('M-21: đơn không có sản phẩm; Chuẩn bị hàng → Chờ giao', (
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
