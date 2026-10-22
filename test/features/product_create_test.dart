import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:smartomni_mobile/core/network/api_exception.dart';
import 'package:smartomni_mobile/features/products/data/products_repositories.dart';
import 'package:smartomni_mobile/features/products/domain/product.dart';
import 'package:smartomni_mobile/features/products/presentation/product_create_screen.dart';
import 'package:smartomni_mobile/features/products/presentation/product_detail_screen.dart';
import 'package:smartomni_mobile/features/products/presentation/products_providers.dart';

import '../helpers/test_app.dart';

/// Mock nhưng tạo sản phẩm luôn lỗi với [message].
class _FailingRepository extends ProductsMockRepository {
  _FailingRepository(this.message);

  final String message;

  @override
  Future<Product> createProduct(CreateProductInput input) async =>
      throw ApiException(type: ApiErrorType.validation, message: message);
}

Future<void> _openCreate(
  WidgetTester tester, {
  List<Override> overrides = const [],
}) async {
  await loginAs(tester, 'admin@demo.vn', tallView: true, overrides: overrides);
  await tester.tap(find.byKey(const Key('nav_products')));
  await tester.pumpAndSettle();
  await tapVisible(tester, find.byKey(const Key('products_add')));
  expect(find.byType(ProductCreateScreen), findsOneWidget);
}

/// Điền đủ form rồi bấm Lưu, server trả lỗi [message].
Future<void> _submitFailing(WidgetTester tester, String message) async {
  await _openCreate(
    tester,
    overrides: [
      productsRepositoryProvider.overrideWithValue(_FailingRepository(message)),
    ],
  );
  await tester.enterText(_field('product_name'), 'Mũ');
  await tester.enterText(_field('sku_code'), 'MU-01');
  await tester.enterText(_field('sku_price'), '99000');
  await tapVisible(tester, find.byKey(const Key('product_create_submit')));
}

Finder _field(String key) => find.descendant(
  of: find.byKey(Key(key)),
  matching: find.byType(EditableText),
);

String _text(WidgetTester tester, String key) =>
    tester.widget<EditableText>(_field(key)).controller.text;

void main() {
  testWidgets('M-32: bắt buộc tên/mã/giá; mã viết hoa; giá có dấu chấm', (
    tester,
  ) async {
    await _openCreate(tester);

    await tapVisible(tester, find.byKey(const Key('product_create_submit')));
    expect(find.text('Tên sản phẩm không được để trống'), findsOneWidget);
    expect(find.byType(ProductCreateScreen), findsOneWidget);

    // Ô giá: trống (không có 0 mặc định), hint ví dụ, căn trái như các ô khác.
    final price = tester.widget<EditableText>(_field('sku_price'));
    expect(price.controller.text, isEmpty);
    expect(price.textAlign, TextAlign.start);
    expect(find.text('Vd: 159.000'), findsOneWidget);
    expect(find.text('Nhiều SKU, ảnh, link sàn · Sắp có'), findsOneWidget);

    await tester.enterText(_field('sku_code'), 'at 001-m/á');
    await tester.enterText(_field('sku_price'), '159000');
    await tester.pump();
    expect(_text(tester, 'sku_code'), 'AT001-M');
    expect(_text(tester, 'sku_price'), '159.000');
    // "₫" là suffix cùng cỡ chữ với số.
    final currency = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const Key('sku_price')),
        matching: find.text('₫'),
      ),
    );
    expect(currency.style?.fontSize, price.style.fontSize);
  });

  testWidgets('M-32: tạo xong mở M-31 của sản phẩm mới', (tester) async {
    await _openCreate(tester);

    await tester.enterText(_field('product_name'), 'Mũ lưỡi trai kaki');
    await tester.enterText(_field('sku_code'), 'MU-KAKI-01');
    await tester.enterText(_field('sku_price'), '99000');
    await tapVisible(tester, find.byKey(const Key('product_create_submit')));

    expect(find.byType(ProductCreateScreen), findsNothing);
    expect(find.byType(ProductDetailScreen), findsOneWidget);
    expect(find.text('Mũ lưỡi trai kaki'), findsOneWidget);
    expect(find.text('Đã tạo sản phẩm'), findsOneWidget);
  });

  testWidgets('M-32: back khi đã nhập thì hỏi trước khi bỏ', (tester) async {
    await _openCreate(tester);
    await tester.enterText(_field('product_name'), 'Nháp');

    // Nút Back hệ thống (Android) / vuốt back.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Bỏ sản phẩm đang nhập?'), findsOneWidget);

    await tester.tap(find.byKey(const Key('discard_cancel')));
    await tester.pumpAndSettle();
    expect(find.byType(ProductCreateScreen), findsOneWidget);
    expect(_text(tester, 'product_name'), 'Nháp');

    // Nút Back hệ thống (Android) / vuốt back.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('discard_confirm')));
    await tester.pumpAndSettle();
    expect(find.byType(ProductCreateScreen), findsNothing);
  });

  testWidgets('M-32: Hủy khi form trống thì đóng, đã nhập thì hỏi', (
    tester,
  ) async {
    await _openCreate(tester);
    expect(find.text('Sản phẩm mới'), findsOneWidget);

    await tester.enterText(_field('sku_code'), 'NHAP-01');
    await tapVisible(tester, find.byKey(const Key('product_create_cancel')));
    expect(find.text('Bỏ sản phẩm đang nhập?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('discard_cancel')));
    await tester.pumpAndSettle();

    await tester.enterText(_field('sku_code'), '');
    await tapVisible(tester, find.byKey(const Key('product_create_cancel')));
    expect(find.byType(ProductCreateScreen), findsNothing);
  });

  testWidgets('M-32: lỗi server về SKU hiện dưới ô mã', (tester) async {
    await _submitFailing(tester, 'Mã SKU đã tồn tại');
    expect(
      find.descendant(
        of: find.byKey(const Key('sku_code')),
        matching: find.text('Mã SKU đã tồn tại'),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('product_create_error')), findsNothing);
    expect(find.byType(ProductCreateScreen), findsOneWidget);
  });

  testWidgets('M-32: lỗi server khác hiện ở banner đầu form', (tester) async {
    await _submitFailing(tester, 'Gói dịch vụ đã hết hạn');
    expect(find.byKey(const Key('product_create_error')), findsOneWidget);
    expect(find.text('Gói dịch vụ đã hết hạn'), findsOneWidget);
    expect(find.byType(ProductCreateScreen), findsOneWidget);
  });
}
