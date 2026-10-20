import '../../products/domain/product.dart';

/// Sản phẩm khách xem trong một cửa hàng (C-10, C-11). Chỉ sản phẩm đang bán.
///
/// ⚠️ Backend CHƯA có API storefront (docs/API_CONTRACT.md mục 3) -> mock.
/// Khi có: `GET /api/storefront/products` và `/{id}`, cửa hàng gửi qua header
/// `X-Tenant-Id`.
abstract class StorefrontRepository {
  Future<List<Product>> listProducts(int tenantId);

  /// Không có thì ném `ApiException` loại `notFound`.
  Future<Product> getProduct(int tenantId, int productId);
}
