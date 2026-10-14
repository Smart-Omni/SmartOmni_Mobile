import 'package:flutter_test/flutter_test.dart';
import 'package:smartomni_mobile/core/models/platform.dart';
import 'package:smartomni_mobile/features/orders/domain/order.dart';
import 'package:smartomni_mobile/features/orders/domain/order_rules.dart';
import 'package:smartomni_mobile/features/orders/presentation/order_ui.dart';

Order _order(
  int id, {
  OrderStatus status = OrderStatus.pending,
  String code = 'X',
  String? customer,
  DateTime? createdAt,
}) => Order(
  id: id,
  platform: Platform.shopee,
  platformOrderId: code,
  status: status,
  totalAmount: 1,
  customerName: customer,
  createdAt: createdAt,
);

void main() {
  group('orderProgress', () {
    List<(OrderStatus, ProgressState)> steps(OrderStatus s) => [
      for (final step in orderProgress(s)) (step.status, step.state),
    ];

    test('PENDING: bước đầu đang làm, các bước sau chưa tới', () {
      expect(steps(OrderStatus.pending), [
        (OrderStatus.pending, ProgressState.current),
        (OrderStatus.toShip, ProgressState.upcoming),
        (OrderStatus.shipped, ProgressState.upcoming),
        (OrderStatus.delivering, ProgressState.upcoming),
        (OrderStatus.completed, ProgressState.upcoming),
      ]);
    });

    test('DELIVERING: 3 bước trước đã xong', () {
      final s = steps(OrderStatus.delivering);
      expect(s.where((e) => e.$2 == ProgressState.done).length, 3);
      expect(s[3], (OrderStatus.delivering, ProgressState.current));
    });

    test('Đã hủy / Trả hàng thay bước cuối', () {
      expect(steps(OrderStatus.cancelled), [
        (OrderStatus.pending, ProgressState.done),
        (OrderStatus.cancelled, ProgressState.current),
      ]);
      expect(steps(OrderStatus.returned).last, (
        OrderStatus.returned,
        ProgressState.current,
      ));
      expect(steps(OrderStatus.returned).length, 5);
    });

    test('chỉ Chờ xử lý / Chờ giao do nhân viên, còn lại sàn cập nhật', () {
      final sources = {
        for (final step in orderProgress(OrderStatus.pending))
          step.status: step.source,
      };
      expect(sources[OrderStatus.toShip], ProgressSource.staff);
      expect(sources[OrderStatus.shipped], ProgressSource.platform);
      expect(sources[OrderStatus.completed], ProgressSource.platform);
    });
  });

  test('ReturnReason.compose ghép "<lý do>: <ghi chú>"', () {
    expect(
      ReturnReason.damaged.compose('  rách đường may '),
      'Hàng lỗi/hư hỏng: rách đường may',
    );
  });

  test('không ghi nhận hoàn/trả cho đơn đã hủy hoặc đã trả', () {
    expect(canRecordReturn(OrderStatus.pending), isTrue);
    expect(canRecordReturn(OrderStatus.completed), isTrue);
    expect(canRecordReturn(OrderStatus.cancelled), isFalse);
    expect(canRecordReturn(OrderStatus.returned), isFalse);
  });

  test('orderMatches: mã đơn hoặc tên khách, bỏ dấu', () {
    final o = _order(1, code: '241014ABCD12', customer: 'Võ Thị F');
    expect(orderMatches(o, ''), isTrue);
    expect(orderMatches(o, 'abcd'), isTrue);
    expect(orderMatches(o, 'vo thi'), isTrue);
    expect(orderMatches(o, 'Nguyễn'), isFalse);
  });

  test('countByStatus đếm đủ mọi trạng thái', () {
    final counts = countByStatus([
      _order(1),
      _order(2),
      _order(3, status: OrderStatus.toShip),
    ]);
    expect(counts[OrderStatus.pending], 2);
    expect(counts[OrderStatus.toShip], 1);
    expect(counts[OrderStatus.returned], 0);
  });

  test('groupOrdersByDay: mới nhất trước, không có ngày ở cuối', () {
    final groups = groupOrdersByDay([
      _order(1, createdAt: DateTime(2026, 10, 13, 9)),
      _order(2),
      _order(3, createdAt: DateTime(2026, 10, 14, 8)),
      _order(4, createdAt: DateTime(2026, 10, 14, 10)),
    ]);
    expect(groups.map((g) => g.$1).toList(), [
      DateTime(2026, 10, 14),
      DateTime(2026, 10, 13),
      null,
    ]);
    expect(groups.first.$2.map((o) => o.id), [4, 3]);
  });

  test('dayGroupLabel', () {
    final now = DateTime(2026, 10, 15, 9);
    expect(dayGroupLabel(DateTime(2026, 10, 15), now: now), 'Hôm nay');
    expect(dayGroupLabel(DateTime(2026, 10, 14), now: now), 'Hôm qua');
    expect(dayGroupLabel(DateTime(2026, 10, 1), now: now), '01/10/2026');
  });

  test('OrderItem.nameAndVariant tách theo " - " cuối', () {
    const a = OrderItem(
      skuCode: 'A',
      name: 'Áo thun cotton basic - Trắng / M',
      quantity: 1,
      unitPrice: 1,
    );
    const b = OrderItem(skuCode: 'B', name: 'Túi', quantity: 1, unitPrice: 1);
    expect(a.nameAndVariant, ('Áo thun cotton basic', 'Trắng / M'));
    expect(b.nameAndVariant, ('Túi', null));
  });
}
