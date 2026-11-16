import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartomni_mobile/core/design/design.dart';
import 'package:smartomni_mobile/core/network/api_paths.dart';
import 'package:smartomni_mobile/features/inventory/data/inventory_repositories.dart';
import 'package:smartomni_mobile/features/inventory/domain/inventory_item.dart';
import 'package:smartomni_mobile/features/inventory/presentation/inventory_providers.dart';
import 'package:smartomni_mobile/features/products/data/products_repositories.dart';
import 'package:smartomni_mobile/features/products/domain/product.dart';
import 'package:smartomni_mobile/features/products/presentation/products_providers.dart';

import '../helpers/fake_backend.dart';
import '../helpers/test_app.dart';

const _products = [
  Product(
    id: 1,
    name: 'Áo thun',
    skus: [
      Sku(id: 11, skuCode: 'AT-TRANG-M', basePrice: 159000, variantName: 'M'),
      Sku(id: 12, skuCode: 'AT-DEN-M', basePrice: 149000),
    ],
  ),
  Product(
    id: 2,
    name: 'Mũ len',
    skus: [Sku(id: 21, skuCode: 'ML-01', basePrice: 99000)],
  ),
];

/// `InventoryItemDto` như BE trả (camelCase): đủ SKU của tenant, SKU chưa
/// đặt tồn thì 0; dòng tồn không khớp SKU thì `SKU-<id>` / "Unknown Product".
Map<String, Object?> _dto(
  int skuId,
  int onHand,
  int reserved, {
  String? code,
  String? product,
}) => {
  'skuId': skuId,
  'skuCode': code ?? 'SKU-$skuId',
  'productName': product ?? 'Unknown Product',
  'quantityOnHand': onHand,
  'reservedQuantity': reserved,
  'availableQuantity': onHand - reserved < 0 ? 0 : onHand - reserved,
};

Map<String, Object?> _page(List<Object?> content) => ok({
  'content': content,
  'totalElements': content.length,
  'totalPages': 1,
  'number': 0,
  'size': 500,
  'last': true,
});

