import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartomni_mobile/core/design/design.dart';
import 'package:smartomni_mobile/features/auth/data/auth_mock_repository.dart';
import 'package:smartomni_mobile/features/orders/data/orders_repositories.dart';
import 'package:smartomni_mobile/features/orders/presentation/order_detail_screen.dart';
import 'package:smartomni_mobile/features/orders/presentation/orders_providers.dart';

import '../helpers/test_app.dart';

/// Mock ghi lại các lần gọi `createReturn` để kiểm tra chuỗi `reason`.
class _RecordingOrdersRepository extends OrdersMockRepository {
  final returns = <(int, String)>[];

  @override
  Future<void> createReturn({required int orderId, required String reason}) {
    returns.add((orderId, reason));
    return super.createReturn(orderId: orderId, reason: reason);
  }
}

/// [tallView]: khung test cao 2000px để danh sách dựng đủ mọi hàng.
Future<_RecordingOrdersRepository> _openOrders(
  WidgetTester tester, {
  bool tallView = true,
}) async {
  if (tallView) {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }
  final repo = _RecordingOrdersRepository();
  await pumpSmartOmniApp(
    tester,
    overrides: [ordersRepositoryProvider.overrideWithValue(repo)],
  );
  await tester.enterText(find.byKey(const Key('login_email')), 'staff@demo.vn');
  await tester.enterText(
    find.byKey(const Key('login_password')),
    MockAccounts.password,
  );
  await tester.tap(find.byKey(const Key('login_submit')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('nav_orders')));
  await tester.pumpAndSettle();
  return repo;
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

String _chipCount(WidgetTester tester, String key) =>
    '${tester.widget<SoFilterChip>(find.byKey(Key(key))).count}';

void main() {
  testWidgets('M-20: chip có số đếm, lọc theo trạng thái', (tester) async {
    await _openOrders(tester);

    expect(_chipCount(tester, 'filter_all'), '7');
    expect(_chipCount(tester, 'filter_pending'), '3');
    expect(find.byType(SoOrderRow), findsNWidgets(7));
    expect(find.textContaining('HÔM NAY'), findsOneWidget);

    await _tap(tester, find.byKey(const Key('filter_pending')));
    expect(find.byType(SoOrderRow), findsNWidgets(3));

    await _tap(tester, find.byKey(const Key('filter_returned')));
    expect(find.byType(SoOrderRow), findsNothing);
    expect(find.text('Không có đơn phù hợp'), findsOneWidget);
  });

  testWidgets('M-20: tìm theo tên khách không dấu', (tester) async {
    await _openOrders(tester);
    await _tap(tester, find.byKey(const Key('orders_search')));
    await tester.enterText(
      find.byKey(const Key('orders_search_field')),
      'vo thi',
    );
    await tester.pumpAndSettle();
    expect(find.byType(SoOrderRow), findsOneWidget);
    expect(find.byKey(const Key('order_1006')), findsOneWidget);

    // Đóng tìm kiếm -> hiện lại đủ.
    await _tap(tester, find.byKey(const Key('orders_search')));
    expect(find.byType(SoOrderRow), findsNWidgets(7));
  });

  testWidgets('M-21: Chuẩn bị hàng chuyển PENDING -> Chờ giao', (tester) async {
    await _openOrders(tester);
    await _tap(tester, find.byKey(const Key('order_1001')));
    expect(find.byType(OrderDetailScreen), findsOneWidget);
    expect(find.byKey(const Key('order_pending_banner')), findsOneWidget);

    await _tap(tester, find.byKey(const Key('order_prepare')));
    expect(find.text('Đã chuyển sang Chờ giao'), findsOneWidget);
    expect(
      tester.widget<SoStatusTag>(find.byKey(const Key('order_status'))).label,
      'Chờ giao',
    );
    expect(find.byKey(const Key('order_pending_banner')), findsNothing);
    expect(find.byKey(const Key('order_prepare')), findsNothing);
    // Vẫn ghi nhận hoàn/trả được.
    expect(find.byKey(const Key('order_return')), findsOneWidget);
  });

  testWidgets('M-21: đơn đã hủy không có nút nào ở thanh dưới', (tester) async {
    await _openOrders(tester);
    await _tap(tester, find.byKey(const Key('order_1005')));
    expect(find.byKey(const Key('order_prepare')), findsNothing);
    expect(find.byKey(const Key('order_return')), findsNothing);
    expect(find.byType(SoActionBar), findsNothing);
  });

  testWidgets('sheet hoàn/trả: bắt buộc lý do + ghi chú, gửi đúng chuỗi', (
    tester,
  ) async {
    final repo = await _openOrders(tester);
    await _tap(tester, find.byKey(const Key('order_1002')));
    await _tap(tester, find.byKey(const Key('order_return')));
    expect(find.text('Ghi nhận hoàn/trả'), findsOneWidget);

    await _tap(tester, find.byKey(const Key('return_submit')));
    expect(find.byKey(const Key('return_reason_error')), findsOneWidget);
    expect(find.text('Nhập ghi chú để đối chiếu sau này'), findsOneWidget);
    expect(repo.returns, isEmpty);

    await _tap(tester, find.byKey(const Key('reason_damaged')));
    await tester.enterText(
      find.byKey(const Key('return_note')),
      'Rách đường may',
    );
    await _tap(tester, find.byKey(const Key('return_submit')));

    expect(repo.returns, [(1002, 'Hàng lỗi/hư hỏng: Rách đường may')]);
    expect(find.text('Ghi nhận hoàn/trả'), findsNothing);
    expect(find.text('Đã ghi nhận hoàn/trả'), findsOneWidget);
  });

  testWidgets('M-20, M-21 và sheet vừa bề rộng 360dp', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await _openOrders(tester, tallView: false);
    await tester.drag(find.byType(ListView).last, const Offset(0, -2000));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.drag(find.byType(ListView).last, const Offset(0, 2000));
    await tester.pumpAndSettle();
    await _tap(tester, find.byKey(const Key('order_1006')));
    await tester.drag(find.byType(ListView).last, const Offset(0, -2000));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await _tap(tester, find.byKey(const Key('order_return')));
    expect(tester.takeException(), isNull);
  });
}
