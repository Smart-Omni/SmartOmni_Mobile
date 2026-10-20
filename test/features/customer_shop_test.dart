import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartomni_mobile/core/network/api_exception.dart';
import 'package:smartomni_mobile/core/utils/mock_delay.dart';
import 'package:smartomni_mobile/features/customer_shop/data/customer_shop_mock_repository.dart';
import 'package:smartomni_mobile/features/customer_shop/domain/customer_shop.dart';
import 'package:smartomni_mobile/features/customer_shop/presentation/customer_shop_providers.dart';
import 'package:smartomni_mobile/features/loyalty/domain/loyalty_rules.dart';
import 'package:smartomni_mobile/features/storefront/data/storefront_mock_repository.dart';
import 'package:smartomni_mobile/features/storefront/presentation/storefront_screens.dart';

Matcher _apiError(ApiErrorType type) =>
    throwsA(isA<ApiException>().having((e) => e.type, 'type', type));

void main() {
  setUp(() => MockDelay.enabled = false);

  group('mã cửa hàng', () {
    test('normalizeShopCode: bỏ dấu cách, viết hoa', () {
      expect(normalizeShopCode(' shop demo '), 'SHOPDEMO');
      expect(normalizeShopCode('hoamoc'), 'HOAMOC');
    });

    test('hasJoined so theo mã đã chuẩn hóa', () {
      const shops = [
        CustomerShop(tenantId: 1, code: 'SHOPDEMO', name: 'A', points: 0),
      ];
      expect(hasJoined(shops, 'shop demo'), isTrue);
      expect(hasJoined(shops, 'BEPXINH'), isFalse);
    });

    test('hạng theo điểm của từng cửa hàng', () {
      const shop = CustomerShop(tenantId: 1, code: 'X', name: 'X', points: 620);
      expect(shop.tier, LoyaltyTier.silver);
    });
  });

  group('CustomerShopMockRepository', () {
    test('có sẵn 2 cửa hàng', () async {
      final shops = await CustomerShopMockRepository().listMyShops();
      expect(shops.map((s) => s.code), ['SHOPDEMO', 'HOAMOC']);
    });

    test('xem trước: có mã thì trả cửa hàng, sai mã thì notFound', () async {
      final repo = CustomerShopMockRepository();
      expect((await repo.previewShop('bepxinh')).name, 'Bếp Xinh');
      expect(
        () => repo.previewShop('KHONGCO'),
        _apiError(ApiErrorType.notFound),
      );
    });

    test('tham gia: thêm vào danh sách; đã tham gia thì báo lỗi', () async {
      final repo = CustomerShopMockRepository();
      final joined = await repo.joinShop(' bepxinh ');
      expect(joined.tenantId, 3);
      expect(joined.points, 0);
      expect(
        (await repo.listMyShops()).map((s) => s.code),
        contains('BEPXINH'),
      );

      expect(
        () => repo.joinShop('SHOPDEMO'),
        _apiError(ApiErrorType.validation),
      );
      expect(() => repo.joinShop('KHONGCO'), _apiError(ApiErrorType.notFound));
    });
  });

  group('cửa hàng đang xem', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
      addTearDown(container.dispose);
    });

    test('mặc định là cửa hàng đầu tiên; chọn thì đổi theo', () async {
      expect((await container.read(currentShopProvider.future))!.tenantId, 1);

      container.read(selectedShopIdProvider.notifier).select(2);
      expect((await container.read(currentShopProvider.future))!.tenantId, 2);
    });

    test(
      'chọn cửa hàng không còn trong danh sách thì về cửa hàng đầu',
      () async {
        container.read(selectedShopIdProvider.notifier).select(99);
        expect((await container.read(currentShopProvider.future))!.tenantId, 1);
      },
    );

    test('chưa tham gia cửa hàng nào thì null, sản phẩm rỗng', () async {
      final empty = ProviderContainer(
        overrides: [myShopsProvider.overrideWith((ref) async => const [])],
      );
      addTearDown(empty.dispose);
      expect(await empty.read(currentShopProvider.future), isNull);
      expect(await empty.read(storefrontProductsProvider.future), isEmpty);
    });

    test('sản phẩm C-10 và C-11 đọc theo cửa hàng đang xem', () async {
      final sub = container.listen(storefrontProductsProvider, (_, _) {});
      addTearDown(sub.close);

      final shop1 = await container.read(storefrontProductsProvider.future);
      expect(shop1, isNotEmpty);
      expect(shop1.every((p) => p.active), isTrue);
      expect(shop1.any((p) => p.id == 2001), isFalse);

      container.read(selectedShopIdProvider.notifier).select(2);
      final shop2 = await container.read(storefrontProductsProvider.future);
      expect(shop2.map((p) => p.id), [2001, 2002, 2003]);

      final detail = await container.read(
        storefrontProductProvider(2002).future,
      );
      expect(detail.name, 'Sữa rửa mặt trà xanh');
    });
  });

  test('StorefrontMockRepository: sản phẩm của cửa hàng khác thì notFound', () {
    expect(
      () => StorefrontMockRepository().getProduct(1, 2001),
      _apiError(ApiErrorType.notFound),
    );
  });
}
