import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartomni_mobile/app/config/app_config.dart';
import 'package:smartomni_mobile/core/design/design.dart';
import 'package:smartomni_mobile/core/models/platform.dart';
import 'package:smartomni_mobile/features/inventory/domain/inventory_item.dart';
import 'package:smartomni_mobile/features/inventory/presentation/inventory_providers.dart';
import 'package:smartomni_mobile/features/products/domain/product.dart';
import 'package:smartomni_mobile/features/products/presentation/product_detail_screen.dart';
import 'package:smartomni_mobile/features/products/presentation/products_providers.dart';
import 'package:smartomni_mobile/l10n/l10n.dart';

import '../helpers/test_app.dart';

const _product = Product(
  id: 7,
  name: 'Áo thun cổ tròn',
  description: 'Cotton 100%.',
  skus: [
    Sku(id: 71, skuCode: 'AT-001-M', variantName: 'Size M', basePrice: 159000),
    Sku(id: 72, skuCode: 'AT-001-L', variantName: 'Size L', basePrice: 169000),
  ],
  marketplaceUrls: {Platform.shopee: 'https://shopee.vn/ao-thun-co-tron'},
);

Future<void> _pump(
  WidgetTester tester, {
  required Future<List<InventoryItem>> Function() stock,
  Product product = _product,
  Size size = const Size(800, 2000),
  double textScale = 1,
}) async {
  // Mặc định khung cao để danh sách (dựng lười) có đủ nhóm liên kết sàn.
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(testConfig),
        productDetailProvider.overrideWith((ref, id) async => product),
        inventoryListProvider.overrideWith((ref) => stock()),
      ],
      child: MaterialApp(
        theme: SoTheme.light(),
        locale: const Locale('vi'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: const ProductDetailScreen(productId: 7),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('M-31: tồn kho lỗi thì chỉ ẩn nhãn, màn vẫn hiện sản phẩm', (
    tester,
  ) async {
    await _pump(tester, stock: () => Future.error(Exception('mất mạng')));

    expect(tester.takeException(), isNull);
    expect(find.text('Áo thun cổ tròn'), findsOneWidget);
    expect(find.text('Không tải được sản phẩm'), findsNothing);
    expect(find.byType(SoMockBanner), findsOneWidget);
    expect(find.byKey(const Key('sku_71')), findsOneWidget);
    expect(find.text('Hết hàng'), findsNothing);
    expect(find.text('Sắp hết'), findsNothing);
  });

  testWidgets('M-31: nhãn hết/sắp hết theo từng SKU, có nút chép URL sàn', (
    tester,
  ) async {
    await _pump(
      tester,
      stock: () async => const [
        InventoryItem(
          skuId: 71,
          skuCode: 'AT-001-M',
          productName: 'Áo thun cổ tròn',
          quantityOnHand: 0,
        ),
        InventoryItem(
          skuId: 72,
          skuCode: 'AT-001-L',
          productName: 'Áo thun cổ tròn',
          quantityOnHand: 3,
        ),
      ],
    );

    expect(find.text('Hết hàng'), findsOneWidget);
    expect(find.text('Sắp hết'), findsOneWidget);
    // Đủ chỗ thì giá nằm sát mép phải hàng (trước mũi tên), số căn phải.
    final row = tester.getRect(find.byKey(const Key('sku_71')));
    final price = tester.getRect(
      find.descendant(
        of: find.byKey(const Key('sku_71')),
        matching: find.text('159.000 ₫'),
      ),
    );
    expect(row.right - price.right, lessThan(64));
    expect(find.text('Đang bán'), findsOneWidget);
    expect(find.byKey(const Key('copy_link_shopee')), findsOneWidget);
    expect(find.byKey(const Key('copy_link_tiktokShop')), findsNothing);
    expect(find.text('Chưa có dữ liệu liên kết'), findsOneWidget);
  });

  testWidgets('M-31 vừa bề rộng 360dp: tên dài, giá lớn, chữ phóng 1.3', (
    tester,
  ) async {
    const long = Product(
      id: 7,
      name: 'Áo khoác gió chống nước hai lớp có mũ tháo rời phiên bản mùa đông',
      description: 'Vải dù hai lớp, khóa kéo YKK, túi trong có khóa.',
      skus: [
        Sku(
          id: 71,
          skuCode: 'AKG-CHONGNUOC-2LOP-XXL-XANHREU',
          variantName: 'Xanh rêu · XXL · Có mũ tháo rời',
          basePrice: 12990000,
        ),
        Sku(id: 72, skuCode: 'AKG-CHONGNUOC-2LOP-M', basePrice: 1290000),
      ],
      marketplaceUrls: {
        Platform.shopee:
            'https://shopee.vn/ao-khoac-gio-chong-nuoc-hai-lop-co-mu-thao-roi-i.123456789.987654321',
        Platform.tiktokShop: 'https://shop.tiktok.com/view/product/1729384756',
      },
    );
    await _pump(
      tester,
      product: long,
      size: const Size(360, 780),
      textScale: 1.3,
      stock: () async => const [
        InventoryItem(
          skuId: 71,
          skuCode: 'AKG-CHONGNUOC-2LOP-XXL-XANHREU',
          productName: 'Áo khoác gió',
          quantityOnHand: 2,
        ),
      ],
    );
    expect(tester.takeException(), isNull);

    // Cuộn hết màn: lỗi tràn ở bất kỳ hàng nào sẽ làm test fail.
    await tester.drag(find.byType(ListView), const Offset(0, -3000));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('copy_link_tiktokShop')), findsOneWidget);
    // SKU không có tên biến thể: mã chỉ hiện một lần (trong SoCodeTag).
    expect(find.text('AKG-CHONGNUOC-2LOP-M'), findsOneWidget);
  });
}
