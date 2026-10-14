import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartomni_mobile/core/design/design.dart';
import 'package:smartomni_mobile/features/inventory/domain/inventory_item.dart';
import 'package:smartomni_mobile/features/products/domain/product.dart';
import 'package:smartomni_mobile/features/products/domain/product_stock.dart';
import 'package:smartomni_mobile/features/products/presentation/product_create_screen.dart';

import '../helpers/test_app.dart';

InventoryItem _stock(int skuId, int onHand, [int reserved = 0]) =>
    InventoryItem(
      skuId: skuId,
      skuCode: 'S$skuId',
      productName: 'P',
      quantityOnHand: onHand,
      reservedQuantity: reserved,
    );

const _product = Product(
  id: 1,
  name: 'P',
  skus: [
    Sku(id: 1, skuCode: 'A', basePrice: 1),
    Sku(id: 2, skuCode: 'B', basePrice: 1),
  ],
);

String _chipCount(WidgetTester tester, String key) =>
    '${tester.widget<SoFilterChip>(find.byKey(Key(key))).count}';

Future<void> _openTab(WidgetTester tester, String navKey) async {
  await tester.tap(find.byKey(Key(navKey)));
  await tester.pumpAndSettle();
}

void main() {
  group('domain', () {
    test('skuCodePattern lấy phần đầu chung theo dấu "-"', () {
      expect(
        skuCodePattern([
          'AT-BASIC-TRANG-M',
          'AT-BASIC-TRANG-L',
          'AT-BASIC-DEN-M',
        ]),
        'AT-BASIC-*',
      );
      expect(skuCodePattern(['TT-CANVAS-BE']), 'TT-CANVAS-BE');
      expect(skuCodePattern(['A-1', 'B-1']), '*');
      expect(skuCodePattern([]), '');
    });

    test('InventoryItem.level: hết ≤ 0, sắp hết ≤ 5', () {
      expect(_stock(1, 3, 3).level, StockLevel.out);
      expect(_stock(1, 8, 3).level, StockLevel.low);
      expect(_stock(1, 9, 3).level, StockLevel.ok);
    });

    test('productStockLevel gộp từ các SKU', () {
      expect(
        productStockLevel(_product, [_stock(1, 0), _stock(2, 0)]),
        StockLevel.out,
      );
      expect(
        productStockLevel(_product, [_stock(1, 0), _stock(2, 50)]),
        StockLevel.low,
      );
      expect(
        productStockLevel(_product, [_stock(1, 50), _stock(2, 50)]),
        StockLevel.ok,
      );
      expect(productStockLevel(_product, [_stock(9, 0)]), isNull);
    });

    test('InventoryFilter và inventoryTotals', () {
      final items = [_stock(1, 0), _stock(2, 4), _stock(3, 40, 10)];
      expect(items.where(InventoryFilter.attention.matches).length, 2);
      expect(items.where(InventoryFilter.out.matches).length, 1);
      expect(inventoryTotals(items), (onHand: 44, reserved: 10));
    });
  });

  testWidgets('M-30: segmented, tìm, nhãn tồn, nút "+"', (tester) async {
    await loginAs(tester, 'staff@demo.vn', tallView: true);
    await _openTab(tester, 'nav_products');

    expect(find.text('Đang bán · 4'), findsOneWidget);
    expect(find.text('Đã ẩn · 1'), findsOneWidget);
    expect(find.textContaining('AT-BASIC-*'), findsOneWidget);
    expect(find.text('Sắp hết'), findsNWidgets(3));

    await tapVisible(tester, find.text('Đã ẩn · 1'));
    expect(find.byKey(const Key('product_5')), findsOneWidget);
    expect(find.byKey(const Key('product_1')), findsNothing);

    await tapVisible(tester, find.text('Đang bán · 4'));
    await tapVisible(tester, find.byKey(const Key('products_search')));
    await tester.enterText(
      find.byKey(const Key('products_search_field')),
      'qj-slim',
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('product_2')), findsOneWidget);
    expect(find.byKey(const Key('product_1')), findsNothing);

    await tapVisible(tester, find.byKey(const Key('products_add')));
    expect(find.byType(ProductCreateScreen), findsOneWidget);
  });

  testWidgets('M-40: tổng kho, chip đếm, lọc hết hàng', (tester) async {
    await loginAs(tester, 'staff@demo.vn', tallView: true);
    await _openTab(tester, 'nav_inventory');

    expect(_chipCount(tester, 'stock_filter_all'), '10');
    expect(_chipCount(tester, 'stock_filter_attention'), '4');
    expect(_chipCount(tester, 'stock_filter_out'), '1');
    final total = find.byKey(const Key('inventory_total_meter'));
    expect(
      find.descendant(of: total, matching: find.text('173')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: total, matching: find.text('162')),
      findsOneWidget,
    );

    await tapVisible(tester, find.byKey(const Key('stock_filter_out')));
    expect(find.byKey(const Key('stock_103')), findsOneWidget);
    expect(find.byKey(const Key('stock_101')), findsNothing);
  });

  testWidgets('sheet đặt lại tồn: −/+, số có thể bán sau khi lưu, lưu', (
    tester,
  ) async {
    await loginAs(tester, 'staff@demo.vn', tallView: true);
    await _openTab(tester, 'nav_inventory');

    // AT-BASIC-TRANG-L: tồn 4, giữ 1.
    await tapVisible(tester, find.byKey(const Key('stock_102')));
    expect(find.text('Đặt lại số tồn'), findsOneWidget);

    await tapVisible(tester, find.byKey(const Key('stock_plus')));
    await tapVisible(tester, find.byKey(const Key('stock_plus')));
    expect(find.textContaining('Sau khi lưu: có thể bán 5'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('stock_input')), '');
    await tapVisible(tester, find.byKey(const Key('stock_save')));
    expect(find.text('Số tồn không được để trống'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('stock_input')), '30');
    await tester.pumpAndSettle();
    expect(find.textContaining('có thể bán 29'), findsOneWidget);
    await tapVisible(tester, find.byKey(const Key('stock_save')));

    expect(find.text('Đặt lại số tồn'), findsNothing);
    expect(find.text('Đã lưu số tồn AT-BASIC-TRANG-L: 30'), findsOneWidget);
    final row = find.byKey(const Key('stock_102'));
    expect(find.descendant(of: row, matching: find.text('29')), findsOneWidget);
  });

  testWidgets('M-30, M-40 và sheet vừa bề rộng 360dp', (tester) async {
    useNarrowPhone(tester);
    await loginAs(tester, 'staff@demo.vn');

    await _openTab(tester, 'nav_products');
    await tester.drag(find.byType(ListView).last, const Offset(0, -2000));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await _openTab(tester, 'nav_inventory');
    await tester.drag(find.byType(ListView).last, const Offset(0, -2000));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.drag(find.byType(ListView).last, const Offset(0, 2000));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const Key('stock_101')));
    expect(find.text('Đặt lại số tồn'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
