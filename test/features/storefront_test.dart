import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartomni_mobile/features/chatbot/presentation/chatbot_screen.dart';
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

    // "Hỏi AI" mở C-12 (test chi tiết ở chatbot_test.dart).
    await tester.tap(find.byKey(const Key('ask_ai')));
    await tester.pumpAndSettle();
    expect(find.byType(ChatbotScreen), findsOneWidget);
    await tester.tap(find.byKey(const Key('so_app_bar_leading')));
    await tester.pumpAndSettle();

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
    expect(find.byKey(const Key('no_shop')), findsOneWidget);
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

  group('C-11', () {
    const both = Product(
      id: 1,
      name: 'Áo thun cổ tròn',
      description: 'Cotton 100%.',
      skus: [
        Sku(id: 11, skuCode: 'AT-M', variantName: 'Size M', basePrice: 159000),
        Sku(id: 12, skuCode: 'AT-L', variantName: 'Size L', basePrice: 189000),
        Sku(id: 13, skuCode: 'AT-NOI-BO', basePrice: 169000),
      ],
      marketplaceUrls: {
        Platform.shopee: 'https://shopee.vn/a',
        Platform.tiktokShop: 'https://shop.tiktok.com/a',
      },
    );

    Future<void> openProduct(
      WidgetTester tester,
      Future<Product> Function() load, {
      bool narrow = false,
    }) async {
      if (narrow) {
        useNarrowPhone(tester);
        tester.platformDispatcher.textScaleFactorTestValue = 1.3;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      }
      await loginAs(
        tester,
        'customer@demo.vn',
        tallView: !narrow,
        overrides: [
          storefrontProductsProvider.overrideWith((ref) async => [both]),
          storefrontProductProvider.overrideWith((ref, id) => load()),
        ],
      );
      await tester.tap(find.byKey(const Key('storefront_product_1')));
      await tester.pumpAndSettle();
      expect(find.byType(StorefrontProductScreen), findsOneWidget);
    }

    SoButtonVariant variant(WidgetTester tester, String key) =>
        tester.widget<SoButton>(find.byKey(Key(key))).variant;

    testWidgets('khoảng giá, ghi chú giá, phân loại, điểm, 2 nút mua', (
      tester,
    ) async {
      await openProduct(tester, () async => both);

      expect(find.text('Áo thun cổ tròn'), findsOneWidget);
      expect(find.text('159.000 – 189.000 ₫'), findsOneWidget);
      expect(
        find.text('Giá tham khảo, giá trên sàn có thể khác.'),
        findsOneWidget,
      );
      expect(find.text('Size M'), findsOneWidget);
      expect(find.text('Size L'), findsOneWidget);
      // SKU không có tên phân loại: không hiện mã nội bộ.
      expect(find.text('AT-NOI-BO'), findsNothing);
      expect(find.text('Cotton 100%.'), findsOneWidget);
      expect(find.text('Tích khoảng 159 điểm tại Shop Demo'), findsOneWidget);

      expect(variant(tester, 'buy_shopee'), SoButtonVariant.primary);
      expect(variant(tester, 'buy_tiktokShop'), SoButtonVariant.secondary);
      expect(find.text('Mua trên TikTok Shop'), findsOneWidget);

      await tester.tap(find.byKey(const Key('product_back')));
      await tester.pumpAndSettle();
      expect(find.byType(StorefrontProductScreen), findsNothing);
    });

    testWidgets('chỉ một sàn có URL thì chỉ một nút chính', (tester) async {
      await openProduct(
        tester,
        () async => const Product(
          id: 1,
          name: 'Túi tote',
          skus: [_sku],
          marketplaceUrls: {Platform.tiktokShop: 'https://shop.tiktok.com/t'},
        ),
      );
      expect(find.text('159.000 ₫'), findsOneWidget);
      expect(variant(tester, 'buy_tiktokShop'), SoButtonVariant.primary);
      expect(find.byKey(const Key('buy_shopee')), findsNothing);
    });

    testWidgets('chưa mở bán trên sàn nào thì không có thanh mua', (
      tester,
    ) async {
      await openProduct(
        tester,
        () async => const Product(id: 1, name: 'Kem', skus: [_sku]),
      );
      expect(find.byKey(const Key('product_not_on_sale')), findsOneWidget);
      expect(find.byType(SoActionBar), findsNothing);
    });

    testWidgets('lỗi thì có Thử lại và vẫn có nút back', (tester) async {
      await openProduct(
        tester,
        () async => throw const ApiException(
          type: ApiErrorType.notFound,
          message: 'Sản phẩm không tồn tại',
        ),
      );
      expect(find.text('Không tải được sản phẩm'), findsOneWidget);
      expect(find.text('Thử lại'), findsOneWidget);
      expect(find.byKey(const Key('product_back')), findsOneWidget);
    });

    testWidgets('vừa bề rộng 360dp, chữ phóng 1.3', (tester) async {
      await openProduct(tester, () async => both, narrow: true);
      expect(tester.takeException(), isNull);
      await tester.drag(
        find.byType(CustomScrollView).last,
        const Offset(0, -1500),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
