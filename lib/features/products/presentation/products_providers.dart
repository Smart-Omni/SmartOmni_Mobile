import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/config/api_availability.dart';
import '../../../app/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../data/products_repositories.dart';
import '../domain/product.dart';
import '../domain/products_repository.dart';

final productsRepositoryProvider = Provider<ProductsRepository>((ref) {
  final mock = ProductsMockRepository();
  return ref.watch(productsUseRemoteProvider)
      ? ProductsRemoteRepository(ref.watch(dioProvider), mock)
      : mock;
});

/// `false`: chi tiết/tạo sản phẩm là dữ liệu mẫu. Danh sách luôn là mẫu
/// (backend chưa có API danh sách).
final productsUseRemoteProvider = Provider<bool>(
  (ref) => ref.watch(appConfigProvider).usesRemote(ApiFeature.products),
);

final productsListProvider = FutureProvider.autoDispose<List<Product>>(
  (ref) => ref.watch(productsRepositoryProvider).listProducts(),
);

final productDetailProvider = FutureProvider.autoDispose.family<Product, int>(
  (ref, id) => ref.watch(productsRepositoryProvider).getProduct(id),
);
