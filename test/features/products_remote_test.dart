import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartomni_mobile/core/design/design.dart';
import 'package:smartomni_mobile/core/network/api_exception.dart';
import 'package:smartomni_mobile/core/network/api_paths.dart';
import 'package:smartomni_mobile/features/products/data/products_repositories.dart';
import 'package:smartomni_mobile/features/products/domain/product.dart';
import 'package:smartomni_mobile/features/products/presentation/product_detail_screen.dart';
import 'package:smartomni_mobile/features/products/presentation/products_providers.dart';

import '../helpers/fake_backend.dart';
import '../helpers/test_app.dart';

/// Entity `Product` như BE trả (camelCase).
Map<String, Object?> _product(
  int id,
  String name, {
  String status = 'ACTIVE',
}) => {
  'id': id,
  'tenantId': 3,
  'name': name,
  'description': 'Mô tả $name',
  'status': status,
  'createdBy': 1,
  'createdAt': '2026-11-10T08:00:00Z',
};

/// Entity `ProductSku`.
Map<String, Object?> _sku(int id, int productId, String code, num? price) => {
  'id': id,
  'tenantId': 3,
  'productId': productId,
  'skuCode': code,
  'variantName': null,
  'basePrice': price,
};

/// `Page` mặc định của Spring.
Map<String, Object?> _page(List<Object?> content) => ok({
  'content': content,
  'totalElements': content.length,
  'totalPages': 1,
  'number': 0,
  'size': 100,
  'first': true,
  'last': true,
});

/// BE giả của Catalog Service, có thể thêm sản phẩm qua POST.
class _Catalog {
  _Catalog({this.failSkusOf, this.delay = Duration.zero}) {
    backend = FakeBackend(_handle);
  }

  final int? failSkusOf;
  final Duration delay;
  late final FakeBackend backend;
  var running = 0;
  var peak = 0;

  final products = [
    _product(1, 'Áo thun'),
    _product(2, 'Quần jean', status: 'HIDDEN'),
    _product(3, 'Mũ len'),
  ];
  final skus = <int, List<Map<String, Object?>>>{
    1: [_sku(11, 1, 'AT-TRANG-M', 159000), _sku(12, 1, 'AT-DEN-M', 149000)],
    2: [_sku(21, 2, 'QJ-29', 389000)],
    3: [_sku(31, 3, 'ML-01', null)],
  };

  Future<(int, Object?)> _handle(RequestOptions o) async {
    final m = RegExp(r'/api/v1/products/(\d+)(/skus)?$').firstMatch(o.path);
    if (o.method == 'POST') {
      final body = o.data as Map;
      final id = products.length + 1;
      final created = _product(id, body['name'] as String);
      products.insert(0, created);
      skus[id] = [
        for (final (i, s) in (body['skus'] as List).indexed)
          _sku(id * 10 + i, id, s['skuCode'] as String, s['basePrice'] as num),
      ];
      return (200, ok(created));
    }
    if (m != null && m.group(2) != null) {
      final id = int.parse(m.group(1)!);
      running++;
      if (running > peak) peak = running;
      await Future<void>.delayed(delay);
      running--;
      if (id == failSkusOf) return (500, apiError('Lỗi máy chủ'));
      return (200, ok(skus[id] ?? const []));
    }
    if (m != null) {
      final id = int.parse(m.group(1)!);
      return (200, ok(products.firstWhere((p) => p['id'] == id)));
    }
    return (200, _page(products));
  }
}

