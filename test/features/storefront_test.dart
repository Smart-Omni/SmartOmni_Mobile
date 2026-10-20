import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartomni_mobile/core/design/design.dart';
import 'package:smartomni_mobile/core/models/platform.dart';
import 'package:smartomni_mobile/core/network/api_exception.dart';
import 'package:smartomni_mobile/features/customer_shop/presentation/customer_shop_providers.dart';
import 'package:smartomni_mobile/features/products/domain/product.dart';
import 'package:smartomni_mobile/features/storefront/presentation/storefront_screens.dart';

import '../helpers/test_app.dart';

const _sku = Sku(id: 1, skuCode: 'A', basePrice: 159000);

const _products = [
  Product(
    id: 1,
    name: 'Áo thun cổ tròn',
    skus: [_sku],
    marketplaceUrls: {
      Platform.shopee: 'https://shopee.vn/a',
      Platform.tiktokShop: 'https://shop.tiktok.com/a',
    },
  ),
  Product(id: 2, name: 'Kem chống nắng', skus: [_sku]),
  Product(
    id: 3,
    name: 'Túi tote canvas',
    skus: [_sku],
    marketplaceUrls: {Platform.shopee: 'https://shopee.vn/c'},
  ),
];

Finder _inCard(int id, Finder finder) => find.descendant(
  of: find.byKey(Key('storefront_product_$id')),
  matching: finder,
);

void main() {
  testWidgets('C-10: viên cửa hàng, Hỏi AI, tiêu đề lớn, lưới thẻ có giá và '
      'kênh', (tester) async {
    await loginAs(
      tester,
      'customer@demo.vn',
      tallView: true,
      overrides: [
        storefrontProductsProvider.overrideWith((ref) async => _products),
      ],
    );

    expect(find.byType(StorefrontScreen), findsOneWidget);
    expect(
      tester
          .widget<SoShopSwitcher>(find.byKey(const Key('shop_switcher')))
          .name,
      'Shop Demo',
    );
    expect(
      find.descendant(
        of: find.byType(SoAppBar),
        matching: find.text('Sản phẩm'),
      ),
      findsOneWidget,
    );
    expect(find.byType(SoMockBanner), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);

    // Ba thẻ, hai hàng: thẻ cùng hàng cao bằng nhau.
    final a = tester.getRect(find.byKey(const Key('storefront_product_1')));
    final b = tester.getRect(find.byKey(const Key('storefront_product_2')));
    expect(a.top, b.top);
    expect(a.height, b.height);
    expect(find.byKey(const Key('storefront_product_3')), findsOneWidget);

    expect(_inCard(1, find.text('Từ 159.000 ₫')), findsOneWidget);
    expect(_inCard(1, find.byType(SoChannelTag)), findsNWidgets(2));
    expect(_inCard(2, find.text('Chưa mở bán trên sàn')), findsOneWidget);

    await tester.tap(find.byKey(const Key('ask_ai')));
    await tester.pump();
    expect(find.text('Sắp có'), findsOneWidget);

    await tester.tap(find.byKey(const Key('storefront_product_1')));
    await tester.pumpAndSettle();
    expect(find.byType(StorefrontProductScreen), findsOneWidget);
  });

  testWidgets('C-10: cửa hàng chưa có sản phẩm', (tester) async {
    await loginAs(
      tester,
      'customer@demo.vn',
      overrides: [storefrontProductsProvider.overrideWith((ref) async => [])],
    );
    expect(find.byKey(const Key('storefront_empty')), findsOneWidget);
    expect(find.text('Cửa hàng chưa có sản phẩm'), findsOneWidget);
  });

  testWidgets('C-10: chưa tham gia cửa hàng nào thì mời thêm cửa hàng', (
    tester,
  ) async {
    await loginAs(
      tester,
      'customer@demo.vn',
      overrides: [myShopsProvider.overrideWith((ref) async => const [])],
    );
    expect(find.byKey(const Key('storefront_no_shop')), findsOneWidget);
    expect(find.byKey(const Key('shop_switcher')), findsNothing);
    expect(find.text('Thêm cửa hàng'), findsOneWidget);
  });

  testWidgets('C-10: lỗi tải thì có Thử lại', (tester) async {
    await loginAs(
      tester,
      'customer@demo.vn',
      overrides: [
        storefrontProductsProvider.overrideWith(
          (ref) async => throw const ApiException(
            type: ApiErrorType.server,
            message: 'Máy chủ đang bận.',
          ),
        ),
      ],
    );
    expect(find.text('Không tải được sản phẩm'), findsOneWidget);
    expect(find.text('Máy chủ đang bận.'), findsOneWidget);
    expect(find.text('Thử lại'), findsOneWidget);
  });

  testWidgets('C-10 vừa bề rộng 360dp, chữ phóng 1.3', (tester) async {
    useNarrowPhone(tester);
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await loginAs(
      tester,
      'customer@demo.vn',
      overrides: [
        storefrontProductsProvider.overrideWith((ref) async => _products),
      ],
    );
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1500));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