void main() {
  group('buildInventoryItems', () {
    final items = buildInventoryItems([
      InventoryRow.fromJson(
        _dto(11, 40, 2, code: 'AT-TRANG-M', product: 'Áo thun'),
      ),
      InventoryRow.fromJson(
        _dto(12, 6, 2, code: 'AT-DEN-M', product: 'Áo thun'),
      ),
      InventoryRow.fromJson(_dto(21, 0, 0, code: 'ML-01', product: 'Mũ len')),
      InventoryRow.fromJson(_dto(99, 3, 5)),
    ], _products);
    InventoryItem item(int skuId) => items.firstWhere((i) => i.skuId == skuId);

    test('đọc thẳng mã SKU, tên sản phẩm, availableQuantity; tên biến thể '
        'ghép từ sản phẩm', () {
      expect(item(11).skuCode, 'AT-TRANG-M');
      expect(item(11).productName, 'Áo thun');
      expect(item(11).variantName, 'M');
      expect(item(11).available, 38);
      expect(item(11).level, StockLevel.ok);
      expect(item(12).available, 4);
      expect(item(12).level, StockLevel.low);
    });

    test('SKU chưa đặt tồn (BE trả tồn 0): Hết hàng', () {
      expect(item(21).quantityOnHand, 0);
      expect(item(21).level, StockLevel.out);
      expect(item(21).productName, 'Mũ len');
    });

    test('dòng tồn không khớp SKU: giữ mã, tên BE; giữ chỗ lớn hơn tồn → có '
        'thể bán 0 (BE), Hết hàng', () {
      expect(item(99).skuCode, 'SKU-99');
      expect(item(99).productName, 'Unknown Product');
      expect(item(99).variantName, isNull);
      expect(item(99).available, 0);
      expect(item(99).level, StockLevel.out);
    });

    test('giữ thứ tự BE (theo skuId)', () {
      expect([for (final i in items) i.skuId], [11, 12, 21, 99]);
    });

    test('BE thiếu mã / tên: lấy từ sản phẩm, không có thì "SKU #id"', () {
      final out = buildInventoryItems(const [
        InventoryRow(skuId: 21, quantityOnHand: 1, reservedQuantity: 0),
        InventoryRow(skuId: 77, quantityOnHand: 1, reservedQuantity: 0),
      ], _products);
      expect(out[0].skuCode, 'ML-01');
      expect(out[0].productName, 'Mũ len');
      expect(out[0].available, 1);
      expect(out[1].displayCode, 'SKU #77');
      expect(out[1].productName, 'SKU #77');
    });
  });

  group('InventoryRemoteRepository', () {
    test('GET /inventory không gửi sort (BE tự sắp theo skuId)', () async {
      final backend = FakeBackend(
        (o) async => (
          200,
          _page([_dto(11, 7, 1, code: 'AT-TRANG-M', product: 'Áo thun')]),
        ),
      );
      final items = await InventoryRemoteRepository(
        fakeDio(backend),
      ).listInventory(_products);

      final req = backend.requests.single;
      expect(req.path, ApiPaths.inventoryList);
      expect(req.queryParameters, {'page': 0, 'size': 500});
      expect(items.single.available, 6);
      expect(items.single.variantName, 'M');
    });

    test('đặt lại tồn gửi POST /adjust?quantity=', () async {
      final backend = FakeBackend((o) async => (200, ok()));
      await InventoryRemoteRepository(
        fakeDio(backend),
      ).setStock(skuId: 21, newQuantity: 15);
      final req = backend.requests.single;
      expect(req.method, 'POST');
      expect(req.path, ApiPaths.inventoryAdjust(21));
      expect(req.queryParameters, {'quantity': 15});
    });
  });

  group('M-40 với BE thật', () {
    /// BE giả: sản phẩm + SKU + tồn; `adjust` gán số tồn mới. [failSkusOnce]:
    /// lần gọi `/products/skus` đầu tiên trả 500 (lỗi thoáng qua).
    FakeBackend backend({bool failSkusOnce = false}) {
      var skusFailed = false;
      final stock = <int, (int, int)>{11: (40, 2), 12: (6, 2), 99: (3, 0)};
      final allSkus = {
        for (final p in _products)
          for (final s in p.skus) s.id: (product: p, sku: s),
      };
      return FakeBackend((RequestOptions o) async {
        final adjust = RegExp(r'/inventory/(\d+)/adjust$').firstMatch(o.path);
        if (adjust != null) {
          final id = int.parse(adjust.group(1)!);
          stock[id] = (o.queryParameters['quantity'] as int, 0);
          return (200, ok());
        }
        if (o.path == ApiPaths.inventoryList) {
          final ids = {...allSkus.keys, ...stock.keys}.toList()..sort();
          return (
            200,
            _page([
              for (final id in ids)
                _dto(
                  id,
                  stock[id]?.$1 ?? 0,
                  stock[id]?.$2 ?? 0,
                  code: allSkus[id]?.sku.skuCode,
                  product: allSkus[id]?.product.name,
                ),
            ]),
          );
        }
        if (o.path == ApiPaths.productSkusBatch) {
          if (failSkusOnce && !skusFailed) {
            skusFailed = true;
            return (500, apiError('Lỗi máy chủ'));
          }
          return (
            200,
            ok([
              for (final p in _products)
                for (final s in p.skus)
                  {
                    'id': s.id,
                    'productId': p.id,
                    'skuCode': s.skuCode,
                    'variantName': s.variantName,
                    'basePrice': s.basePrice,
                  },
            ]),
          );
        }
        return (
          200,
          ok({
            'content': [
              for (final p in _products)
                {'id': p.id, 'name': p.name, 'status': 'ACTIVE'},
            ],
            'totalElements': _products.length,
            'totalPages': 1,
            'number': 0,
            'size': 100,
          }),
        );
      });
    }

    Future<FakeBackend> open(
      WidgetTester tester,
      String tab, {
      bool failSkusOnce = false,
    }) async {
      final be = backend(failSkusOnce: failSkusOnce);
      await loginAs(
        tester,
        'admin@demo.vn',
        tallView: true,
        overrides: [
          productsUseRemoteProvider.overrideWithValue(true),
          inventoryUseRemoteProvider.overrideWithValue(true),
          productsRepositoryProvider.overrideWithValue(
            ProductsRemoteRepository(fakeDio(be)),
          ),
          inventoryRepositoryProvider.overrideWithValue(
            InventoryRemoteRepository(fakeDio(be)),
          ),
        ],
      );
      await tester.tap(find.byKey(Key(tab)));
      await tester.pumpAndSettle();
      return be;
    }

    testWidgets('không banner mẫu; dòng tồn lạ hiện mã BE "SKU-99"; SKU '
        'chưa đặt tồn là Hết hàng và đặt tồn được ngay', (tester) async {
      final be = await open(tester, 'nav_inventory');

      expect(find.byType(SoMockBanner), findsNothing);
      expect(find.text('SKU-99'), findsOneWidget);
      // Danh sách sản phẩm chỉ tải một lần (dùng chung với M-30).
      expect(be.calls(ApiPaths.products), 1);

      final mu = find.byKey(const Key('stock_21'));
      expect(
        find.descendant(of: mu, matching: find.text('Hết hàng')),
        findsOneWidget,
      );

      await tapVisible(tester, mu);
      await tester.enterText(find.byKey(const Key('stock_input')), '15');
      await tester.tap(find.byKey(const Key('stock_save')));
      await tester.pumpAndSettle();

      expect(
        be.requests.where((r) => r.path == ApiPaths.inventoryAdjust(21)),
        hasLength(1),
      );
      expect(find.text('Đã lưu số tồn ML-01: 15'), findsOneWidget);
      expect(
        find.descendant(of: mu, matching: find.text('Hết hàng')),
        findsNothing,
      );
    });

    testWidgets('sản phẩm lỗi thoáng qua: Thử lại ở M-40 tải lại cả sản phẩm '
        'và hiện danh sách', (tester) async {
      await open(tester, 'nav_inventory', failSkusOnce: true);
      expect(find.text('Không tải được tồn kho'), findsOneWidget);

      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();

      expect(find.text('Không tải được tồn kho'), findsNothing);
      expect(find.byKey(const Key('stock_21')), findsOneWidget);
    });

    testWidgets('M-30 hiện lại nhãn tồn khi tồn kho là thật', (tester) async {
      await open(tester, 'nav_products');
      // AT-DEN-M còn 4 có thể bán -> Áo thun "Sắp hết"; Mũ len chưa có tồn.
      expect(find.text('Sắp hết'), findsOneWidget);
      expect(find.text('Hết hàng'), findsOneWidget);
    });
  });
}