void main() {
  group('ProductsRemoteRepository.listProducts', () {
    test('đọc Page<Product> + SKU từng sản phẩm: HIDDEN = đã ẩn, giá "từ" '
        'nhỏ nhất, basePrice null = 0, không có link sàn', () async {
      final catalog = _Catalog();
      final list = await ProductsRemoteRepository(
        fakeDio(catalog.backend),
      ).listProducts();

      final first = catalog.backend.requests.first;
      expect(first.path, ApiPaths.products);
      expect(first.queryParameters, {
        'page': 0,
        'size': 100,
        'sort': 'createdAt,desc',
      });
      expect([for (final p in list) p.id], [1, 2, 3]);
      expect(list[0].skus.map((s) => s.skuCode), ['AT-TRANG-M', 'AT-DEN-M']);
      expect(list[0].minPrice, 149000);
      expect(list[1].active, isFalse);
      expect(list[2].skus.single.basePrice, 0);
      expect(list.every((p) => p.marketplaceUrls.isEmpty), isTrue);
    });

    test('gọi /skus song song, tối đa 4 cùng lúc, giữ thứ tự', () async {
      final catalog = _Catalog(delay: const Duration(milliseconds: 10));
      for (var id = 4; id <= 10; id++) {
        catalog.products.add(_product(id, 'SP $id'));
      }
      final list = await ProductsRemoteRepository(
        fakeDio(catalog.backend),
      ).listProducts();

      expect(catalog.peak, 4);
      expect([for (final p in list) p.id], [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
    });

    test('một lần gọi /skus lỗi → cả danh sách lỗi', () async {
      final catalog = _Catalog(failSkusOf: 2);
      await expectLater(
        ProductsRemoteRepository(fakeDio(catalog.backend)).listProducts(),
        throwsA(isA<ApiException>()),
      );
    });
  });

  test('tạo sản phẩm gửi CreateProductRequest', () async {
    final catalog = _Catalog();
    await ProductsRemoteRepository(fakeDio(catalog.backend)).createProduct(
      const CreateProductInput(
        name: 'Mũ lưỡi trai',
        skus: [CreateSkuInput(skuCode: 'MU-01', basePrice: 99000)],
      ),
    );
    final req = catalog.backend.requests.single;
    expect(req.method, 'POST');
    expect(req.path, ApiPaths.products);
    expect(req.data, {
      'name': 'Mũ lưỡi trai',
      'skus': [
        {'skuCode': 'MU-01', 'basePrice': 99000.0},
      ],
    });
  });

  group('M-30/31/32 với BE thật', () {
    Future<_Catalog> openProducts(
      WidgetTester tester, {
      int? failSkusOf,
    }) async {
      final catalog = _Catalog(failSkusOf: failSkusOf);
      await loginAs(
        tester,
        'admin@demo.vn',
        tallView: true,
        overrides: [
          productsUseRemoteProvider.overrideWithValue(true),
          productsRepositoryProvider.overrideWithValue(
            ProductsRemoteRepository(fakeDio(catalog.backend)),
          ),
        ],
      );
      await tester.tap(find.byKey(const Key('nav_products')));
      await tester.pumpAndSettle();
      return catalog;
    }

    testWidgets('M-30: không banner mẫu, không chấm kênh, không nhãn tồn', (
      tester,
    ) async {
      await openProducts(tester);

      expect(find.byType(SoMockBanner), findsNothing);
      expect(find.text('Áo thun'), findsOneWidget);
      expect(find.text('Đang bán · 2'), findsOneWidget);
      expect(find.byType(SoChannelTag), findsNothing);
      // Tồn kho còn là mẫu: không gắn nhãn hết / sắp hết.
      expect(find.text('Hết hàng'), findsNothing);
      expect(find.text('Sắp hết'), findsNothing);
    });

    testWidgets('M-30: /skus lỗi → báo lỗi + Thử lại', (tester) async {
      await openProducts(tester, failSkusOf: 1);
      expect(find.text('Không tải được sản phẩm'), findsOneWidget);
      expect(find.text('Thử lại'), findsOneWidget);
    });

    testWidgets('M-31: không banner, không nhóm Liên kết sàn', (tester) async {
      await openProducts(tester);
      await tapVisible(tester, find.byKey(const Key('product_1')));

      expect(find.byType(ProductDetailScreen), findsOneWidget);
      expect(find.byType(SoMockBanner), findsNothing);
      expect(find.text('Liên kết sàn'), findsNothing);
      expect(find.text('AT-TRANG-M'), findsOneWidget);
    });

    testWidgets('M-32: tạo xong mở M-31, quay lại thì M-30 có sản phẩm mới', (
      tester,
    ) async {
      await openProducts(tester);
      await tapVisible(tester, find.byKey(const Key('products_add')));
      Finder field(String key) => find.descendant(
        of: find.byKey(Key(key)),
        matching: find.byType(EditableText),
      );
      await tester.enterText(field('product_name'), 'Mũ lưỡi trai');
      await tester.enterText(field('sku_code'), 'MU-01');
      await tester.enterText(field('sku_price'), '99000');
      await tapVisible(tester, find.byKey(const Key('product_create_submit')));

      expect(find.byType(ProductDetailScreen), findsOneWidget);
      await tester.tap(find.byKey(const Key('so_app_bar_leading')));
      await tester.pumpAndSettle();
      expect(find.text('Mũ lưỡi trai'), findsOneWidget);
      expect(find.text('Đang bán · 3'), findsOneWidget);
    });
  });
}
