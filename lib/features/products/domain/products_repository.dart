import 'product.dart';

abstract class ProductsRepository {
  /// Danh sách sản phẩm của tenant, kèm SKU.
  /// GET /api/v1/products + GET /api/v1/products/{id}/skus cho từng sản phẩm.
  Future<List<Product>> listProducts();

  /// GET /api/v1/products/{id} + GET /api/v1/products/{id}/skus
  Future<Product> getProduct(int id);

  /// POST /api/v1/products
  Future<Product> createProduct(CreateProductInput input);
}
