import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartomni_mobile/core/design/design.dart';
import 'package:smartomni_mobile/core/utils/pdf_tools.dart';
import 'package:smartomni_mobile/features/orders/data/shipping_label_mock_repository.dart';
import 'package:smartomni_mobile/features/orders/domain/order.dart';
import 'package:smartomni_mobile/features/orders/domain/order_rules.dart';
import 'package:smartomni_mobile/features/orders/domain/shipping_label_repository.dart';
import 'package:smartomni_mobile/features/orders/presentation/orders_providers.dart';
import 'package:smartomni_mobile/features/orders/presentation/shipping_label_screen.dart';

import '../helpers/test_app.dart';

/// PNG 1×1 làm ảnh trang tem (trong test không có plugin `printing`).
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
);

class _FakePdfTools implements PdfTools {
  _FakePdfTools({this.failPrint = false});

  final bool failPrint;
  final shared = <String>[];
  final printed = <String>[];

  @override
  Future<List<PdfPageImage>> rasterize(Uint8List pdf, {double dpi = 250}) =>
      Future.value([PdfPageImage(_png, 200, 300)]);

  @override
  Future<void> share(Uint8List pdf, String filename) async =>
      shared.add(filename);

  @override
  Future<void> printPdf(Uint8List pdf, String jobName) async {
    if (failPrint) throw Exception('không có dịch vụ in');
    printed.add(jobName);
  }
}

/// Tem lấy từ [load]; mặc định trả vài byte giả.
class _FakeLabels implements ShippingLabelRepository {
  _FakeLabels([this.load]);

  final Future<Uint8List> Function()? load;
  var calls = 0;

  @override
  Future<Uint8List> fetchLabel(int orderId) {
    calls++;
    return load?.call() ?? Future.value(Uint8List.fromList([1, 2, 3]));
  }
}

Future<_FakePdfTools> _openOrder(
  WidgetTester tester,
  int orderId, {
  _FakeLabels? labels,
  _FakePdfTools? tools,
}) async {
  final pdf = tools ?? _FakePdfTools();
  await loginAs(
    tester,
    'staff@demo.vn',
    tallView: true,
    overrides: [
      shippingLabelRepositoryProvider.overrideWithValue(
        labels ?? _FakeLabels(),
      ),
      pdfToolsProvider.overrideWithValue(pdf),
    ],
  );
  await tester.tap(find.byKey(const Key('nav_orders')));
  await tester.pumpAndSettle();
  await tapVisible(tester, find.byKey(Key('order_$orderId')));
  return pdf;
}

SoListRow _labelRow(WidgetTester tester) =>
    tester.widget<SoListRow>(find.byKey(const Key('order_label')));

VoidCallback? _onPressed(WidgetTester tester, String key) =>
    tester.widget<SoButton>(find.byKey(Key(key))).onPressed;

