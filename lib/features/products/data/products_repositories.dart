import 'package:dio/dio.dart';

import '../../../core/mock/mock_data.dart';
import '../../../core/models/platform.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/api_paths.dart';
import '../../../core/network/api_response.dart';
import '../../../core/utils/map_with_limit.dart';
import '../../../core/utils/mock_delay.dart';
import '../domain/product.dart';
import '../domain/products_repository.dart';

/// Gọi API thật của Catalog Service. BE trả thẳng entity (camelCase):
/// `Product { id, name, description, status }`, SKU lấy riêng ở `/{id}/skus`.
/// BE không trả link sàn, nên [Product.marketplaceUrls] luôn rỗng.
class ProductsRemoteRepository implements ProductsRepository {
  ProductsRemoteRepository(this._dio);

  final Dio _dio;

  @override
  Future<List<Product>> listProducts() async {
    try {
      // shortcut: chỉ tải trang đầu 100 sản phẩm, rồi mỗi sản phẩm một lần
      // gọi SKU (N+1, tối đa 4 cùng lúc). BE chưa có API trả kèm SKU.
      final res = await _dio.get<Object?>(
        ApiPaths.products,
        queryParameters: {'page': 0, 'size': 100, 'sort': 'createdAt,desc'},
      );
      final products = unwrapResponse<List<Product>>(
        res.data,
        (data) => PageResult.fromJson(data, Product.fromJson).items,
      );
      return await mapWithLimit(
        products,
        (p) async => p.copyWith(skus: await _skus(p.id)),
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<List<Sku>> _skus(int productId) async {
    final res = await _dio.get<Object?>(ApiPaths.productSkus(productId));
    return unwrapResponse<List<Sku>>(
      res.data,
      (data) => [
        for (final s in (data as List<dynamic>? ?? const []))
          Sku.fromJson(s as JsonMap),
      ],
    );
  }

  @override
  Future<Product> getProduct(int id) async {
    try {
      final productRes = await _dio.get<Object?>(ApiPaths.product(id));
      final skus = await _skus(id);
      return unwrapResponse<Product>(
        productRes.data,
        (data) => Product.fromJson(data! as JsonMap, skus: skus),
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  @override
  Future<Product> createProduct(CreateProductInput input) async {
    try {
      final res = await _dio.post<Object?>(
        ApiPaths.products,
        data: input.toJson(),
      );
      return unwrapResponse<Product>(
        res.data,
        (data) => Product.fromJson(data! as JsonMap),
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

class ProductsMockRepository implements ProductsRepository {
  ProductsMockRepository() : _products = _seed();

  final List<Product> _products;

  static List<Product> _seed() => [
    for (final (id, name, desc, skus, shopee, tiktok) in MockData.products)
      Product(
        id: id,
        name: name,
        description: desc,
        active: !MockData.hiddenProductIds.contains(id),
        skus: [
          for (final (skuId, code, variant, price) in skus)
            Sku(
              id: skuId,
              skuCode: code,
              variantName: variant,
              basePrice: price,
            ),
        ],
        marketplaceUrls: {
          Platform.shopee: ?shopee,
          Platform.tiktokShop: ?tiktok,
        },
      ),
  ];

  @override
  Future<List<Product>> listProducts() async {
    await MockDelay.short();
    return List.unmodifiable(_products);
  }

  @override
  Future<Product> getProduct(int id) async {
    await MockDelay.short();
    return _products.firstWhere(
      (p) => p.id == id,
      orElse: () => throw const ApiException(
        type: ApiErrorType.notFound,
        message: 'Sản phẩm không tồn tại',
      ),
    );
  }

  @override
  Future<Product> createProduct(CreateProductInput input) async {
    await MockDelay.short();
    final id = _products.fold<int>(0, (m, p) => p.id > m ? p.id : m) + 1;
    final product = Product(
      id: id,
      name: input.name,
      description: input.description,
      skus: [
        for (final (i, s) in input.skus.indexed)
          Sku(
            id: id * 100 + i + 1,
            skuCode: s.skuCode,
            variantName: s.variantName,
            basePrice: s.basePrice,
          ),
      ],
    );
    _products.add(product);
    return product;
  }
}
