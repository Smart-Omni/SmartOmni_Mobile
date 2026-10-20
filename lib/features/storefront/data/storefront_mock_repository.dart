import '../../../core/models/platform.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/mock_delay.dart';
import '../../products/data/products_repositories.dart';
import '../../products/domain/product.dart';
import '../domain/storefront_repository.dart';

/// Mock: cửa hàng 1 dùng chung sản phẩm mẫu của Merchant (chỉ sản phẩm đang
/// bán); cửa hàng 2 có bộ sản phẩm riêng; cửa hàng khác chưa có sản phẩm.
class StorefrontMockRepository implements StorefrontRepository {
  final _shop1 = ProductsMockRepository();

  static const _shop2 = [
    Product(
      id: 2001,
      name: 'Son kem lì Hoa Mộc',
      description: 'Lên màu chuẩn, giữ màu 6 giờ.',
      skus: [
        Sku(
          id: 200101,
          skuCode: 'HM-SON-DO',
          variantName: 'Đỏ gạch',
          basePrice: 189000,
        ),
        Sku(
          id: 200102,
          skuCode: 'HM-SON-HONG',
          variantName: 'Hồng đất',
          basePrice: 189000,
        ),
      ],
      marketplaceUrls: {Platform.shopee: 'https://shopee.vn/hoamoc-son-kem'},
    ),
    Product(
      id: 2002,
      name: 'Sữa rửa mặt trà xanh',
      skus: [
        Sku(
          id: 200201,
          skuCode: 'HM-SRM-150',
          variantName: '150 ml',
          basePrice: 129000,
        ),
      ],
      marketplaceUrls: {
        Platform.shopee: 'https://shopee.vn/hoamoc-srm',
        Platform.tiktokShop: 'https://shop.tiktok.com/hoamoc-srm',
      },
    ),
    Product(
      id: 2003,
      name: 'Kem chống nắng SPF 50',
      skus: [
        Sku(
          id: 200301,
          skuCode: 'HM-KCN-50',
          variantName: '50 ml',
          basePrice: 245000,
        ),
      ],
    ),
  ];

  Future<List<Product>> _products(int tenantId) async => switch (tenantId) {
    1 => (await _shop1.listProducts()).where((p) => p.active).toList(),
    2 => _shop2,
    _ => const <Product>[],
  };

  @override
  Future<List<Product>> listProducts(int tenantId) async {
    await MockDelay.short();
    return _products(tenantId);
  }

  @override
  Future<Product> getProduct(int tenantId, int productId) async {
    await MockDelay.short();
    return (await _products(tenantId)).firstWhere(
      (p) => p.id == productId,
      orElse: () => throw const ApiException(
        type: ApiErrorType.notFound,
        message: 'Sản phẩm không tồn tại',
      ),
    );
  }
}
