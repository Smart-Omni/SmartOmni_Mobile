import 'product.dart';

abstract class ProductsRepository {
  /// Danh sách sản phẩm của tenant.
  /// ⚠️ Backend CHƯA có `GET /api/products` -> luôn dùng mock (xem API_CONTRACT.md).
  Future<List<Product>> listProducts();

  /// GET /api/products/{id} + GET /api/products/{id}/skus
  Future<Product> getProduct(int id);

  /// POST /api/products
  Future<Product> createProduct(CreateProductInput input);
}