void main() {
  test('labelAvailability: tem có sau khi Chuẩn bị hàng', () {
    expect(
      labelAvailability(OrderStatus.pending),
      LabelAvailability.afterPrepare,
    );
    for (final s in [
      OrderStatus.toShip,
      OrderStatus.shipped,
      OrderStatus.delivering,
    ]) {
      expect(labelAvailability(s), LabelAvailability.ready, reason: '$s');
    }
    for (final s in [
      OrderStatus.completed,
      OrderStatus.cancelled,
      OrderStatus.returned,
    ]) {
      expect(labelAvailability(s), LabelAvailability.none, reason: '$s');
    }
  });

  testWidgets('mock trả file PDF tem mẫu', (tester) async {
    final pdf = await tester.runAsync(
      () => const ShippingLabelMockRepository().fetchLabel(1),
    );
    expect(ascii.decode(pdf!.sublist(0, 4)), '%PDF');
  });

  testWidgets('M-21 Chờ giao -> M-22: xem trước, chia sẻ, in', (tester) async {
    final tools = await _openOrder(tester, 1002);
    expect(_labelRow(tester).enabled, isTrue);

    await tapVisible(tester, find.byKey(const Key('order_label')));
    expect(find.byType(ShippingLabelScreen), findsOneWidget);
    expect(find.text('In vận đơn'), findsOneWidget);
    expect(find.text('5779112233445566'), findsOneWidget);
    expect(find.byType(SoMockBanner), findsOneWidget);
    expect(find.byKey(const Key('label_preview')), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsOneWidget);
    // Không chọn khổ giấy: chỉ có hai nút.
    expect(find.byType(SoButton), findsNWidgets(2));

    await tester.tap(find.byKey(const Key('label_share')));
    await tester.pumpAndSettle();
    expect(tools.shared, ['van-don-5779112233445566.pdf']);

    await tester.tap(find.byKey(const Key('label_print')));
    await tester.pumpAndSettle();
    expect(tools.printed, ['Vận đơn 5779112233445566']);
  });

  testWidgets('M-21 Chờ xử lý: hàng In vận đơn mờ, mở được sau Chuẩn bị hàng', (
    tester,
  ) async {
    await _openOrder(tester, 1001);
    expect(_labelRow(tester).enabled, isFalse);
    expect(find.text('Có sau khi Chuẩn bị hàng'), findsOneWidget);
    await tapVisible(tester, find.byKey(const Key('order_label')));
    expect(find.byType(ShippingLabelScreen), findsNothing);

    await tapVisible(tester, find.byKey(const Key('order_prepare')));
    expect(_labelRow(tester).enabled, isTrue);
  });

  testWidgets('M-21 Hoàn tất / Đã hủy: không có hàng In vận đơn', (
    tester,
  ) async {
    await _openOrder(tester, 1004);
    expect(find.byKey(const Key('order_label')), findsNothing);
  });

  testWidgets('M-22 đang tải: skeleton, hai nút khóa', (tester) async {
    final pending = Completer<Uint8List>();
    await _openOrder(tester, 1002, labels: _FakeLabels(() => pending.future));
    await revealCentered(tester, find.byKey(const Key('order_label')));
    await tester.tap(find.byKey(const Key('order_label')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(SoSkeleton), findsOneWidget);
    expect(_onPressed(tester, 'label_share'), isNull);
    expect(_onPressed(tester, 'label_print'), isNull);

    pending.complete(Uint8List(1));
    await tester.pumpAndSettle();
    expect(find.byType(SoSkeleton), findsNothing);
    expect(_onPressed(tester, 'label_print'), isNotNull);
  });

  testWidgets('M-22 sàn chưa tạo tem: trạng thái riêng, nút khóa', (
    tester,
  ) async {
    await _openOrder(
      tester,
      1002,
      labels: _FakeLabels(() => Future.error(const LabelNotReadyException())),
    );
    await tapVisible(tester, find.byKey(const Key('order_label')));

    expect(find.byKey(const Key('label_not_ready')), findsOneWidget);
    expect(find.byKey(const Key('label_error')), findsNothing);
    expect(_onPressed(tester, 'label_print'), isNull);
  });

  testWidgets('M-22 lỗi mạng: Thử lại tải lại tem', (tester) async {
    late final _FakeLabels labels;
    labels = _FakeLabels(
      () => labels.calls == 1
          ? Future.error(Exception('mất mạng'))
          : Future.value(Uint8List(1)),
    );
    await _openOrder(tester, 1002, labels: labels);
    await tapVisible(tester, find.byKey(const Key('order_label')));
    expect(find.byKey(const Key('label_error')), findsOneWidget);

    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(labels.calls, 2);
    expect(find.byKey(const Key('label_error')), findsNothing);
    expect(find.byType(InteractiveViewer), findsOneWidget);
  });

  testWidgets('M-22 in lỗi: báo toast, nút bấm lại được', (tester) async {
    await _openOrder(tester, 1002, tools: _FakePdfTools(failPrint: true));
    await tapVisible(tester, find.byKey(const Key('order_label')));

    await tester.tap(find.byKey(const Key('label_print')));
    await tester.pumpAndSettle();
    expect(find.text('Không mở được hộp thoại in. Thử lại.'), findsOneWidget);
    expect(_onPressed(tester, 'label_print'), isNotNull);
  });

  testWidgets('M-22 vừa bề rộng 360dp', (tester) async {
    await _openOrder(tester, 1002);
    await tapVisible(tester, find.byKey(const Key('order_label')));
    tester.view.physicalSize = const Size(360, 740);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
